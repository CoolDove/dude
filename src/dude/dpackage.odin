package dude

import "core:log"
import "core:os"
import "core:strings"
import "core:fmt"
import "core:path/filepath"

// Parse a dpackage script, create a `DPackage`. For resource management.
dpac_init :: proc(path: string, allocator:= context.allocator) -> (^DPackage, bool) {
    context.allocator = allocator
    data, ok := os.read_entire_file(path)
    defer delete(data)

    if ok {
        source := cast(string)data
        meta, ok := dpac_init_from_source(source, allocator)
        if ok {
            pac := new(DPackage)
            pac.meta = meta
            pac.data = make(map[ResKey]rawptr)
            return pac, true
        } else {
            return nil, false
        }
    } else {
        return nil, false
    }
}

dpac_init_from_source :: proc(source: string, allocator:= context.allocator) -> (^DPacMeta, bool) {
    context.allocator = allocator
    dpac := generate_package_from_source(source)
    log.debugf("DPac: DPacMeta [ {} ] created!", strings.to_string(dpac.name))
    return dpac, true
}

// To add a resource type with a `loader` process,
// which creates a resource object from a `DPacValue`.
dpac_register_loader :: proc(type: typeid, loader: DPacResLoader) {
    // TODO
}

DPacResLoader :: proc(value:^DPacValue) -> rawptr

@(private="file")
dpac_resource_loaders : map[typeid]DPacResLoader

dpac_load :: proc(dpac: ^DPackage) {
    meta := dpac.meta
    values := meta.values
    for value in &values {
        dpac_load_value(dpac, &value)
    }
}

dpac_load_value :: proc(dpac: ^DPackage, value: ^DPacValue) -> rawptr {
    the_data : rawptr

    switch value.type {
    case "Color":
        the_data = builtin_loader_color(dpac, value)
    case "Shader":
        the_data = builtin_loader_shader(dpac, value)
    case:
        log.errorf("DPac: Unknown resource type: {}", value.type)
        return nil
    }

    if the_data != nil {
        map_insert(&dpac.data, res_key(value.name), the_data)
    } else {
        log.errorf("DPac: Failed to load resource {} for unknown reason.", value.name)
        return nil
    }

    return the_data
}

dpac_unload :: proc(dpac: ^DPackage) {
}

dpac_query :: proc {
    dpac_query_key, 
    dpac_query_name,
}
dpac_query_name :: proc(dpac: ^DPackage, name: string, $T: typeid) -> ^T {
    return dpac_query_key(dpac, res_key(name), T)
}
dpac_query_key :: proc(dpac: ^DPackage, key:  ResKey, $T: typeid) -> ^T {
    assert(dpac != nil, "Invalid dpackage pointer.")
    data, ok := dpac.data[key]
    if ok do return transmute(^T)data
    else do return nil
}

dpac_destroy :: proc(dpac: ^DPackage) {
    free(dpac.meta)
    delete(dpac.data)
}

builtin_loader_color :: proc(dpac: ^DPackage, value: ^DPacValue) -> rawptr {
    name := value.name
    obj, ok := value.value.(DPacObject)
    if ok {
        color := new(Color)
        for i in 0..<len(obj.values) {
            v, ok := obj.values[i].value.(DPacLiteral).(f32)
            if !ok do v = cast(f32)obj.values[i].value.(DPacLiteral).(i32)
            color[i] = v
        }
        dpac.data[res_key(name)] = color
        return color
    }
    return nil
}

builtin_loader_shader :: proc(dpac: ^DPackage, value: ^DPacValue) -> rawptr {
    path := value.load_path
    if !os.is_file(path) {
        panic(fmt.tprintf("Invalid filepath: {}", path))
    }
    source, ok := os.read_entire_file_from_filename(path)
    if !ok { return nil }
    id := dshader_load_from_source(cast(string)source)
    delete(source)

    if id == 0 { return nil }

    shader := new(DShader)
    shader.id = id

    return shader
}

DPackage :: struct {
    meta : ^DPacMeta,
    data : map[ResKey]rawptr,
}