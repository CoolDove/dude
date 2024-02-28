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
	render_pass : [dynamic]^RenderPass,

    time_total, time_delta : f64,
}

GameSettings :: struct {
    status_window_alpha : f32,
    render_wireframe : bool,
    immediate_draw_wireframe : bool,
}

game : Game

game_update :: proc() {
    game.time_total = time.duration_seconds(app.duration_total)
    game.time_delta = time.duration_seconds(app.duration_frame)
	total_time :f32= auto_cast game.time_total
	delta :f32= auto_cast game.time_delta

	tweener_update(&game.global_tweener, delta)

    if _callback_update == nil {
        log.errorf("Dude: You should set a valid `update` for me.")
    } else do _callback_update(&game, delta)

    render_update(total_time)
    for pass in &game.render_pass {
        render_pass_draw(pass)
    }

    // Game builtin draw.
    if game.settings.status_window_alpha > 0 do draw_status()

    // ## DEBUG IMGUI
	imgui_frame_begin()
    if _callback_gui != nil do _callback_gui()
	dude_imgui_basic_settings()
	imgui_frame_end()

    free_all(allocators.frame)
    free_all(context.temp_allocator)
}

game_init :: proc() {
    using dgl
    allocators_init()

    dpac_init()

    game.settings = new(GameSettings)

    tween_system_init()

	tweener_init(&game.global_tweener, 16)
	
	// time.stopwatch_start(&game.timer)

    render_init()

    if _callback_init != nil do _callback_init(&game)
}

game_release :: proc() {
    log.debug("game release")
    if _callback_release != nil do _callback_release(&game)

    render_release()

	tweener_release(&game.global_tweener)
    
    free(game.settings)

    allocators_release()
}

BuiltinResource :: struct {
    default_font : ^DynamicFont,
}

builtin_res : BuiltinResource