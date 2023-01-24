package main


import "core:log"
import "core:math/linalg"

import "dude"
import "dude/ecs"


SceneTest := dude.Scene { test_scene_loader, nil, test_scene_unloader }


@(private="file")
test_scene_loader :: proc(world: ^ecs.World) {
    using dude
    using ecs
    {// Res load
        res_load_texture("texture/box.png")
    }
    {// main camera
        camera := add_entity(world)
        add_component(world, camera, Transform {
            position    = {0, 0, 3.5},
            orientation = linalg.quaternion_from_forward_and_up(Vec3{0, 0, 1}, Vec3{0, 1, 0}),
            scale       = {1, 1, 1},
        })
        add_component(world, camera, Camera{
            fov  = 45,
            near = .1,
            far  = 300,
        })
        add_component(world, camera, BuiltIn3DCameraController{---, 1, 1})
        add_component(world, camera, DebugInfo{"MainCamera"})
    }
    {// main light
        light := add_entity(world)
        l : Light
        {using l
            color = {1, .8, .8, 1}
            direction = linalg.normalize(Vec3{-0.9, .3, 0}) 
        }
        add_component(world, light, l)
        add_component(world, light, DebugInfo{"MainLight"})
    }
    {// Add test SpriteRenderer.
        dove := ecs.add_entity(world)
        sprite := ecs.add_component(world, dove, SpriteRenderer)
        sprite.texture_id = res_get_texture("texture/box.png").id
        sprite.size = {64, 64}
        sprite.pos = {0, 0}
        sprite.pivot = {0.0, 0.0}
        sprite.color = COLORS.WHITE
    }
}

@(private="file")
test_scene_unloader :: proc(world: ^ecs.World) {
    dude.res_unload_texture("texture/box.png")
}