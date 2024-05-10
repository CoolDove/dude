package dpac

import "core:slice"
import "core:strconv"
import "core:os"
import "core:reflect"
import "core:bytes"
import "core:encoding/endian"
import "core:strings"


BundleErr :: enum {
    None,
    FailedToLoadData,
    InvalidPac_UntaggedArrayOrSlice,
}

// Stored with little endian.
bundle :: proc(T: typeid, allocator:= context.allocator) -> (output: []byte, err: BundleErr) {
    using strings
    b : Builder
    builder_init(&b)

    dpac_header := PackageHeader{transmute(u64)MAGIC, VERSION}
    // write_bytes(&b, slice.bytes_from_ptr(&dpac_header, size_of(PackageHeader)))
    _write_package_header(&b, dpac_header)

    if err = _bundle_struct(&b, type_info_of(T)); err == .None {
        return transmute([]u8)to_string(b), err
    } else {
        builder_destroy(&b)
        return {}, err
    }
}

@private
_bundle :: proc(b: ^strings.Builder, t: ^reflect.Type_Info, tag: string) -> BundleErr {
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
_bundle_struct :: proc(b: ^strings.Builder, type: ^reflect.Type_Info) -> BundleErr {
    using strings

    types := reflect.struct_field_types(type.id)
    tags := reflect.struct_field_tags(type.id)
    _write_header(b, BlockHeader{.NestedStruct, {count=auto_cast len(types)}})

    for i in 0..<len(types) {
        t := types[i]
        tag, has_dpac_tag := reflect.struct_tag_lookup(tags[i], DPAC_TAG)
        if err := _bundle(b, t, auto_cast tag); err != .None do return err
    }
    return .None
}

// Array or slice
@private
_bundle_array :: proc(b: ^strings.Builder, type: ^reflect.Type_Info, tag: string) -> BundleErr {
    assert(tag != "", "Array field must be tagged by dpac.")
    if tag == "" do return .InvalidPac_UntaggedArrayOrSlice
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
            _bundle_asset(b, path)
            slice_elem_count += 1
        } else {
            header := cast(^BlockHeader)_string_builder_point(b, header_offset)
            header.info.count = auto_cast slice_elem_count
            return .None
        }
        if !was_allocation && elem_count == -1 do break
    }
    return .None
}

@private
_bundle_asset :: proc(b: ^strings.Builder, tag: string) -> BundleErr {
    using strings
    header_offset := _write_header(b, BlockHeader{})
    defer {
        header := cast(^BlockHeader)_string_builder_point(b, header_offset)
        header.type = .Data
        header.info.index.from = cast(u64)(header_offset + cast(uintptr)size_of(BlockHeader))
        header.info.index.to = cast(u64)builder_len(b^)
    }

    if data, ok := os.read_entire_file_from_filename(tag); ok {
		defer delete(data)
        write_bytes(b, data)
        return .None
    } else {
        return .FailedToLoadData
    }
}

@private// Returns where does the header begin.
_write_header :: proc(b: ^strings.Builder, header: BlockHeader) -> uintptr {
    ptr := strings.builder_len(b^)
    endian.put_u64(_sb_step(b, size_of(u64)), .Little, transmute(u64)header.type)
    switch header.type {
    case .Data:
        endian.put_u64(_sb_step(b, size_of(u64)), .Little, transmute(u64)header.info.index.from)
        endian.put_u64(_sb_step(b, size_of(u64)), .Little, transmute(u64)header.info.index.to)
    case .NestedStruct: fallthrough
    case .Array:
        endian.put_u64(_sb_step(b, size_of(u64)), .Little, cast(u64)header.info.count)
    }
    return auto_cast ptr
}
@private
_write_package_header :: proc(b: ^strings.Builder, header: PackageHeader) {
    h := header
    endian.put_u64(_sb_step(b, size_of(u64)), .Little, h.magic)
    endian.put_u64(_sb_step(b, size_of(u64)), .Little, h.version)
}

@private
_sb_step :: proc(b: ^strings.Builder, size: i32) -> []u8 {
    ptr := cast(uintptr)strings.builder_len(b^)
    for i in 0..<size {
        strings.write_byte(b, 0)
    }
    return slice.bytes_from_ptr(cast(rawptr)(transmute(uintptr)raw_data(b.buf)+ptr), auto_cast size)
}

@private
_string_builder_point :: proc(b: ^strings.Builder, offset: uintptr) -> rawptr {
    return cast(rawptr)(transmute(uintptr)(&b.buf[0])+offset)
}

PackageHeader :: struct {
    magic : u64,
    version : u64,
}
BlockHeader :: struct {
    type : BlockType,
    info : struct #raw_union {
        count : u64, // For .Array and .NestedStruct, indicates the count of elements or fields.
        index : BlockIndex, // For .Data, indicates the start ptr and the end ptr in this dpac.
    },
}
BlockIndex :: struct {
    from,to : u64,
}

BlockType :: enum u64 {
    Data,
    Array,
    NestedStruct,
}
