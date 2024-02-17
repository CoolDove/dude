package dpac

import "core:log"
import "core:os"
import "core:strings"
import "core:fmt"
import "core:mem"
import "core:slice"
import "core:runtime"
import "core:reflect"
import "core:path/filepath"

DPacResLoader :: proc(data: rawptr, value:^DPacObject) -> rawptr

@(private="file")
dpac_resource_loaders : map[typeid]DPacResLoader

DPacErr_Load :: enum {
    None, TypeMismatch, UnknownField, TooMuchFields,
}

// NOTE(Dove): DPackage Load Process
// Allocate the asset data in `pac_storage`, then set the symbol data in the dpackage meta.

// Everytime you want to load an object, call this function.
// It'll allocate an asset object, and correctly set it up.
// Then call an object loader function that you specified with `dpac_register_asset`.
dpac_load_value :: proc(dpac: ^DPackage, obj: ^DPacObject) -> DPackageAsset {
    the_data : DPackageAsset
    if lit, ok := obj.value.(DPacLiteral); ok {
        the_data = load_literal(obj)
    } else if ini, ok := obj.value.(DPacInitializer); ok {
        the_data = load_initializer(dpac, obj)
    } else if ref, ok := obj.value.(DPacRef); ok {
        the_data = load_reference(dpac, obj)
    }
    if the_data.ptr != nil {
        if asset_type, ok := dpac_asset_types[obj.type]; ok {
            loader := asset_type.loader
            if loader != nil do loader(the_data.ptr, obj)
        }
        if obj.name != "" { log.debugf("DPac: Load value [{}]: {}", obj.name, the_data) } 
        else              { log.debugf("DPac: Load anonymous value: {}", the_data) }
    } else {
        return {}
    }
    return the_data
}

load_literal :: proc(obj: ^DPacObject) -> DPackageAsset {
    lit := obj.value.(DPacLiteral)
    switch obj.type {
    case "String":
        if str, ok := lit.(string); ok {
            ret := new(string)
            ret^ = strings.clone(str[1:len(str) - 1])
            return DPackageAsset{ret, typeid_of(string)}
        } else {
            log.errorf("DPac: Invalid literal string: {}", lit)
            return DPackageAsset{nil, typeid_of(string)}
        }
    case "Float":
        if f, ok := lit.(f32); ok {
            ret := new(f32)
            ret^ = f
            return DPackageAsset{ret, typeid_of(f32)}
        } else if i, ok := lit.(i32); ok {
            ret := new(f32)
            ret^ = cast(f32)i
            return DPackageAsset{ret, typeid_of(f32)}
        } else {
            return DPackageAsset{nil, typeid_of(f32)}
        }
    case "Integer":
        if f, ok := lit.(f32); ok {
            ret := new(i32)
            ret^ = cast(i32)f
            return DPackageAsset{ret, typeid_of(i32)}
        } else if i, ok := lit.(i32); ok {
            ret := new(i32)
            ret^ = i
            return DPackageAsset{ret, typeid_of(i32)}
        } else {
            log.errorf("DPac: Invalid literal i32: {}", lit)
            return DPackageAsset{nil, typeid_of(i32)}
        }
    case:
        log.errorf("DPac: Unknown literal type: {}", obj.type)
        return DPackageAsset{nil, typeid_of(any)}
    }
    log.errorf("DPac: Unknown error when load literal: {}", obj)
    return DPackageAsset{nil, typeid_of(any)}
}


// Load an object initializer, either anonymous nor named.
// 
// If a object initalizer is mixing between anonymous or named.
// It'll be take as a named initializer, and all the anonymous fields would be just **ignored**.
load_initializer :: proc(dpac: ^DPackage, obj: ^DPacObject) -> DPackageAsset {
    context.allocator = dpac.pac_storage.allocator

    ini := obj.value.(DPacInitializer)
    if atype, ok := dpac_asset_types[obj.type]; ok {
        if ini.anonymous {
            return load_initializer_anonymous(dpac, obj, atype)
        } else {
            return load_initializer_named(dpac, obj, atype)
        }
    } else {
        log.errorf("DPac: Asset type is not registered: {}", ini.type)
        return {}
    }
    return {}
}

load_initializer_anonymous :: proc(dpac: ^DPackage, obj: ^DPacObject, atype : DPacAssetType) -> DPackageAsset {
    ini := obj.value.(DPacInitializer)
    type_info := type_info_of(atype.type)
    core_type_info := reflect.type_info_core(type_info)
    if reflect.is_struct(core_type_info) {
        // Initializer is to build a struct.
        field_types   := reflect.struct_field_types(atype.type)
        field_offsets := reflect.struct_field_offsets(atype.type)
        if len(field_offsets) < len(ini.fields) {
            log.errorf("DPac: Too much elements in anonymous initializer. Expected: {}, actual: {}", 
                len(field_offsets), len(ini.fields))
            return DPackageAsset{nil, type_info.id}
        }

		bytes, err := mem.alloc(type_info.size)
		assert(err == .None, "Failed to allocate memory for dpac.")
        target := cast(^byte)bytes

        for f, ind in &ini.fields {
            fptr := mem.ptr_offset(target, field_offsets[ind])
            ftype := field_types[ind]
            value := dpac_load_value(dpac, &f.value)
            // TODO: Value type things.
            set_value(fptr, value, reflect.is_pointer(ftype))
            log.debugf("Anonymous field: {} - {}", ftype, value)
            if value.ptr == nil {
                log.errorf("DPac: Faild to load field: {} when load anonymous initializer.", f)
                free(target)
                return DPackageAsset{nil, type_info.id}
            }
        }
        return DPackageAsset{target, type_info.id}
    } else if reflect.is_array(core_type_info) {
        // Initializer is to build an array.
        using reflect
        array_type := core_type_info.variant.(Type_Info_Array)
        if len(ini.fields) > array_type.count {
            log.errorf("DPac: Too much elements to load array type {}. Expected: {}, actual: {}.", 
                type_info, array_type.count, len(ini.fields))
        }
		bytes, err := mem.alloc(array_type.elem_size * array_type.count)
		assert(err == .None, "Failed to allocate memory for dpac.")
        target := cast(^byte)bytes

        elem_is_pointer := is_pointer(type_info_core(array_type.elem))
        for field, ind in &ini.fields {
            fptr := mem.ptr_offset(target, ind * array_type.elem.size)
            data := dpac_load_value(dpac, &field.value)
            if data.ptr != nil {
                set_value(fptr, data, elem_is_pointer)
            } else {
                free(target)
                log.errorf("DPac: Failed to load value: {}", field.value)
                return {}
            }
        }
        return DPackageAsset{target, type_info.id}
    } else if reflect.is_slice(core_type_info) {
        using reflect
        slice_type := core_type_info.variant.(Type_Info_Slice)
        count := len(ini.fields)

		bytes, err := mem.alloc(slice_type.elem_size * count)
		assert(err == .None, "Failed to allocate memory for dpac.")
        target := cast(^byte)bytes

        elem_is_pointer := is_pointer(type_info_core(slice_type.elem))
        for field, ind in &ini.fields {
            fptr := mem.ptr_offset(target, ind * slice_type.elem_size)
            data := dpac_load_value(dpac, &field.value)
            if data.ptr != nil {
                set_value(fptr, data, elem_is_pointer)
            } else {
                free(target)
                log.errorf("DPac: Failed to load value: {}", field.value)
                return {}
            }
        }
        // target only stores the data
        the_slice := new(runtime.Raw_Slice)
        the_slice.data = target
        the_slice.len = count
        log.debugf("Load slice: {}", the_slice)
        return DPackageAsset{the_slice, type_info.id}
    }
    return {}
}

load_initializer_named :: proc(dpac: ^DPackage, obj: ^DPacObject, atype : DPacAssetType) -> DPackageAsset {
    ini := obj.value.(DPacInitializer)
    type_info := type_info_of(atype.type)
    field_names   := reflect.struct_field_names(atype.type)
    field_types   := reflect.struct_field_types(atype.type)
    field_offsets := reflect.struct_field_offsets(atype.type)

    if reflect.is_array(type_info) {
        log.errorf("DPac: It's invalid to initialize an array type by named initializer.")
        return DPackageAsset{nil, type_info.id}
    }
    if len(field_offsets) < len(ini.fields) {
        log.errorf("DPac: Too much elements in named initializer. Expected: {}, actual: {}", 
            len(field_offsets), len(ini.fields))
        return DPackageAsset{nil, type_info.id}
    }

	bytes, err := mem.alloc(type_info.size)
    target := cast(^byte)bytes
    for f, ind in &ini.fields {
        if f.field == "" do continue // Ignore anonymous fields.
        find := -1
        for af, aind in field_names {
            if af == f.field {
                find = aind
                break
            }
        }
        if find != -1 {
            ftype := field_types[find]
            foffset := field_offsets[find]
            fptr := mem.ptr_offset(target, foffset)
            data := dpac_load_value(dpac, &f.value)
            set_value(fptr, data, reflect.is_pointer(ftype))
        } else {
            log.errorf("DPac: Unknown field: {} in {}.", f.field, atype.type)
        }
    }
    return DPackageAsset{target, type_info.id}
}

@(private="file")
set_value :: proc(target : rawptr, data : DPackageAsset, by_pointer : bool) {
    if by_pointer {
        ptr := data.ptr
        mem.copy(target, &ptr, size_of(rawptr))
    } else {
        mem.copy(target, data.ptr, type_info_of(data.type).size)
    }
}

load_reference :: proc(dpac: ^DPackage, obj: ^DPacObject) -> DPackageAsset {
    data : DPackageAsset
    ref := obj.value.(DPacRef)
    key := dpac_key(ref.name)
    if symbol, ok := &dpac.symbols[key]; ok {
        if symbol.data.ptr == nil {// The data is not loaded.
            data = dpac_load_value(dpac, &symbol.obj)
            symbol.data = data
        } else {// The data has been loaded.
            data = symbol.data
        }
        return data
    } else {
        log.errorf("DPac: Unknown symbol: {}.", ref.name)
        return {}
    }
    return {}
}

// builtin_loader_color :: proc(dpac: ^DPackage, value: ^DPacObject) -> rawptr {
//     // name := value.name
//     // ini, ok := value.value.(DPacInitializer)
//     // if ok {
//     //     color := new(Color)
//     //     for i in 0..<len(ini.fields) {
//     //         v, ok := ini.fields[i].value.value.(DPacLiteral).(f32)
//     //         if !ok do v = cast(f32)ini.fields[i].value.value.(DPacLiteral).(i32)
//     //         color[i] = v
//     //     }
//     //     return color
//     // }
//     return nil
// }

// builtin_loader_shader :: proc(dpac: ^DPackage, value: ^DPacObject) -> rawptr {
//     // path := dpac_path_convert(dpac, value.load_path)
//     // defer delete(path)
//     // if !os.is_file(path) {
//     //     panic(fmt.tprintf("Invalid filepath: {}", path))
//     // }
//     // log.debugf("DPac: Load shader from: {}", path)
//     // source, ok := os.read_entire_file_from_filename(path)
//     // if !ok { return nil }
//     // id := dshader_load_from_source(cast(string)source)
//     // delete(source)

//     // if id == 0 { return nil }

//     // shader := new(DShader)
//     // shader.id = id

//     // return shader
//     return nil
// }

// builtin_loader_texture :: proc(dpac: ^DPackage, value: ^DPacObject) -> rawptr {
//     // path := dpac_path_convert(dpac, value.load_path)
//     // defer delete(path)
//     // if !os.is_file(path) {
//     //     panic(fmt.tprintf("Invalid filepath: {}", path))
//     // }
//     // log.debugf("DPac: Load texture from : {}", path)

//     // tex := dgl.texture_load(path)
//     // if tex.id == 0 do return nil
//     // ptex := new(Texture)
//     // ptex^ = Texture{
//     //     size = tex.size,
//     //     id = tex.id,
//     // }
//     // return cast(rawptr)ptex
//     return nil
// }
