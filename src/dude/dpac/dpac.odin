package dpac

import "core:math/linalg"
import "core:log"
import "core:mem"
import "core:math/rand"
import "core:fmt"
import "core:slice"
import "core:strconv"
import "core:os"
import "core:runtime"
import "core:reflect"
import "core:bytes"
import "core:strings"
import "core:encoding/json"


// Dpackage is designed to use a struct as the meta data for a dpackage.
// Use field tag: dpac to indicate the file path. If a field is not tagged 
//  by `dpac` and it's a struct, the dpac will take it as a nested struct.
// You can tag an array/slice's load path like "./res/texture_$(index).png"
//  the index should be continuous.

// TODO: Endian is not handled.

MAGIC :[4]u8: {'D','P','A','C'}
VERSION :u32: 1

bundle :: proc($T: typeid, allocator:= context.allocator) -> []byte {
    using strings
    b : Builder
    builder_init(&b)
    _write_object(&b, PackageHeader{transmute(u32)MAGIC, VERSION})

    if _bundle_struct(&b, type_info_of(T)) {
        fmt.printf("bundle success, size: {} bytes.", builder_len(b))
        return transmute([]u8)to_string(b)
    } else {
        builder_destroy(&b)
        fmt.printf("bundle failed.")
        return {}
    }
}

_bundle :: proc(b: ^strings.Builder, t: ^reflect.Type_Info, tag: string) -> bool {
    if reflect.is_struct(t) {
        if tag != "" do return _bundle_asset(b, t, cast(string)tag)
        else do return _bundle_struct(b, t)
    } else if reflect.is_array(t) || reflect.is_slice(t) {
        return _bundle_array(b, t, cast(string)tag)
    } else {
        return _bundle_asset(b, t, cast(string)tag)
    }
}

_bundle_struct :: proc(b: ^strings.Builder, type: ^reflect.Type_Info) -> bool {
    using strings

    types := reflect.struct_field_types(type.id)
    tags := reflect.struct_field_tags(type.id)
    header : BlockHeader
    header.type = .NestedStruct
    header.info.count = auto_cast len(types)
    _write_object(b, header)

    for i in 0..<header.info.count {
        t := types[i]
        tag, has_dpac_tag := reflect.struct_tag_lookup(tags[i], "dpac")
        if !_bundle(b, t, auto_cast tag) do return false
    }
    return true
}

// Array or slice
_bundle_array :: proc(b: ^strings.Builder, type: ^reflect.Type_Info, tag: string) -> bool {
    assert(tag != "", "Array field must be tagged by dpac.")
    using strings
    elem_type : ^reflect.Type_Info
    elem_count : int = -1
    if reflect.is_array(type) {
        array := type.variant.(reflect.Type_Info_Array)
        elem_type = array.elem
        elem_count = array.count
    } else if reflect.is_slice(type) {
        slice := type.variant.(reflect.Type_Info_Slice)
        elem_type = slice.elem
    }

    header_offset := transmute(uintptr)builder_len(b^)
    _write_object(b, BlockHeader{})
    header := cast(^BlockHeader)(transmute(uintptr)(&b.buf[0])+header_offset)
    header.type = .Array
    // @OPTIMIZE:
    index_buffer : [6]u8
    for i in 0..<(elem_count if elem_count > 0 else 0xffffffff) {
        path, was_allocation := strings.replace_all(tag, "$(index)", strconv.append_uint(index_buffer[:], cast(u64)i, 10))
        if was_allocation do defer delete(path)
        if data, ok := os.read_entire_file_from_filename(path); ok {
            fmt.printf("bundle: {}\n", path)
            write_bytes(b, data)
            header.info.count += 1
        } else {
            return true
        }
        if !was_allocation && elem_count == -1 do break
    }
    return true
}

_bundle_asset :: proc(b: ^strings.Builder, type: ^reflect.Type_Info, tag: string) -> bool {
    using strings
    header_offset := transmute(uintptr)builder_len(b^)
    _write_object(b, BlockHeader{})

    header := cast(^BlockHeader)(transmute(uintptr)(&b.buf[0])+header_offset)
    header.type = .Data
    header.info.index.from = cast(i64)builder_len(b^)
    defer header.info.index.to = cast(i64)builder_len(b^)

    if data, ok := os.read_entire_file_from_filename(tag); ok {
        write_bytes(b, data)
        fmt.printf("bundle: {}\n", tag)
        return true
    } else {
        return false
    }
}

_write_object :: proc(b: ^strings.Builder, obj: $T) {
    obj := (transmute([size_of(T)]u8)obj)
    strings.write_bytes(b, obj[:])
}

PackageHeader :: struct {
    magic : u32,
    version : u32,
}
BlockHeader :: struct {
    type : BlockType,
    info : struct #raw_union {
        count : u32,
        index : BlockIndex,
    },
}
BlockIndex :: struct {
    from,to : i64,
}

BlockType :: enum u32 {
    Data,
    Array,
    NestedStruct,
}