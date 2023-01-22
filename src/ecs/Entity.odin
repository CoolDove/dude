package ecs

Entity :: distinct u32

add_entity :: proc(world: ^World) -> Entity {
    entity_id := cast(u32)spsset_len(&world.entities)
    spsset_add(
        &world.entities,
        entity_id,
        EntityInfo{},
    )
    return cast(Entity)entity_id
}

@(private="file")
get_new_entity_id :: proc(world: ^World) -> u32 {
    return cast(u32)spsset_len(&world.entities)
}