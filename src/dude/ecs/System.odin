package ecs

System :: struct {
    update : proc(world: ^World),
}

add_system :: proc(world: ^World, update : proc(world: ^World)) {
    append(&world.systems, update)
}