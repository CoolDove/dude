package ecs

import "core:mem"


// NOTE: Doesn't support resizing currently.

spsset_make :: proc(count: u32, allocator:= context.allocator) -> SparseSet {
    context.allocator = allocator
    spsset : SparseSet
    spsset.dense  = make([dynamic]u32, 0, count)
    spsset.sparse = make([dynamic]u32, count, count)
    return spsset
}

spsset_contain :: proc(using spsset: ^SparseSet, value: u32) -> bool {
    if value >= cast(u32)len(sparse) do return false
    index := sparse[value]
    if index >= cast(u32)len(dense) do return false
    return dense[index] == value
}

spsset_add_multiple :: proc(using spsset: ^SparseSet, values: ..u32) {
    for value in values do spsset_add(spsset, value)
}
spsset_add :: proc(using spsset: ^SparseSet, value: u32) -> bool {
    // Repeated value is not allowed in a sparse set.
    if spsset_contain(spsset, value) do return false 
    if spsset_len(spsset) >= spsset_cap(spsset) do return false
    sparse_index := len(&dense)
    append(&dense, value)
    sparse[value] = cast(u32)sparse_index
    return true
}

spsset_remove_multiple :: proc(using spsset: ^SparseSet, values: ..u32) {
    for value in values do spsset_remove(spsset, value)
}
spsset_remove :: proc(using spsset: ^SparseSet, value: u32) -> bool {
    if !spsset_contain(spsset, value) do return false
    index := sparse[value]
    {// Exchange the target element and the last element.
        t := dense[index]
        sparse[value] = 0
        sparse[dense[len(dense) - 1]] = index
        dense[index] = dense[len(dense) - 1]
        dense[len(dense) - 1] = t
    }
    pop(&dense)
    return true
}
spsset_len :: proc(using spsset: ^SparseSet) -> int {
    return len(dense)
}
spsset_cap :: proc(using spsset: ^SparseSet) -> int {
    return len(sparse)
}

SparseSet :: struct {
    dense  : [dynamic]u32,
    sparse : [dynamic]u32,
}