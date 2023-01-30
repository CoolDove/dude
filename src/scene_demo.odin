package main

import "core:log"
import "core:math/linalg"

import "dude"
import "dude/ecs"

scene_demo := dude.Scene { test_scene_loader, test_scene_update, test_scene_unloader }

@(private="file")
test_scene_loader :: proc(world: ^ecs.World) {
    using dude
    using ecs
    
    {// Res load
        context.allocator = allocators.level
        res_add_embbed("font/inkfree.ttf", #load("../res/font/inkfree.ttf"))
        res_load_font("font/inkfree.ttf", 32)
        res_load_texture("texture/box.png")
    }

    prefab_camera(world, "MainCamera", false)
    prefab_light(world, "MainLight")

    {// Add test SpriteRenderer.
        dove := ecs.add_entity(world)
        sprite := SpriteRenderer {
            texture_id = res_get_texture("texture/box.png").id,
            enable = true,
            size = {64, 64},
            pivot = {0.0, 0.0},
            space = .Screen,
            color = COLORS.WHITE,
        }
        transform := Transform {
            position = {100, 0, 0},
            orientation = linalg.QUATERNIONF32_IDENTITY,
            scale = {1, 1, 1},
        }
        ecs.add_components(world, dove, 
            transform, sprite)
    }
    {
        start_triggered = false
        alpha = 0.0
    }
}

@(private="file")
start_triggered := false
@(private="file")
alpha :f32= 0.0


@(private="file")
test_scene_update :: proc(world: ^ecs.World) {
    using dude
    inkfree := res_get_font("font/inkfree.ttf")

    text :=  "Press `Enter` to start"
    text_width := immediate_measure_text_width(inkfree, text)
    wnd_size := game.window.size
    screen_center := Vec2{cast(f32)wnd_size.x, cast(f32)wnd_size.y} * 0.5

    color := COLORS.WHITE
    color.w = alpha

    dude.immediate_text(inkfree, text, 
        {screen_center.x - text_width * 0.5, screen_center.y},
        COLORS.RED,
    )

    if !start_triggered {
        if get_key_down(.RETURN) {
            start_triggered = true
            tween(&alpha, 1, 1.2)->
                set_on_complete(start_game, nil)
            sprites := ecs.get_components(world, SpriteRenderer)
            for sp in &sprites do sp.enable = false
        }
    } else {
        immediate_quad(0, {cast(f32)wnd_size.x, cast(f32)wnd_size.y}, color)
    }

}

@(private="file")
start_game :: proc(nothing:rawptr=nil) {
    dude.switch_scene("Mushroom")
}

@(private="file")
test_scene_unloader :: proc(world: ^ecs.World) {
    context.allocator = dude.allocators.level
    dude.res_unload_texture("texture/box.png")
    dude.res_unload_font("font/inkfree.ttf")

    free_all()
}