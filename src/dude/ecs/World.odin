package ecs

import "core:strings"
import "core:reflect"
import "core:runtime"
import "core:math/linalg"
import "core:mem"

// ## NOTE: World struct
// - **entities**: A sparse set, the data holds a dynamic array of `EntityComponentInfo`.
// In this array, the order doesn't matters, so when deleting object, the target object 
// would be exchanged to the last one, and be popped.
// - **components**: A map from `typeid` to `ComponentPool`. You could use a type to find
// the existing components.
World :: struct {
    entities   : SparseSet(EntityInfo),
    components : ComponentMap,
    systems : [dynamic]proc(world: ^World),
}

EntityInfo :: struct {
    name : string,
}

// API
world_create :: proc(allocator:= context.allocator) -> ^World{
    context.allocator = allocator
    world := new(World)
    
    world.entities = spsset_make(EntityInfo, 4096 * 4)
    world.components = make(ComponentMap, 32, allocator)
    world.systems = make([dynamic]proc(world: ^World))

    return world
}

world_destroy :: proc(world: ^World) {
    spsset_destroy(&world.entities)
    delete(world.components)
    delete(world.systems)
}

world_update :: proc(using world: ^World) {
    for update in systems {
        update(world)
    }
}