package ecs

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

remove_entity :: proc(world: ^World) {
    // TODO
}

@(private="file")
get_new_entity_id :: proc(world: ^World) -> u32 {
    defer entity_id += 1
    return entity_id
}

@(private="file")
entity_id : u32 = 0

EntityBuilder :: struct {
    entity : Entity,
    world  : ^World,
}

EntityBuilder_VTable :: struct {
    add_component : proc(builder: ^EntityBuilder),
}

entity_builder_vtable := EntityBuilder_VTable {

}