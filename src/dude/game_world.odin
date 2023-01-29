package dude


import "ecs"

// Utils to help use ecs in the game.


get_main_light :: proc(world: ^ecs.World) -> ^Light {
    lights := ecs.get_components(world, Light)
    if lights != nil && len(lights) > 0 do return &lights[0]
    return nil
}

get_main_camera :: proc(world: ^ecs.World) -> ^Camera {
    cameras := ecs.get_components(world, Camera)
    if cameras != nil && len(cameras) > 0 do return &cameras[0]
    return nil
}