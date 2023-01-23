package main

import "core:time"
import "core:log"
import "core:fmt"
import "core:strings"
import "core:math"
import "core:math/linalg"

import sdl "vendor:sdl2"
import gl "vendor:OpenGL"

when ODIN_DEBUG do import "pac:imgui"

import "dgl"
import "ecs"

Game :: struct {
    using settings : ^GameSettings,
    window : ^Window,

    main_world : ^ecs.World,

    basic_shader : dgl.Shader,
}

GameSettings :: struct {
    status_window_alpha : f32,
    render_wireframe : bool,
    immediate_draw_wireframe : bool,
}

game : Game

GameObject :: struct {
    mesh      : TriangleMesh,
    transform : Transform,
}

draw_game :: proc() {
	using dgl
    wnd := game.window
    if game.settings.status_window_alpha > 0 do draw_status()
}

when ODIN_DEBUG {
draw_game_imgui :: proc() {
    imgui.checkbox("immediate draw wireframe", &game.immediate_draw_wireframe)

    for t, ind in &tweens {
        text := fmt.tprintf("{}: {}", ind, "working" if !t.done else "done.")
        imgui.selectable(text, !t.done)
    }
}
}

@(private="file")
draw_status :: proc() {
    frame_ms := time.duration_milliseconds(app.duration_frame)
    framerate := cast(i32)(1000.0/frame_ms)
    color := Vec4{.1, 1, .1, 1}
    color.a *= game.settings.status_window_alpha

    font := res_get_font("font/unifont.ttf")
    immediate_text(font, fmt.tprintf("FPS: {}", framerate), {10, 32+10}, color)
    immediate_text(font, fmt.tprintf("Fullscreen: {}", game.window.fullscreen), 
        {10, 32+10+32+10}, color)
}

update_game :: proc() {
    {// Global input handling
        if get_key_down(.F1) {
            game.immediate_draw_wireframe = !game.immediate_draw_wireframe
        }
    }

    if game.main_world != nil {
        ecs.world_update(game.main_world)
    } else {
        wnd_size := game.window.size
        unifont := res_get_font("font/unifont.tff")
        text := "有欲望而无行动者滋生瘟疫"
        text_width := immediate_measure_text_width(unifont, text)
        immediate_text(unifont, text,
            {cast(f32)wnd_size.x * 0.5 - text_width * 0.5, cast(f32)wnd_size.y * 0.5},
            {.9, .2, .8, .5})
    }

    tween_update()
}

init_game :: proc() {
    using dgl

    game.settings = new(GameSettings)

	vertex_shader_src :: string(#load("../res/shader/basic_3d_vertex.glsl"))
	fragment_shader_src :: string(#load("../res/shader/basic_3d_fragment.glsl"))

    game.basic_shader = load_shader(vertex_shader_src, fragment_shader_src)

    tween_init()

    {// Load some built in assets.
        res_add_embbed("texture/box.png",       #load("../res/texture/box.png"))
        res_add_embbed("texture/walk_icon.png", #load("../res/texture/walk_icon.png"))
        res_add_embbed("font/inkfree.ttf",      #load("../res/font/inkfree.ttf"))
        res_add_embbed("font/unifont.tff",      #load("../res/font/unifont.ttf"))

        res_load_texture("texture/box.png")
        res_load_texture("texture/walk_icon.png")
        res_load_font("font/inkfree.ttf", 32.0)
        res_load_font("font/unifont.tff", 32.0)

        res_load_model("model/mushroom.fbx", game.basic_shader.native_id, draw_settings.default_texture_white, 0.01)
    }

    res_list_embbed()
    res_list_loaded()

    if false {// Init the world
        using game
        using ecs
        main_world = ecs.world_create()
        world := main_world
        ecs.add_system(main_world, render_system_update)
        ecs.add_system(main_world, built_in_3dcamera_controller_update)

        {// Add the camera and light.
            log.debugf("Create Camera and Light")
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
            log.debugf("Camera and Light created ")
        }
        {// Add MeshRenderers.
            log.debugf("Create MeshRenderers")
            add_mesh_renderers(world, res_get_model("model/mushroom.fbx"))
            log.debugf("MeshRenderers created")
        }
        {// Add test SpriteRenderer.
            dove := ecs.add_entity(main_world)
            sprite := ecs.add_component(main_world, dove, SpriteRenderer)
            sprite.texture_id = res_get_texture("texture/box.png").texture_id
            sprite.size = {64, 64}
            sprite.pos = {0, 0}
            sprite.pivot = {0.0, 0.0}
        }
    }

}

@(private="file")
add_mesh_renderers :: proc(world: ^ecs.World, asset : ^ModelAsset) {
    for name, mesh in &asset.meshes {
        ent := ecs.add_entity(world)
        
        mesh_renderer := ecs.add_component(world, ent, MeshRenderer)
        mesh_renderer.mesh = &mesh
        mesh_renderer.transform_matrix = linalg.MATRIX4F32_IDENTITY
        ecs.add_component(world, ent, DebugInfo{
            fmt.aprintf("DBGNAME: {}", strings.to_string(mesh_renderer.mesh.name)),
        })
    }
}

@(private="file")
load_shader :: proc(vertex_source, frag_source : string)  -> dgl.Shader {
	shader_comp_vertex := dgl.shader_create_component(.VERTEX_SHADER, vertex_source)
	shader_comp_fragment := dgl.shader_create_component(.FRAGMENT_SHADER, frag_source)
	shader := dgl.shader_create(&shader_comp_vertex, &shader_comp_fragment)
	dgl.shader_destroy_components(&shader_comp_vertex, &shader_comp_fragment)
	return shader
}

quit_game :: proc() {
    ecs.world_destroy(game.main_world)
    
    tween_destroy()

    res_unload_texture("texture/box.png")
    res_unload_texture("texture/walk_icon.png")
    res_unload_model("model/mushroom.fbx")
    res_unload_font("font/unifont.ttf")
    res_unload_font("font/inkfree.ttf")

    log.debug("QUIT GAME")

    free(game.settings)

}