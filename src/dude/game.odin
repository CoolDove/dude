package dude

import "core:time"
import "core:log"
import "core:fmt"
import "core:reflect"
import "core:strings"
import "core:math"
import "core:mem"
import "core:runtime"
import "core:slice"
import "core:math/linalg"

import sdl "vendor:sdl2"
import gl "vendor:OpenGL"

import "vendor/imgui"

import "dgl"
import "ecs"
import "dpac"

@private
registered_scenes : map[string]Scene
@private
default_scene : string

Game :: struct {
    using settings : ^GameSettings,
    window : ^Window,

	global_tweener : Tweener,

	timer : time.Stopwatch,

    current_scene : ^Scene,
    main_world : ^ecs.World,

	render_pass : [dynamic]RenderPass,

}

GameSettings :: struct {
    status_window_alpha : f32,
    render_wireframe : bool,
    immediate_draw_wireframe : bool,
}

game : Game

update_game :: proc() {
	duration := time.stopwatch_duration(game.timer)
	delta :f32= auto_cast time.duration_seconds(duration)
	time.stopwatch_start(&game.timer)


    // ## FRAME PREPARE
    check_scene_switch()

	gl.Clear(gl.COLOR_BUFFER_BIT|gl.DEPTH_BUFFER_BIT|gl.STENCIL_BUFFER_BIT)
    wnd := game.window
	// immediate_begin(dgl.Vec4i{0, 0, wnd.size.x, wnd.size.y})

    // ## GAME LOGIC
    {// Engine input handling
        if get_key_down(.F1) {
            game.immediate_draw_wireframe = !game.immediate_draw_wireframe
        }
        if get_key_down(.F2) {
            game.status_window_alpha = 1 - game.status_window_alpha
        }
        if get_key_down(.F3) {
            @static vsync_on := true
            vsync_on = !vsync_on
            // toggle_vsync(vsync_on)
        }
    }

    // Game world
    if game.main_world != nil {
        world := game.main_world
        if game.current_scene.update != nil {
            game.current_scene.update(world)
        }
       
		camera := get_main_camera(world)
		if camera != nil do gizmos_begin(camera)
      
        ecs.world_update(world)
        // render_world(world)

		// ## Test draw
		test_render()

        gizmos_xz_grid(10, 1, COLORS.GRAY)
        if camera != nil do gizmos_end()

    } else {// Draw "No Scene Loaded" and the cool dude logo.
        draw_no_scene_logo(game.window)
    }

	tweener_update(&game.global_tweener, delta)
    // tween_update()

    // Game builtin draw.
    if game.settings.status_window_alpha > 0 do draw_status()

    // ## RENDERING
    // immediate_end(game.immediate_draw_wireframe)

    // ## DEBUG IMGUI
	imgui_frame_begin()
	dude_imgui_basic_settings()
	imgui_frame_end()

    free_all(allocators.frame)
}

@private
check_scene_switch :: proc() -> bool {
    result := false
    if to_switch_scene != nil {
        unload_scene()
        load_scene_by_ptr(to_switch_scene)
        to_switch_scene = nil
    }
    return true
}

init_game :: proc() {
    using dgl
    allocators_init()

    dpac_init()

    game.settings = new(GameSettings)

    load_builtin_assets() 
    tween_system_init()

	tweener_init(&game.global_tweener, 16)

    if default_scene != "" {
        load_scene(default_scene)
    }
	
	time.stopwatch_start(&game.timer)

	test_render_init()
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
	test_render_release()

	tweener_release(&game.global_tweener)
    unload_scene()

    unload_builtin_assets()
    log.debug("QUIT GAME")
    free(game.settings)

    allocators_release()
}

BuiltinResource :: struct {
    default_font : ^DynamicFont,
}

builtin_res : BuiltinResource

@(private="file")
load_builtin_assets :: proc() {
    res_add_embbed("texture/dude.png", #load("resources/dude.png"))
    res_add_embbed("font/unifont.ttf", #load("resources/unifont.ttf"))
    res_add_embbed("shader/builtin_immediate_basic.shader", 
        #load("resources/builtin_immediate_basic.shader"))
    res_add_embbed("shader/builtin_immediate_font.shader", 
        #load("resources/builtin_immediate_font.shader"))
    res_add_embbed("shader/builtin_mesh_opaque.shader", 
        #load("resources/builtin_mesh_opaque.shader"))
    res_add_embbed("shader/builtin_gizmos_basic.shader", 
        #load("resources/builtin_gizmos_basic.shader"))
    res_add_embbed("shader/builtin_sprite.shader", 
        #load("resources/builtin_sprite.shader"))

    res_load_texture("texture/dude.png")
    {
        white := new(Texture)
        white.id = dgl.texture_create(4, 4, [4]u8{0xff, 0xff, 0xff, 0xff})
        white.size = {4, 4}
        res_add_texture("texture/white.tex", white)
    }
    {
        black := new(Texture)
        black.id = dgl.texture_create(4, 4, [4]u8{0x00, 0x00, 0x00, 0xff})
        black.size = {4, 4}
        res_add_texture("texture/black.tex", black)
    }
    builtin_res.default_font, _ = res_load_font("font/unifont.ttf", 32.0)

    res_load_shader("shader/builtin_sprite.shader")
    res_load_shader("shader/builtin_immediate_basic.shader")
    res_load_shader("shader/builtin_immediate_font.shader")
    res_load_shader("shader/builtin_mesh_opaque.shader")
    res_load_shader("shader/builtin_gizmos_basic.shader")
}

@(private="file")
unload_builtin_assets :: proc() {
    res_unload_texture("texture/dude.png")
    res_unload_texture("texture/white.tex")
    res_unload_texture("texture/black.tex")
    res_unload_font("font/unifont.ttf")

    res_unload_shader("shader/builtin_sprite.shader")
    res_unload_shader("shader/builtin_immediate_basic.shader")
    res_unload_shader("shader/builtin_immediate_font.shader")
    res_unload_shader("shader/builtin_mesh_opaque.shader")
    res_unload_shader("shader/builtin_gizmos_basic.shader")
}
