package dude

import "core:log"
import "core:os"
import "core:strings"
import "core:fmt"
import "core:mem"
import "core:runtime"
import "core:path/filepath"

import "dgl"

DPackage :: struct {
    meta : ^DPacMeta,
    data : map[ResKey]rawptr,
    path : string,
    loaded : bool,
    // mem
    pac_storage  : DPackageStorage,
    meta_storage : DPackageStorage,
}

DPackageStorage :: struct {
    buffer : []byte,
    arena  : mem.Arena,
    allocator : runtime.Allocator,
}

// Parse a dpackage script, create a `DPackage`. For resource management.
dpac_init :: proc(path: string) -> (^DPackage, bool) {
    context.allocator = allocators.default
    data, ok := os.read_entire_file(path)
    defer delete(data)

    if ok {
        source := cast(string)data
        pac := new(DPackage)
        dpac_alloc_storage(&pac.meta_storage, 1024 * 1024)

        meta, ok := dpac_init_from_source(pac, source)

        if ok {
            pac.meta = meta
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

dpac_alloc_storage :: proc(using storage: ^DPackageStorage, size : int) -> mem.Allocator_Error  {
    context.allocator = allocators.default
    err : mem.Allocator_Error
    buffer, err = mem.alloc_bytes(size)
    mem.arena_init(&arena, buffer)
    allocator = mem.arena_allocator(&arena)
    return err
}
dpac_free_storage :: proc(using dpacstore : ^DPackageStorage) {
    context.allocator = allocators.default
    mem.free_bytes(buffer)
}

dpac_init_from_source :: proc(dpac: ^DPackage, source: string) -> (^DPacMeta, bool) {
    context.allocator = allocators.default
    if len(dpac.meta_storage.buffer) == 0 {
        log.errorf("DPac: DPac's meta storage is not allocated, cannot generate.")
        return nil, false
    }
    dpac := dpac_gen_meta_from_source(dpac, source)
    log.debugf("DPac: DPacMeta [ {} ] created!", strings.to_string(dpac.name))
    return dpac, true
}

dpac_destroy :: proc(dpac: ^DPackage) {
    context.allocator = allocators.default
    // ## release the resources
    // ...
    dpac_unload(dpac)

    // ## release the meta
    dpac_free_storage(&dpac.meta_storage)

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
    context.allocator = allocators.default
    dpac_alloc_storage(&dpac.pac_storage, 100 * 1024 * 1024)
    context.allocator = dpac.pac_storage.allocator
    meta := dpac.meta
    dpac.data = make(map[ResKey]rawptr)
    values := meta.values
    for value in &values {
        dpac_load_value(dpac, &value)
    }
    dpac.loaded = true
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

dpac_unload :: proc(using dpac: ^DPackage) {
    if loaded {
        context.allocator = allocators.default
        dpac_free_storage(&dpac.pac_storage)
        loaded = false
    }
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