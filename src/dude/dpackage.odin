package dude

import "core:log"
import "core:os"
import "core:strings"
import "core:fmt"
import "core:path/filepath"

import "dgl"

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
            if filepath.is_abs(path) {
                pac.path = filepath.dir(path)
            } else {
                abs, _ := filepath.abs(path, context.temp_allocator)
                pac.path = filepath.dir(abs)
            }
            log.debugf("DPac: Load package from: {} : [{}]", pac.path, filepath.base(path))
            
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

dpac_release :: proc(dpac: ^DPackage) {
    // ## release the resources
    // ...

    // ## release the meta
    {
        meta := dpac.meta
        delete(meta.identifiers)
        strings.builder_destroy(&meta.name)
        for value in &meta.values {
            dpac_release_value(&value)
        }
    }

    free(dpac.meta)
    delete(dpac.data)
}
dpac_release_value :: proc(value: ^DPacObject) {
    if value.name != "" do delete(value.name)
    if value.load_path != "" do delete(value.load_path)
    switch vtype in value.value {
    case DPacRef:
        ref := value.value.(DPacRef)
        if ref.name != "" do delete(ref.name)
        if ref.pac != "" do delete(ref.pac)
    case DPacLiteral:
        lit := value.value.(DPacLiteral)
        if text, ok := lit.(string); ok && text != "" {
            delete(text)
        }
    case DPacInitializer:
        ini := value.value.(DPacInitializer)
        for field in &ini.fields {
            if !ini.anonymous && field.field != "" do delete(field.field)
            dpac_release_value(&field.value)
        }
    }
}

// To add a resource type with a `loader` process,
// which creates a resource object from a `DPacObject`.
dpac_register_loader :: proc(type: typeid, loader: DPacResLoader) {
    // TODO
}

DPacResLoader :: proc(value:^DPacObject) -> rawptr

@(private="file")
dpac_resource_loaders : map[typeid]DPacResLoader

dpac_load :: proc(dpac: ^DPackage) {
    meta := dpac.meta
    values := meta.values
    for value in &values {
        dpac_load_value(dpac, &value)
    }
}

dpac_load_value :: proc(dpac: ^DPackage, value: ^DPacObject) -> rawptr {
    the_data : rawptr
    switch value.type {
    case "Color":
        the_data = builtin_loader_color(dpac, value)
    case "Shader":
        the_data = builtin_loader_shader(dpac, value)
    case "Texture":
        the_data = builtin_loader_texture(dpac, value)
    case:
        log.errorf("DPac: Unknown resource type: {}", value.type)
        return nil
    }

    if the_data != nil && value.name != "" {
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

builtin_loader_color :: proc(dpac: ^DPackage, value: ^DPacObject) -> rawptr {
    name := value.name
    ini, ok := value.value.(DPacInitializer)
    if ok {
        color := new(Color)
        for i in 0..<len(ini.fields) {
            v, ok := ini.fields[i].value.value.(DPacLiteral).(f32)
            if !ok do v = cast(f32)ini.fields[i].value.value.(DPacLiteral).(i32)
            color[i] = v
        }
        return color
    }
    return nil
}

builtin_loader_shader :: proc(dpac: ^DPackage, value: ^DPacObject) -> rawptr {
    path := dpac_path_convert(dpac, value.load_path)
    defer delete(path)
    if !os.is_file(path) {
        panic(fmt.tprintf("Invalid filepath: {}", path))
    }
    log.debugf("DPac: Load shader from: {}", path)
    source, ok := os.read_entire_file_from_filename(path)
    if !ok { return nil }
    id := dshader_load_from_source(cast(string)source)
    delete(source)

    if id == 0 { return nil }

    shader := new(DShader)
    shader.id = id

    return shader
}

builtin_loader_texture :: proc(dpac: ^DPackage, value: ^DPacObject) -> rawptr {
    path := dpac_path_convert(dpac, value.load_path)
    defer delete(path)
    if !os.is_file(path) {
        panic(fmt.tprintf("Invalid filepath: {}", path))
    }
    log.debugf("DPac: Load texture from : {}", path)

    tex := dgl.texture_load(path)
    if tex.id == 0 do return nil
    ptex := new(Texture)
    ptex^ = Texture{
        size = tex.size,
        id = tex.id,
    }

    return cast(rawptr)ptex
}

dpac_path_convert :: proc(dpac: ^DPackage, path: string, allocator := context.allocator) -> string {
    context.allocator = allocator
    if filepath.is_abs(path) do return strings.clone(path)
    else do return filepath.join({ dpac.path, path })
}

dpac_debug_log :: proc(dpac: ^DPackage) {

}

DPackage :: struct {
    meta : ^DPacMeta,
    data : map[ResKey]rawptr,
    path : string,
}