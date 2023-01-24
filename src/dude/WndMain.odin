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

when ODIN_DEBUG {
	import imgl "pac:imgui/impl/opengl"
	import imsdl "pac:imgui/impl/sdl"
	import "pac:imgui"

	ImguiState :: struct {
		sdl_state : imsdl.SDL_State,
		opengl_state : imgl.OpenGL_State,
	}

	imgui_state : ImguiState
}

import dgl "dgl"

WndMainData :: struct {
	data : u32,
}

create_main_window :: proc (allocator:=context.allocator, loc := #caller_location) -> Window {
	wnd := window_get_basic_template("Demo")
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


when ODIN_DEBUG {
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
}

@(private="file")
after_instantiate :: proc(using wnd: ^Window) {
	wdata := window_data(WndMainData, wnd)
	log.debugf("window data: {}", wdata)

	when ODIN_DEBUG do init_imgui(&imgui_state, window)

	init()
	immediate_init()

	log.debugf("window {} instantiated.", name)

	game.window = wnd
	init_game()
}

@(private="file")
before_destroy :: proc(wnd: ^Window) {
	wdata := window_data(WndMainData, wnd)
	quit_game()
	log.debug("Main Window Closed")
}

@(private="file")
handler :: proc(using wnd:^Window, event:sdl.Event) {
	wnd_data := window_data(WndMainData, wnd)
	using wnd_data

	when ODIN_DEBUG do imsdl.process_event(event, &imgui_state.sdl_state)

	input_handle_sdl2(event)

	window_event := event.window
}

@(private="file")
update :: proc(using wnd:^Window) {// Game runs in this.
	wnd_data := window_data(WndMainData, wnd)
	draw_settings.screen_width = cast(f32)wnd.size.x
	draw_settings.screen_height = cast(f32)wnd.size.y

	update_game()

	sdl.GL_SwapWindow(wnd.window)

	input_after_update_sdl2()
}

when ODIN_DEBUG {
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
}