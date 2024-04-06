package collections


import "core:runtime"

Stack :: struct {
    top : ^StackNode,
    count : u32,
    allocator : runtime.Allocator,
}
StackNode :: struct {
    data : u32, 
    prev : ^StackNode,
}

stack_create :: proc(allocator:= context.allocator) -> Stack {
    return Stack{nil, 0, allocator}
}
stack_push :: proc(stack: ^Stack, data: u32) {
    context.allocator = stack.allocator
    node := new (StackNode)
    node.data = data 
    node.prev = stack.top
    stack.top = node
    stack.count += 1
}
stack_pop :: proc(stack: ^Stack) -> (data: u32, ok: bool) #optional_ok {
    if stack.count == 0 do return 0, false
    node := stack.top
    data = node.data
    stack.top = node.prev
    free(node)
    stack.count -= 1
    return data, true
}
stack_peek :: proc(stack: ^Stack) -> (data: u32, ok: bool) #optional_ok {
    if stack.count == 0 do return 0, false
    return stack.top.data, true
}