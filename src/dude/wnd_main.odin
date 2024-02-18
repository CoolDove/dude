package dude

import "core:fmt"
import "core:os"
import "core:strings"
import "core:time"
import "core:math"
import "core:log"
import "core:math/rand"

import sdl  "vendor:sdl2"
import gl   "vendor:OpenGL"

import imgl "vendor/imgui/impl/opengl"
import imsdl "vendor/imgui/impl/sdl"
import "vendor/imgui"

import dgl "dgl"

ImguiState :: struct {
	sdl_state : imsdl.SDL_State,
	opengl_state : imgl.OpenGL_State,
}

imgui_state : ImguiState

create_main_window :: proc (allocator:=context.allocator, loc := #caller_location) -> Window {
	wnd := window_get_basic_template(game_config.name)
	wnd.derive_vtable = &main_wnd_vtable
	wnd.window_flags += { .RESIZABLE }
    return wnd
}

@(private="file")
main_wnd_vtable := Window_DeriveVTable {
	handler,
	update,
	before_destroy,
	after_instantiate,
}

@(private="file")
init_imgui :: proc(imgui_state:^ImguiState, wnd: ^sdl.Window) {
	imgui.create_context()
	imgui.style_colors_dark()

	// imsdl.setup_state(&imgui_state.sdl_state)
	imsdl.init(&imgui_state.sdl_state, wnd)
	imgl.setup_state(&imgui_state.opengl_state)

	imgui_version := imgui.get_version()

	log.infof("ImGui inited, version: %s", imgui_version)
}

@(private="file")
after_instantiate :: proc(using wnd: ^Window) {
	init_imgui(&imgui_state, window)

	log.debugf("window {} instantiated.", name)

	game.window = wnd
	init_game()
}

@(private="file")
before_destroy :: proc(wnd: ^Window) {
	quit_game()
	log.debug("Main Window Closed")
}

@(private="file")
handler :: proc(using wnd:^Window, event:sdl.Event) {
	imsdl.process_event(event, &imgui_state.sdl_state)

	input_handle_sdl2(event)

	window_event := event.window
}

@(private="file")
update :: proc(using wnd:^Window) {// Game runs in this.

	update_game()

	sdl.GL_SwapWindow(wnd.window)
	input_after_update_sdl2()
}


@(private)
imgui_frame_begin :: proc() {
	imsdl.new_frame()
	imgui.new_frame()
}

@(private)
imgui_frame_end :: proc() {
	imgui.end_frame()
	imgui.render()
	draw_data := imgui.get_draw_data();
	imgl.imgui_render(draw_data, imgui_state.opengl_state)
}
