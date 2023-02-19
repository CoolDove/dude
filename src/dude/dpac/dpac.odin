﻿package dpac

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
    using meta_part : DPackageMetaPart,
    using pac_part  : DPackagePacPart,
}
DPackageMetaPart :: struct {
    meta_storage : DPackageStorage,// Used when initing the dpacakge.
    path : string,
    loaded : bool,
    using meta : ^DPacMeta,
}
DPackagePacPart :: struct {
    pac_storage  : DPackageStorage, // Used when loading the dpackage.
    // data : map[DPacKey]DPackageAsset,
}

// Asset representation of the dpackage asset.
// Points to one specific allocated and initialized data, the actual data is stored in the `pac_storage`.
// When you query an asset, you should go for the `dpac.meta.symbols`, which stored in the `meta_storage`.
DPackageAsset :: struct {
    ptr  : rawptr,
    type : typeid,
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
// After this, the `meta` of the dpackage is allocated and correctly setup.
// You can load then.
dpac_init :: proc(path: string) -> (^DPackage, bool) {
    context.allocator = dpac_default_allocator^
    data, ok := os.read_entire_file(path)
    defer delete(data)

    if ok {
        source := cast(string)data
        pac := new(DPackage)
        dpac_alloc_storage(&pac.meta_storage, 1024 * 1024)
        
        context.allocator = dpac_default_allocator^
        meta := generate_meta_from_source(pac, source)

        if ok {
            pac.meta = meta
            package_path : string
            if filepath.is_abs(path) {
                package_path = filepath.dir(path)
            } else {
                abs, _ := filepath.abs(path, context.temp_allocator)
                package_path = filepath.dir(abs)
            }
            pac.path = strings.clone(package_path, pac.meta_storage.allocator)

            log.debugf("DPac: Load package from: {} : [{}]. Meta data storage: {}/{}", 
                pac.path, filepath.base(path),
                pac.meta_storage.arena.peak_used, len(pac.meta_storage.arena.data),
            )
            
            return pac, true
        } else {
            log.errorf("DPac: Failed to generate meta from: {}.", path)
            return nil, false
        }
    } else {
        log.errorf("DPac: Failed to load file from: {}.", path)
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

// dpac_init_from_source :: proc(dpac: ^DPackage, source: string) -> (^DPacMeta, bool) {
//     return dpac, true
// }

dpac_destroy :: proc(dpac: ^DPackage) {
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
    // dpac.data = make(map[DPacKey]DPackageAsset)
    symbols := meta.symbols
    for key, symb in &symbols {
        if symb.data.ptr == nil {// Means not loaded.
            asset := dpac_load_value(dpac, &symb.obj)
            symb.data = asset
        }
    }
    dpac.loaded = true

    log.debugf("DPac: Package {} loaded, mem usage: {}/{}.", dpac.path, 
        dpac.pac_storage.arena.peak_used, 
        len(dpac.pac_storage.arena.data),
    )
}

dpac_unload :: proc(using dpac: ^DPackage) {
    if loaded {
        context.allocator = dpac.meta_storage.allocator
        for key, symb in &dpac.meta.symbols {
            symb.data.ptr = nil // Mark them as unloaded.
        }
        context.allocator = dpac_default_allocator^
        dpac_free_storage(&dpac.pac_storage)
        loaded = false
    }
}

dpac_query :: proc {
    dpac_query_key, 
    dpac_query_name,
    dpac_query_key_raw, 
    dpac_query_name_raw,
}
dpac_query_name :: proc(dpac: ^DPackage, name: string, $T: typeid) -> ^T {
    return dpac_query_key(dpac, dpac_key(name), T)
}
dpac_query_key :: proc(dpac: ^DPackage, key: DPacKey, $T: typeid) -> ^T {
    assert(dpac != nil, "Invalid dpackage pointer.")
    symb, ok := dpac.symbols[key]
    ptr := symb.data.ptr
    if ok && ptr != nil do return transmute(^T)ptr
    else do return nil
}
dpac_query_name_raw :: proc(dpac: ^DPackage, name: string) -> DPackageAsset {
    return dpac_query_key_raw(dpac, dpac_key(name))
}
dpac_query_key_raw :: proc(dpac: ^DPackage, key: DPacKey) -> DPackageAsset {
    assert(dpac != nil, "Invalid dpackage pointer.")
    data, ok := dpac.symbols[key]
    if ok && data.data.ptr != nil do return data.data
    else do return {}
}


dpac_path_convert :: proc(dpac: ^DPackage, path: string, allocator := context.allocator) -> string {
    context.allocator = allocator
    if filepath.is_abs(path) do return strings.clone(path)
    else do return filepath.join({ dpac.path, path })
}

dpac_debug_log :: proc(dpac: ^DPackage) {

}