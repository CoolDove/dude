package ecs

import "core:strings"
import "core:math/linalg"
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

ComponentPool :: struct {
    // this is not to be used as [dynamic]any, 
    components : [dynamic]any,
    dead : Stack,
}

ComponentMap :: map[typeid]ComponentPool

Component :: struct {
    entity : Entity,
}

add_component :: proc {
    add_component_by_type,
    add_component_by_data,
}
add_component_by_type :: proc(world: ^World, entity: Entity, $T: typeid) -> ^T {
    return add_component(world, entity, T{})
}
add_component_by_data :: proc(world: ^World, entity: Entity, component: $T) -> ^T {
    if !(T in world.components) {
        world.components[T] = ComponentPool{make([dynamic]any), stack_create()}
    }
    pool := &world.components[T]
    components := transmute(^[dynamic]T)&pool.components
    append(components, component)
    component_id := cast(u32)(len(components) - 1)
    comp := &components[component_id]
    {
        base_ptr := transmute(^Component)comp
        base_ptr.entity = entity
    }
    data := spsset_find(&world.entities, cast(u32)entity)
    append(data, EntityComponentInfo{component_id, T})
    return comp
}

get_components :: proc(world: ^World, $T: typeid) -> []T {
    if comps, ok := world.components[T]; ok {
        return (transmute([dynamic]T)comps.components)[:]
    } else {
        return nil
    }
}

// ## Test Components
// Some built-in components to test the ecs system.

SpriteRenderer :: struct {
    using component : Component,// THIS IS WHAT A GAME COMPONENT NEEDS! SHOULD BE PLACED AT FIRST.
    texture_id : u32,
    size, pos, pivot : linalg.Vector2f32,
}

TextRenderer :: struct {
    text : ^strings.Builder,
    dirty_flag : bool,
    pos : linalg.Vector2f32,
}