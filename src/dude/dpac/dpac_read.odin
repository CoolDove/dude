package dpac

import "core:io"
import "core:bufio"
import "core:reflect"
import "core:mem"
import "core:runtime"

LoadErr :: enum {
    None = 0,
    Unknown,
    InvalidPac_PacTooSmall,
    InvalidPac_NotADPac,
    InvalidPac_VersionNotMatch,
    InvalidPac_UntaggedArrayOrSlice,
    PacStructMissmatch_ArrayOrSliceCount,
}


DPacLoader :: struct {
    buf : []u8,
    ptr : int,
}

load :: proc(pac: []u8, p: rawptr, t: ^reflect.Type_Info) -> LoadErr {
    loader := DPacLoader{pac, 0}

    if len(pac) < size_of(PackageHeader) do return .InvalidPac_PacTooSmall
    header := (cast(^PackageHeader)raw_data(pac))^
    loader.ptr += size_of(PackageHeader)
    if header.magic != transmute(u32)MAGIC do return .InvalidPac_NotADPac
    if header.version != VERSION {
        return .InvalidPac_VersionNotMatch
    }

    err := _load_struct(&loader, p, t)
    return err
}

_data_handler_default :: proc(p: rawptr, t: ^reflect.Type_Info, data: []u8) {
}

_load :: proc(loader: ^DPacLoader, p: rawptr, t: ^reflect.Type_Info, tag: string) -> LoadErr {
    if reflect.is_struct(t) {
        if tag != "" do return _load_asset(loader, p, t, cast(string)tag)
        else do return _load_struct(loader, p, t)
    } else if reflect.is_array(t) || reflect.is_slice(t) {
        return _load_array(loader, p, t, cast(string)tag)
    } else {
        return _load_asset(loader, p, t, cast(string)tag)
    }
}
_load_struct :: proc(loader: ^DPacLoader, p: rawptr, t: ^reflect.Type_Info) -> LoadErr {
    if header, ok := _load_header(loader); ok {
        if header.type != .NestedStruct do return .Unknown
        types := reflect.struct_field_types(t.id)
        offsets := reflect.struct_field_offsets(t.id)
        tags := reflect.struct_field_tags(t.id)
        for i in 0..<len(types) {
            err := _load(loader, cast(rawptr)(cast(uintptr)p+offsets[i]), types[i], cast(string)tags[i])
            if err != .None do return err
        }
        return .None
    } else {
        return .Unknown
    }
}
// Array or slice
_load_array :: proc(loader: ^DPacLoader, p: rawptr, t: ^reflect.Type_Info, tag: string) -> LoadErr {
    if tag == "" do return .InvalidPac_UntaggedArrayOrSlice
    if header, ok := _load_header(loader); ok {
        elem_count := header.info.count
        elem_type : ^reflect.Type_Info
        ptr := p
        if reflect.is_array(t) {
            tarray := t.variant.(reflect.Type_Info_Array)
            if cast(u32)tarray.count != elem_count do return .PacStructMissmatch_ArrayOrSliceCount
            elem_type = tarray.elem
        } else if reflect.is_slice(t) {
            elem_type = t.variant.(reflect.Type_Info_Slice).elem
            elem_buffer := make_slice([]u8, elem_count * cast(u32)elem_type.size)
            the_slice := cast(^runtime.Raw_Slice)p
            ptr = raw_data(elem_buffer)
            the_slice.data = ptr
            the_slice.len = cast(int)elem_count
        }
        for i in 0..<elem_count {
            err := _load(loader, ptr, elem_type, tag)
            if err != .None do return err
            ptr = cast(rawptr)(cast(uintptr)ptr + cast(uintptr)elem_type.size)
        }
    }
    return .None
}

@private
_load_asset :: proc(loader: ^DPacLoader, p: rawptr, t: ^reflect.Type_Info, tag: string) -> LoadErr {
    header, ok := _load_header(loader)
    if ok && header.type == .Data {
        index := header.info.index
        _data_handler_default(p, t, loader.buf[index.from:index.to])
        loader.ptr = cast(int)index.to
        return .None
    }
    return .Unknown
}

_load_header :: proc(using loader: ^DPacLoader, peek:= false) -> (BlockHeader, bool) {
    if len(buf) - ptr < size_of(BlockHeader) do return {}, false
    h := cast(^BlockHeader)&buf[ptr]
    if !peek do ptr += size_of(BlockHeader)
    return h^, true
}