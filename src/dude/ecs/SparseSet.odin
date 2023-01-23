package ecs

import "core:mem"


// NOTE: Doesn't support resizing currently.

spsset_make :: proc($T: typeid, count: u32, allocator:= context.allocator) -> SparseSet(T) {
    context.allocator = allocator
    spsset : SparseSet(T)
    spsset.dense  = make([dynamic]SparseSetNode(T), 0, count)
    spsset.sparse = make([dynamic]u32, count, count)
    return spsset
}
spsset_destroy :: proc(using spsset: ^$T/SparseSet) {
    delete(dense)
    delete(sparse)
}

spsset_contain :: proc(using spsset: ^$T/SparseSet, id: u32) -> bool {
    if id >= cast(u32)len(sparse) do return false
    index := sparse[id]
    if index >= cast(u32)len(dense) do return false
    return dense[index].id == id
}

// Get the data copy.
spsset_get :: proc(using spsset: ^SparseSet($T), id : u32) -> (data: T, ok: bool) #optional_ok {
    if !spsset_contain(spsset, id) do return T{}, false
    return dense[sparse[id]].data, true
}
// Find the data address.
spsset_find :: proc(using spsset: ^SparseSet($T), id : u32) -> (data: ^T, ok: bool) #optional_ok {
    if !spsset_contain(spsset, id) do return nil, false
    return &dense[sparse[id]].data, true
}

spsset_add :: proc(using spsset: ^$SSet/SparseSet, index: u32, data : $T) -> bool {
    // Repeated value is not allowed in a sparse set.
    if spsset_contain(spsset, index) do return false 
    if len(spsset.dense) >= len(spsset.sparse) do return false
    sparse_index := len(&dense)
    append(&dense, SparseSetNode(T){index, data})
    sparse[index] = cast(u32)sparse_index
    return true
}

spsset_remove :: proc(using spsset: ^$T/SparseSet, value: u32) -> bool {
    if !spsset_contain(spsset, value) do return false
    index := sparse[value]
    {// Exchange the target element and the last element.
        t := dense[index]
        sparse[value] = 0
        sparse[dense[len(dense) - 1].id] = index
        dense[index] = dense[len(dense) - 1]
        dense[len(dense) - 1] = t
    }
    pop(&dense)
    return true
}
spsset_len :: proc(using spsset: ^$T/SparseSet) -> int {
    return len(dense)
}
spsset_cap :: proc(using spsset: ^$T/SparseSet) -> int {
    return len(sparse)
}

SparseSet :: struct($T: typeid) {
    dense  : [dynamic]SparseSetNode(T),
    sparse : [dynamic]u32,
}

SparseSetNode :: struct($T: typeid) {
    id : u32,
    data : T,
}