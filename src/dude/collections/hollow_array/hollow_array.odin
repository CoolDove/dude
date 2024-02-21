package hollow_array


HollowArray :: struct($T:typeid) {
    buffer : [dynamic]HollowArrayValue(T),
    dead_idx : [dynamic]int,
    count, id_access : int,
}
HollowArrayValue :: struct($T:typeid) {
    value:T,
    id: int,// When id < 0, the value is empty.
}

HollowArrayHandle :: struct($T:typeid) {
    hollow_array: ^HollowArray(T),
    index : int,
    id : int,
}

hla_make :: proc($T: typeid, capacity:= 0, allocator:= context.allocator) -> HollowArray(T) {
    context.allocator = allocator
    hla : HollowArray(T)
    using hla
    buffer = make_dynamic_array_len_cap([dynamic]HollowArrayValue(T), 0, capacity)
    dead_idx = make([dynamic]int)
    return hla
}
hla_delete :: proc(using hla: ^HollowArray($T)) {
    delete(buffer)
    delete(dead_idx)
    hla^ = {}
}
hla_clear :: proc(using hla: ^HollowArray($T)) {
    clear(&buffer)
    clear(&dead_idx)
    count, id_access = 0,0
}

hla_append :: proc(using hla : ^HollowArray($T), elem: T) -> HollowArrayHandle(T) {
    index : int
    obj : ^HollowArrayValue(T)
    if len(dead_idx) > 0 {
        index = pop(&dead_idx)
        obj = &buffer[index]        
    } else {
        append(&buffer, HollowArrayValue(T){})
        index = len(buffer) - 1
        obj = &buffer[index]
    }
    obj.value = elem
    obj.id = id_access
    id_access += 1
    count += 1
    return {
        hla,
        index,
        obj.id,
    }
}

hla_remove :: proc {
    hla_remove_index,
    hla_remove_handle,
}
hla_remove_index :: proc(using hla : ^HollowArray($T), index: int) {
    if index >= len(hla.buffer) do return
    ptr := &hla.buffer[index]
    if ptr.id >= 0 {
        ptr.id = -1
        count -= 1
        append(&dead_idx, index)
    }
}
hla_remove_handle :: proc(using handle: HollowArrayHandle($T)) {
    using handle.hollow_array
    if index >= len(buffer) do return
    ptr := &buffer[index]
    if ptr.id >= 0 && ptr.id == id {
        ptr.id = -1
        count -= 1
        append(&dead_idx, index)
    }
}

hla_get :: proc {
    hla_get_value,
    hla_get_pointer,
}
hla_get_value :: proc(using handle: HollowArrayHandle($T)) -> (T, bool) #optional_ok {
    if hollow_array == nil do return {}, false
    using hollow_array
    v := buffer[index]
    if v.id != id do return {}, false
    return v, true
}
hla_get_pointer :: proc(using handle: HollowArrayHandle($T)) -> (^T, bool) #optional_ok {
    if hollow_array == nil do return nil, false
    using hollow_array
    v := &buffer[index]
    if v.id != id do return nil, false
    return &v.value, true
}

hla_ite :: proc(using hla: ^HollowArray($T), buffer_index:^int, alive_index:^int=nil) -> (^T, bool) {
    assert(buffer_index!=nil, "HollowArray: Invalid iterator.")
    if count == 0 do return nil, false

    if buffer_index^ == 0 && alive_index != nil do alive_index^= -1

    for i in buffer_index^..<len(hla.buffer) {
        v := &hla.buffer[i]
        // TODO: Check if this buffer_index is correct.
        buffer_index^ += 1
        if v.id < 0 do continue
        if alive_index != nil do alive_index^ += 1
        return &v.value, true
    }
    return nil, false
}