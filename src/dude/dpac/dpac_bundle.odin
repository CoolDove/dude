package dpac

import "core:fmt"
import "core:slice"
import "core:strconv"
import "core:os"
import "core:reflect"
import "core:bytes"
import "core:encoding/endian"
import "core:strings"

@private
_bundle :: proc(b: ^strings.Builder, t: ^reflect.Type_Info, tag: string) -> bool {
    if reflect.is_struct(t) {
        if tag != "" do return _bundle_asset(b, cast(string)tag)
        else do return _bundle_struct(b, t)
    } else if reflect.is_array(t) || reflect.is_slice(t) {
        return _bundle_array(b, t, cast(string)tag)
    } else {
        return _bundle_asset(b, cast(string)tag)
    }
}

@private
_bundle_struct :: proc(b: ^strings.Builder, type: ^reflect.Type_Info) -> bool {
    using strings

    types := reflect.struct_field_types(type.id)
    tags := reflect.struct_field_tags(type.id)
    _write_header(b, BlockHeader{.NestedStruct, {count=auto_cast len(types)}})

    for i in 0..<len(types) {
        t := types[i]
        tag, has_dpac_tag := reflect.struct_tag_lookup(tags[i], DPAC_TAG)
        if !_bundle(b, t, auto_cast tag) do return false
    }
    return true
}

// Array or slice
@private
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

    header_offset := _write_header(b, BlockHeader{type=.Array})
    // @OPTIMIZE:
    index_buffer : [6]u8
    slice_elem_count := 0
    for i in 0..<(elem_count if elem_count > 0 else 0xffffffff) {
        path, was_allocation := strings.replace_all(tag, "$(index)", strconv.append_uint(index_buffer[:], cast(u64)i, 10))
        if was_allocation do defer delete(path)
        if data, ok := os.read_entire_file_from_filename(path); ok {
            fmt.printf("bundle: {}\n", path)
            // write_bytes(b, data)
            _bundle_asset(b, path)
            // header := cast(^BlockHeader)_string_builder_point(b, header_offset)
            // header.info.count += 1
            slice_elem_count += 1
        } else {
            header := cast(^BlockHeader)_string_builder_point(b, header_offset)
            header.info.count = auto_cast slice_elem_count
            return true
        }
        if !was_allocation && elem_count == -1 do break
    }
    return true
}

@private
_bundle_asset :: proc(b: ^strings.Builder, tag: string) -> bool {
    using strings
    header_offset := _write_header(b, BlockHeader{.Data, {index=BlockIndex{cast(i64)builder_len(b^),0}}})
    defer {
        header := cast(^BlockHeader)_string_builder_point(b, header_offset)
        header.info.index.to = cast(i64)builder_len(b^)
    }

    if data, ok := os.read_entire_file_from_filename(tag); ok {
        write_bytes(b, data)
        fmt.printf("bundle: {}\n", tag)
        return true
    } else {
        return false
    }
}

@private
_write_header :: proc(b: ^strings.Builder, header: BlockHeader) -> uintptr {
    obj := header
    ptr := strings.builder_len(b^)
    strings.write_bytes(b, slice.bytes_from_ptr(&obj, size_of(BlockHeader)))
    return auto_cast ptr
}

@private
_string_builder_point :: proc(b: ^strings.Builder, offset: uintptr) -> rawptr {
    return cast(rawptr)(transmute(uintptr)(&b.buf[0])+offset)
}

PackageHeader :: struct {
    magic : u32,
    version : u32,
    endian : u32,
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