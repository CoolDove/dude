package ecs

import "core:log"

Entity :: distinct u32

add_entity :: proc(world: ^World, info:= EntityInfo{}) -> Entity {
    entity_id := get_new_entity_id(world)
    spsset_add(
        &world.entities,
        entity_id,
        info,
    )
    return cast(Entity)entity_id
}

entity_info :: #force_inline proc(world: ^World, entity: Entity) -> ^EntityInfo {
    return spsset_find(&world.entities, cast(u32)entity)
}
has_entity :: #force_inline proc(world: ^World, entity: Entity) -> bool {
    return spsset_contain(&world.entities, cast(u32) entity)
}

remove_entity :: proc(world: ^World, entity: Entity, try := false) -> bool {
    assert(world != nil )
    if !has_entity(world, entity) {
        if !try do log.errorf("ECS: Can't remove entity {} because it doesn't exist.", entity);
        return false
    }
    for type, comp in world.components {
        remove_component(world, entity, type, true)
    }
    spsset_remove(&world.entities, cast(u32)entity)
    return true
}

@(private="file")
get_new_entity_id :: proc(world: ^World) -> u32 {
    defer entity_id += 1
    return entity_id
}

@(private="file")
entity_id : u32 = 0