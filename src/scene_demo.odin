﻿package main

import "core:log"
import "core:strings"
import "core:mem"
import "core:math/linalg"

import "dude"
import "dude/ecs"

scene_demo := dude.Scene { test_scene_loader, test_scene_update, test_scene_unloader }

demo_dpackage : ^dude.DPackage

Dove :: struct {
    name : string,
    age : ^i32,
    line : string,
    height: f32,
}

@(private="file")
test_scene_loader :: proc(world: ^ecs.World) {
    using dude
    using ecs

    {// load DPacMeta
        dpac_register_asset("Dove", Dove, nil)
        pac, ok := dpac_init("res/test_demo.dpacodin")
        dpac_load(pac)
        demo_dpackage = pac
    }
    
    // {// Res load
    //     res_add_embbed("font/inkfree.ttf", #load("../res/font/inkfree.ttf"))
    //     res_load_font("font/inkfree.ttf", 32)
    //     res_load_texture("texture/box.png")
    // }

    // prefab_editor_camera(world, "MainCamera", false)
    // prefab_light(world, "MainLight")

    // {// Add test SpriteRenderer.
    //     dove := ecs.add_entity(world)
    //     sprite := SpriteRenderer {
    //         texture_id = res_get_texture("texture/box.png").id,
    //         enable = true,
    //         size = {64, 64},
    //         pivot = {0.5, 0.5},
    //         space = .Screen,
    //         color = COLORS.WHITE,
    //     }
    //     transform := Transform {
    //         position = {100, 0, 0},
    //         orientation = linalg.QUATERNIONF32_IDENTITY,
    //         scale = {1, 1, 1},
    //     }
    //     ecs.add_components(world, dove, 
    //         transform, sprite)
    // }
    // {
    //     start_triggered = false
    //     alpha = 0.0
    // }
}

@(private="file")
start_triggered := false
@(private="file")
alpha :f32= 0.0


@(private="file")
test_scene_update :: proc(world: ^ecs.World) {
    using dude
    // inkfree := res_get_font("font/inkfree.ttf")

    // text :=  "Press `Enter` to start"
    // text_width := immediate_measure_text_width(inkfree, text)
    // wnd_size := game.window.size
    // screen_center := Vec2{cast(f32)wnd_size.x, cast(f32)wnd_size.y} * 0.5

    // color := auto_cast dpac_query(demo_dpackage, "color_text", Color)

    // if color != nil {
    //     dude.immediate_text(inkfree, text, 
    //         {screen_center.x - text_width * 0.5, screen_center.y},
    //         color^,
    //     )
    // } else {
    //     dude.immediate_text(inkfree, text, 
    //         {screen_center.x - text_width * 0.5, screen_center.y},
    //         COLORS.RED,
    //     )
    // }
    // dude.immediate_text(inkfree, text, 
    //     {screen_center.x - text_width * 0.5, screen_center.y},
    //     COLORS.RED,
    // )

    // dude.immediate_texture(
    //     {100, 100}, {64, 64}, COLORS.WHITE, 
    //     dpac_query(demo_dpackage, "dude_logo", Texture).id)


    @static test_buffer : []byte
    @static allocated := false

    if get_key_down(.K) {
        log.debugf("global_name: {}", dpac_query(demo_dpackage, "global_name", string)^)
        log.debugf("global_f32: {}", dpac_query(demo_dpackage, "global_f32", f32)^)
        log.debugf("global_i32: {}", dpac_query(demo_dpackage, "global_i32", i32)^)
        log.debugf("dove: {}", dpac_query(demo_dpackage, "dove_test", Dove)^)
    }

    if !start_triggered {
        if get_key_down(.RETURN) {
            start_triggered = true
            tween(&alpha, 1, 1.2)->
                set_on_complete(start_game, nil)
            // sprites := ecs.get_components(world, SpriteRenderer)
            // for sp in &sprites do sp.enable = false
        }
    } else {
        // curtain_color := color^
        // curtain_color.a = alpha
        // immediate_quad(0, {cast(f32)wnd_size.x, cast(f32)wnd_size.y}, curtain_color)
    }

}

@(private="file")
start_game :: proc(nothing:rawptr=nil) {
    dude.switch_scene("Mushroom")
}

@(private="file")
test_scene_unloader :: proc(world: ^ecs.World) {
    dude.dpac_destroy(demo_dpackage)
    // dude.res_unload_texture("texture/box.png")
    // dude.res_unload_font("font/inkfree.ttf")
}