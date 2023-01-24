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

    prefab_camera(world, "MainCamera", false)
    prefab_light(world, "MainLight")
    
    {// Add test SpriteRenderer.
        dove := ecs.add_entity(world)
        sprite := ecs.add_component(world, dove, SpriteRenderer)
        sprite.texture_id = res_get_texture("texture/box.png").id
        sprite.size = {64, 64}
        sprite.pivot = {0.0, 0.0}
        sprite.space = .World
        sprite.color = COLORS.WHITE

        ecs.add_component(world, dove, BuiltIn3DCameraController{---, 1, 1})
    }
}

@(private="file")
test_scene_unloader :: proc(world: ^ecs.World) {
    dude.res_unload_texture("texture/box.png")
}