package ecs

import "core:strings"
import "core:math/linalg"
import "core:runtime"
import "core:reflect"
import "core:slice"
import "core:intrinsics"

ComponentPool :: struct {
    // Should be cast/transmuted to [dynamic]T before using.
    components : runtime.Raw_Dynamic_Array,
    entities : map[Entity]u32, // Map entity id to the index of its component.
}

ComponentMap :: map[typeid]ComponentPool

Component :: struct {
    entity  : Entity,
}

add_component :: proc {
    add_component_by_type,
    add_component_by_data,
}
add_component_by_type :: proc(world: ^World, entity: Entity, $T: typeid) -> ^T {
    return add_component(world, entity, T{})
}
add_component_by_data :: proc(world: ^World, entity: Entity, component: $T) -> ^T {
    component_type := component_type_check(T)
    if component_type == ComponentType.Invalid do return nil

    if !(T in world.components) {// If the component type hasn't been registered.
        world.components[T] = ComponentPool{
            transmute(runtime.Raw_Dynamic_Array)make([dynamic]any),
            make(map[Entity]u32)}
    }
    pool := &world.components[T]
    components := cast(^[dynamic]T)&pool.components
    append(components, component)// Append new component.
    component_id := cast(u32)(len(components) - 1)
    pool.entities[entity] = component_id
    comp := &components[component_id]
    if component_type == .ComponentBased {
        // Set up basic Component things.
        base_ptr := transmute(^Component)comp
        base_ptr.entity = entity
    }
    return comp
}

ComponentType :: enum {
    Invalid,        // Invalid struct for a component.
    ComponentBased, // Has a `component: Component` as the first field.
    SimpleComponent,// Just any struct.
}

component_type_check :: proc($T: typeid) -> ComponentType {
    info := type_info_of(T)
    if reflect.is_struct(info) {
        field_types := reflect.struct_field_types(T)
        if len(field_types) > 0 && field_types[0].id == Component {
            return .ComponentBased
        } else {
            return .SimpleComponent
        }
    } else {
        return .Invalid
    }
}

remove_component :: proc(world: ^World, entity: Entity, $T: typeid) {
    // Remove the component instance in the component pool.
    assert(T in world.components, "ECS Error: Entity data dismatches the component pool.")
    pool := &world.components[T]
    components := transmute(^[dynamic]T)&pool.components
    if comp_id, ok := pool.entities[entity]; ok {
        last := len(components) - 1
        slice.swap(components[:], cast(int)comp_id, cast(int)last)
        for key, id in pool.entities {
            if cast(int)id == last do pool.entities[key] = comp_id
        }
        pop(components)
        delete_key(&pool.entities, entity)
    }
}

get_components :: proc {
    get_components_of_type,
    get_components_of_entity,
}

get_components_of_type :: proc(world: ^World, $T: typeid) -> []T {
    if comps, ok := world.components[T]; ok {
        return (transmute([dynamic]T)comps.components)[:]
    } else {
        return nil
    }
}

get_components_of_entity :: proc(world: ^World, entity: Entity, allocator:= context.allocator) -> [dynamic]ComponentInfo {
    components := make([dynamic]ComponentInfo, allocator)
    for key, pool in world.components {
        if entity in pool.entities {
            append(&components, ComponentInfo{key, pool.entities[entity]})
        }
    }
    return components
}

get_component :: proc(world: ^World, entity: Entity, $T: typeid) -> ^T {
    pool, ok := &world.components[T]
    if !ok do return nil
    comp_id := pool.entities[entity]
    return &(transmute([dynamic]T)pool.components)[comp_id]
}

ComponentInfo :: struct {
    type: typeid,
    id : u32,
}

// ## Test Components
// Some built-in components to test the ecs system.
Transform :: struct {
    position    : linalg.Vector3f32,
    orientation : linalg.Quaternionf32,
    scale       : linalg.Vector3f32,
}

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

// ## Dead code

// Stack :: struct {
//     top : ^StackNode,
//     count : u32,
//     allocator : runtime.Allocator,
// }
// StackNode :: struct {
//     data : u32, 
//     prev : ^StackNode,
// }

// stack_create :: proc(allocator:= context.allocator) -> Stack {
//     return Stack{nil, 0, allocator}
// }
// stack_push :: proc(stack: ^Stack, data: u32) {
//     context.allocator = stack.allocator
//     node := new (StackNode)
//     node.data = data 
//     node.prev = stack.top
//     stack.top = node
//     stack.count += 1
// }
// stack_pop :: proc(stack: ^Stack) -> (data: u32, ok: bool) #optional_ok {
//     if stack.count == 0 do return 0, false
//     node := stack.top
//     data = node.data
//     stack.top = node.prev
//     free(node)
//     stack.count -= 1
//     return data, true
// }
// stack_peek :: proc(stack: ^Stack) -> (data: u32, ok: bool) #optional_ok {
//     if stack.count == 0 do return 0, false
//     return stack.top.data, true
// }