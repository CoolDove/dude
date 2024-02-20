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

Game :: struct {
    using settings : ^GameSettings,
    window : ^Window,

	global_tweener : Tweener,

	timer : time.Stopwatch,

    // current_scene : ^Scene,
    main_world : ^ecs.World,

	render_pass : [dynamic]RenderPass,
}

GameSettings :: struct {
    status_window_alpha : f32,
    render_wireframe : bool,
    immediate_draw_wireframe : bool,
}

game : Game

game_update :: proc() {
	duration := time.stopwatch_duration(game.timer)
	delta :f32= auto_cast time.duration_seconds(duration)
	time.stopwatch_start(&game.timer)


	gl.Clear(gl.COLOR_BUFFER_BIT|gl.DEPTH_BUFFER_BIT|gl.STENCIL_BUFFER_BIT)

	test_render()

    draw_no_scene_logo(game.window)

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

game_init :: proc() {
    using dgl
    allocators_init()

    dpac_init()

    game.settings = new(GameSettings)

    tween_system_init()

	tweener_init(&game.global_tweener, 16)
	
	time.stopwatch_start(&game.timer)

	test_render_init()
}

game_release :: proc() {
    log.debug("game release")

	test_render_release()

	tweener_release(&game.global_tweener)
    
    free(game.settings)

    allocators_release()
}

BuiltinResource :: struct {
    default_font : ^DynamicFont,
}

builtin_res : BuiltinResource