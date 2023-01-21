package ecs

import "core:strings"
import "core:reflect"
import "core:runtime"
import "core:math/linalg"
import "core:mem"


// NOTE: The implementation of `World`
// Remove component: The component info of the entity should be updated.

// ## NOTE: World struct
// - **entities**: A sparse set, the data holds a dynamic array of `EntityComponentInfo`.
// In this array, the order doesn't matters, so when deleting object, the target object 
// would be exchanged to the last one, and be popped.
// - **components**: A map from `typeid` to `ComponentPool`. You could use a type to find
// the existing components.
World :: struct {
    entities   : SparseSet(EntityInfo),
    components : ComponentMap,
    // systems_update : [dynamic]SystemUpdateProc,
}

EntityInfo :: struct {
    // nothing.
}

EntityComponentInfo :: struct {
    id   : u32,
    type : typeid,
    is_valid : bool,
}

// API
world_create :: proc(allocator:= context.allocator) -> ^World{
    context.allocator = allocator
    world := new(World)
    
    // world.entities = spsset_make([dynamic]EntityComponentInfo, 4096 * 4)
    world.entities = spsset_make(EntityInfo, 4096 * 4)
    world.components = make(ComponentMap)

    return world
}

world_destroy :: proc(world: ^World) {
    spsset_destroy(&world.entities)
    delete(world.components)
}

// world_update :: proc(using world: ^World) {
//     for system in systems_update {
//         system(world)
//     }
// }

add_entity :: proc(world: ^World) -> Entity {
    entity_id := cast(u32)spsset_len(&world.entities)
    spsset_add(
        &world.entities,
        entity_id,
        EntityInfo{},
    )
    return cast(Entity)entity_id
}

get_new_entity_id :: proc(world: ^World) -> u32 {
    return cast(u32)spsset_len(&world.entities)
}

// - entity: 
// - T: The component type.
// - inject: Whether to inject the entity id, a **Component** is needed at the beginning.
// If you use a normal struct as a component, set the `inject` to false.
// add_component :: proc {
//     add_component_with_object,
//     add_component_with_type,
// }
// add_component_with_object :: proc(world: ^World, entity: Entity, component: $T, inject := true) -> ^T {
//     components := &world.components[T]
//     if inject {// Setup component base.
//         comp_ptr := transmute(^Component)&component
//         comp_ptr.entity = entity
//         comp_ptr.type = T
//     }
//     append(components, component)
//     return transmute(^T)&components[len(components) - 1]
// }
// add_component_with_type :: proc(world: ^World, entity: Entity, $T: typeid, inject := true) -> ^T {
//     components := &world.components[T]
//     component : T
//     if inject {// Setup component base.
//         comp_ptr := transmute(^Component)&component
//         comp_ptr.entity = entity
//         comp_ptr.type = T
//     }
//     append(components, component)
//     return transmute(^T)&components[len(components) - 1]
// }

// push_system :: proc(world: ^World, update : SystemUpdateProc) {
//     append(&world.systems_update, update)
// }

query_component :: proc(world: ^World, $T: typeid) -> []T {
    if component, ok := world.components[T]; ok {
        return transmute([]T)world.components[T][:]
    } else {
        return nil
    }
}


// components_map :: map[typeid]u32

SystemUpdateProc :: proc(world: ^World)

System :: struct {
    update : proc(world: ^World),
}

Entity :: distinct u32