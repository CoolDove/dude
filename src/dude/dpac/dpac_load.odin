package dpac

import "core:log"
import "core:os"
import "core:strings"
import "core:fmt"
import "core:mem"
import "core:runtime"
import "core:reflect"
import "core:path/filepath"

DPacResLoader :: proc(value:^DPacObject) -> rawptr

@(private="file")
dpac_resource_loaders : map[typeid]DPacResLoader

DPacErr_Load :: enum {
    None, TypeMismatch, UnknownField, TooMuchFields,
}

// NOTE(Dove): DPackage Load Process
// Allocate the asset data in `pac_storage`, then set the symbol data in the dpackage meta.

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
            ret^ = strings.clone(str)
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
            return load_initializer_anonymous(dpac, &ini, atype)
        } else {
            return load_initializer_named(dpac, &ini, atype)
        }
    } else {
        log.errorf("DPac: Asset type is not registered: {}", ini.type)
        return {}
    }
    return {}
}

load_initializer_anonymous :: proc(dpac: ^DPackage, ini: ^DPacInitializer, atype : DPacAssetType) -> DPackageAsset {
    type_info := type_info_of(atype.type)
    field_types   := reflect.struct_field_types(atype.type)
    field_offsets := reflect.struct_field_offsets(atype.type)
    if len(field_offsets) < len(ini.fields) {
        log.errorf("DPac: Too much elements in anonymous initializer. Expected: {}, actual: {}", 
            len(field_offsets), len(ini.fields))
        return DPackageAsset{nil, type_info.id}
    }
    obj := cast(^byte)mem.alloc(type_info.size)
    for f, ind in &ini.fields {
        fptr := mem.ptr_offset(obj, field_offsets[ind])
        ftype := field_types[ind]
        err := set_field_value(dpac, obj, ftype, field_offsets[ind], &f.value)
        if err != .None {
            log.errorf("DPac: Error {} occured when load anonymous initializer.", err)
            free(obj)
            return DPackageAsset{nil, type_info.id}
        }
    }
    return DPackageAsset{obj, type_info.id}
}

load_initializer_named :: proc(dpac: ^DPackage, ini: ^DPacInitializer, atype : DPacAssetType) -> DPackageAsset {
    type_info := type_info_of(atype.type)
    field_names   := reflect.struct_field_names(atype.type)
    field_types   := reflect.struct_field_types(atype.type)
    field_offsets := reflect.struct_field_offsets(atype.type)
    if len(field_offsets) < len(ini.fields) {
        log.errorf("DPac: Too much elements in named initializer. Expected: {}, actual: {}", 
            len(field_offsets), len(ini.fields))
        return DPackageAsset{nil, type_info.id}
    }

    obj := cast(^byte)mem.alloc(type_info.size)
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
            set_field_value(dpac, obj, ftype, foffset, &f.value)
        } else {
            log.errorf("DPac: Unknown field: {} in {}.", f.field, atype.type)
        }
    }
    return DPackageAsset{obj, type_info.id}
}

set_field_value :: proc(dpac: ^DPackage, obj: ^byte, ftype: ^runtime.Type_Info, foffset: uintptr, value_node: ^DPacObject) -> DPacErr_Load {
    fptr := mem.ptr_offset(obj, foffset)
    value := dpac_load_value(dpac, value_node)
    if lit, ok := value_node.value.(DPacLiteral); ok {
        // ## Load literal value
        if pointer_type, ok := ftype.variant.(reflect.Type_Info_Pointer); ok {
            base_type := runtime.type_info_core(pointer_type.elem).id
            mismatch := false
            switch lit_type in lit {
            case f32 :
                if base_type != typeid_of(f32) do mismatch = true
            case i32 :
                if base_type != typeid_of(i32) do mismatch = true
            case string :
                if base_type != typeid_of(string) do mismatch = true
            }
            if mismatch {
                log.errorf("DPac: Pointer field type mismatch.")
                return .TypeMismatch
            }
            mem.copy(fptr, &value, size_of(rawptr))
        } else {
            set_lit :: proc(dst, src: rawptr, T: typeid, info: ^reflect.Type_Info) -> bool {
                if info.id != T do return false
                mem.copy(dst, src, size_of(T))
                return true
            }
            copy_size := 0
            switch lit_type in lit {
            case string:
                if ftype.id == string {
                    str_ptr := transmute(^string)fptr
                    src_str := (transmute(^string)value.ptr)^
                    str_ptr^ = strings.clone(src_str[1:len(src_str) - 1])
                } else {
                    log.errorf("DPac: Invalid literal: {}", lit)
                    return .TypeMismatch
                }
            case f32:
                if !set_lit(fptr, value.ptr, f32, ftype) {
                    log.errorf("DPac: Invalid literal: {}", lit)
                    return .TypeMismatch
                }
            case i32:
                if !set_lit(fptr, value.ptr, i32, ftype) {
                    log.errorf("DPac: Invalid literal: {}", lit)
                    return .TypeMismatch
                }
            }
        }
    } else if ini, ok := value_node.value.(DPacInitializer); ok {
        // ## Load initializer value
        using reflect
        obj := load_initializer(dpac, value_node)
        value_type := type_info_of(dpac_asset_types[value_node.type].type)
        if reflect.is_pointer(ftype) {
            pointer_type := ftype.variant.(Type_Info_Pointer).elem
            if pointer_type != value_type {
                log.errorf("DPac: Field value type mismatch: Expected: {}, but actually {}.", pointer_type.id, value_type.id)
                return .TypeMismatch
            } else {
                mem.copy(fptr, &obj, size_of(rawptr))
            }
        } else {
            if ftype.id != value_type.id {
                log.errorf("DPac: Field value type mismatch: Expected: {}, but actually {}.", ftype.id, value_type.id)
                return .TypeMismatch
            } else {
                mem.copy(fptr, obj.ptr, ftype.size)
            }
        }
    } else if ref, ok := value_node.value.(DPacRef); ok {
        log.warnf("DPac: loading reference.")
        if (ref.pac == "") {
            key := dpac_key(ref.name)
            if symbol, ok := dpac.symbols[key]; ok {
                ref_data := load_reference(dpac, value_node)
                set_reference_value(fptr, &ref_data, reflect.is_pointer(ftype))
            }
        } else {
            panic("DPac: Only support ref to the same package for now.")
        }
    }
    return .None
}

set_reference_value :: proc(target : ^byte, data : ^DPackageAsset, by_pointer : bool) {
    if by_pointer {
        mem.copy(target, &data.ptr, size_of(rawptr))
    } else {
        mem.copy(target, data.ptr, size_of(data.type))
    }
}

load_reference :: proc(dpac: ^DPackage, obj: ^DPacObject) -> DPackageAsset {
    data : DPackageAsset
    ref := obj.value.(DPacRef)
    key := dpac_key(ref.name)
    if symbol, ok := dpac.symbols[key]; ok {
        if symbol.data.ptr == nil {// The data is not loaded.
            data = dpac_load_value(dpac, &symbol.obj)
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