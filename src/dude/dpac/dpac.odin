package dpac

import "core:log"
import "core:os"
import "core:strings"
import "core:fmt"
import "core:mem"
import "core:hash"
import "core:runtime"
import "core:reflect"
import "core:path/filepath"

import "../dgl"

DPacKey :: distinct u64

DPackage :: struct {
    meta : ^DPacMeta,
    data : map[DPacKey]rawptr,
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

@private
dpac_asset_types : map[string]DPacAssetType
@private
dpac_default_allocator : ^runtime.Allocator

DPacAssetType :: struct {
    type : typeid, 
    loader : DPacResLoader,
}

// ## Install and uninstall, invoke before you use any dpac api, and after you use any api.
dpac_install :: proc(default_allocator: ^runtime.Allocator) {
    dpac_default_allocator = default_allocator
    context.allocator = dpac_default_allocator^
    dpac_asset_types = make(map[string]DPacAssetType)
}

// To add a resource type with a `loader` process,
// which creates a resource object from a `DPacObject`.
dpac_register_asset :: proc(key: string, type: typeid, loader: DPacResLoader = nil) -> bool {
    if dpac_default_allocator == nil {
        log.errorf("DPac: DPac is not installed, cannot reigster loader before it's installed.")
        return false
    }
    if !dpac_asset_type_valid(type) {
        log.errorf("DPac: DPac can only reigster asset type by struct, while {} is not a struct.", type)
        return false
    }
    if key in dpac_asset_types {
        log.warnf("DPac: asset type {} has been registered.", key)
        dpac_asset_types[key] = DPacAssetType{ type, loader }
    } else {
        map_insert(&dpac_asset_types, strings.clone(key), DPacAssetType{ type, loader })
    }
    return true
}

dpac_asset_type_valid :: proc(type: typeid) -> bool {
    type_info := type_info_of(type)
    #partial switch t in type_info.variant {
    case runtime.Type_Info_Named :
        named := type_info.variant.(runtime.Type_Info_Named)
        base_info := type_info_of(named.base.id)
        return reflect.is_struct(base_info) || reflect.is_array(base_info)
    case runtime.Type_Info_Array : 
        return true
    case runtime.Type_Info_Struct :
        return true
    }
    return false
}

dpac_uninstall :: proc() {
    context.allocator = dpac_default_allocator^
    delete(dpac_asset_types)
}

// ## Main api.

dpac_key :: proc(name:string) -> DPacKey {
    return cast(DPacKey)hash.crc64_xz(raw_data(name)[:len(name)])
}

// Parse a dpackage script, create a `DPackage`. For resource management.
dpac_init :: proc(path: string) -> (^DPackage, bool) {
    context.allocator = dpac_default_allocator^
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
    context.allocator = dpac_default_allocator^
    err : mem.Allocator_Error
    buffer, err = mem.alloc_bytes(size)
    mem.arena_init(&arena, buffer)
    allocator = mem.arena_allocator(&arena)
    return err
}
dpac_free_storage :: proc(using dpacstore : ^DPackageStorage) {
    context.allocator = dpac_default_allocator^
    mem.free_bytes(buffer)
}

dpac_init_from_source :: proc(dpac: ^DPackage, source: string) -> (^DPacMeta, bool) {
    context.allocator = dpac_default_allocator^
    if len(dpac.meta_storage.buffer) == 0 {
        log.errorf("DPac: DPac's meta storage is not allocated, cannot generate.")
        return nil, false
    }
    dpac := dpac_gen_meta_from_source(dpac, source)
    log.debugf("DPac: DPacMeta [ {} ] created!", strings.to_string(dpac.name))
    return dpac, true
}

dpac_destroy :: proc(dpac: ^DPackage) {
    context.allocator = dpac_default_allocator^
    // ## release the resources
    // ...
    dpac_unload(dpac)

    // ## release the meta
    dpac_free_storage(&dpac.meta_storage)

}

dpac_load :: proc(dpac: ^DPackage) {
    context.allocator = dpac_default_allocator^
    dpac_alloc_storage(&dpac.pac_storage, 10 * 1024 * 1024)
    context.allocator = dpac.pac_storage.allocator
    meta := dpac.meta
    dpac.data = make(map[DPacKey]rawptr)
    values := meta.values
    for value in &values {
        dpac_load_value(dpac, &value)
    }
    dpac.loaded = true

    log.debugf("DPac: Package {} loaded, mem usage: {}/{}.", dpac.path, 
        dpac.pac_storage.arena.peak_used, 
        len(dpac.pac_storage.arena.data),
    )

}

dpac_unload :: proc(using dpac: ^DPackage) {
    if loaded {
        context.allocator = dpac_default_allocator^
        dpac_free_storage(&dpac.pac_storage)
        loaded = false
    }
}

dpac_query :: proc {
    dpac_query_key, 
    dpac_query_name,
}
dpac_query_name :: proc(dpac: ^DPackage, name: string, $T: typeid) -> ^T {
    return dpac_query_key(dpac, dpac_key(name), T)
}
dpac_query_key :: proc(dpac: ^DPackage, key: DPacKey, $T: typeid) -> ^T {
    assert(dpac != nil, "Invalid dpackage pointer.")
    data, ok := dpac.data[key]
    if ok do return transmute(^T)data
    else do return nil
}

dpac_path_convert :: proc(dpac: ^DPackage, path: string, allocator := context.allocator) -> string {
    context.allocator = allocator
    if filepath.is_abs(path) do return strings.clone(path)
    else do return filepath.join({ dpac.path, path })
}

dpac_debug_log :: proc(dpac: ^DPackage) {

}