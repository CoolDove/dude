package dude

import "core:time"
import "core:log"
import "core:fmt"
import "core:reflect"
import "core:strings"
import "core:math"
import "core:math/linalg"

import sdl "vendor:sdl2"
import gl "vendor:OpenGL"

when ODIN_DEBUG do import "pac:imgui"

import "dgl"
import "ecs"

@private
registered_scenes : map[string]Scene
@private
default_scene : string

Game :: struct {
    using settings : ^GameSettings,
    window : ^Window,

    current_scene : ^Scene,
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

update_game :: proc() {
    // ## FRAME PREPARE
	gl.Clear(gl.COLOR_BUFFER_BIT|gl.DEPTH_BUFFER_BIT|gl.STENCIL_BUFFER_BIT)
    wnd := game.window
	immediate_begin(dgl.Vec4i{0, 0, wnd.size.x, wnd.size.y})

    // ## GAME LOGIC
    {// Engine input handling
        if get_key_down(.F1) {
            game.immediate_draw_wireframe = !game.immediate_draw_wireframe
        }
        if get_key_down(.F2) {
            game.status_window_alpha = 1 - game.status_window_alpha
        }
    }

    // Game world
    if game.main_world != nil {
        world := game.main_world
        if game.current_scene.update != nil {
            game.current_scene.update(world)
        }

        when ODIN_DEBUG {
            camera := get_main_camera(world)
            if camera != nil do gizmos_begin(camera)
        }

        ecs.world_update(world)
        render_world(world)

        when ODIN_DEBUG { gizmos_xz_grid(10, 1, COLORS.GRAY) }

        when ODIN_DEBUG {
            if camera != nil do gizmos_end()
        }

    } else {// Draw "No Scene Loaded" and the cool dude logo.
        draw_no_scene_logo(game.window)
    }

    tween_update()

    // Game builtin draw.
    if game.settings.status_window_alpha > 0 do draw_status()

    // ## RENDERING
    immediate_end(game.immediate_draw_wireframe)

    // ## DEBUG IMGUI
	when ODIN_DEBUG {
        imgui_frame_begin()
		dude_imgui_basic_settings()
        imgui_frame_end()
	}

}

init_game :: proc() {
    using dgl

    game.settings = new(GameSettings)
    // TODO: Move shader loading into res module.
    game.basic_shader = dgl.shader_load_vertex_and_fragment(
        #load("resources/basic_3d_vertex.glsl"),
        #load("resources/basic_3d_fragment.glsl"))

    load_builtin_assets() 

    tween_init()

    if default_scene != "" {
        load_scene(default_scene)
    }
}

struct_offset_detail :: proc($T:typeid) -> uintptr {
    names   := reflect.struct_field_names(T)
    offsets := reflect.struct_field_offsets(T)

    sb : strings.Builder
    strings.builder_init(&sb)
    defer strings.builder_destroy(&sb)
    strings.write_string(&sb, fmt.tprintf("{}: <", typeid_of(T)))

    for i in 0..<len(names) {
        name := names[i]
        offset := offsets[i]
        strings.write_string(&sb, fmt.tprintf("{}: {}", name, offset))
        if i != len(names) - 1 do strings.write_string(&sb, ", ")
    }
    strings.write_string(&sb, fmt.tprintf("> total size: {}", size_of(T)))
    log.debugf(strings.to_string(sb))

    return offsets[0] if len(offsets) > 0 else 0
}

quit_game :: proc() {
    unload_scene()
    
    tween_destroy()

    unload_builtin_assets()

    log.debug("QUIT GAME")

    free(game.settings)
}

load_builtin_assets :: proc() {
    res_add_embbed("texture/dude.png", #load("resources/dude.png"))
    res_add_embbed("font/unifont.tff", #load("resources/unifont.ttf"))

    res_load_texture("texture/dude.png")
    {
        white := new(Texture)
        white.id = dgl.texture_create(4, 4, [4]u8{0xff, 0xff, 0xff, 0xff})
        white.size = {4, 4}
        res_add_texture("texture/white", white)
    }
    {
        black := new(Texture)
        black.id = dgl.texture_create(4, 4, [4]u8{0x00, 0x00, 0x00, 0xff})
        black.size = {4, 4}
        res_add_texture("texture/black", black)
    }
    res_load_font("font/unifont.tff", 32.0)
}

unload_builtin_assets :: proc() {
    res_unload_texture("texture/dude.png")
    res_unload_texture("texture/white")
    res_unload_texture("texture/black")
    res_unload_font("font/unifont.ttf")
}