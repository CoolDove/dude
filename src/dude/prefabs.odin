package dude

import "core:math/linalg"
import "core:strings"

import "ecs"

prefab_camera :: proc(world: ^ecs.World, name: string, built_in_controller: bool = true) {
    using ecs
    camera := add_entity(world, {name})
    add_components(world, camera, 
        DebugInfo{name},
        Transform {
            position    = {0, 0, 3.5},
            orientation = linalg.quaternion_from_forward_and_up(Vec3{0, 0, 1}, Vec3{0, 1, 0}),
            scale       = {1, 1, 1},
        },
        Camera{
            fov  = 45,
            near = .1,
            far  = 300,
        },
    )
    if built_in_controller do add_component(world, camera, EditorCameraController{---, .35, .006})
}

prefab_light :: proc(world: ^ecs.World, name: string, color: Color = COLORS.GREEN) {
    using ecs
    light := add_entity(world, {name="MainLight"})
    add_components(world, light, 
        DebugInfo{name},
        Light{{}, linalg.normalize(Vec3{-0.9, .3, 0}), color},
    )
}