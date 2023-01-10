package main

import "core:fmt"
import "core:os"
import "core:strings"
import "core:time"
import "core:math"
import "core:log"
import "core:math/rand"

import sdl  "vendor:sdl2"
import gl   "vendor:OpenGL"

import imgl "pac:imgui/impl/opengl"
import imsdl "pac:imgui/impl/sdl"

import "pac:imgui"

import dgl "dgl"

WndMainData :: struct {
	imgui_state : ImguiState,
}

ImguiState :: struct {
	sdl_state : imsdl.SDL_State,
	opengl_state : imgl.OpenGL_State,
}

create_main_window :: proc (allocator:=context.allocator, loc := #caller_location) -> Window {
	wnd := window_get_basic_template("MillionUV")

	wnd.handler = handler
	wnd.update = update

	wnd.after_instantiate = after_instantiate
	wnd.before_destroy = before_destroy

	wnd.window_flags += { .RESIZABLE }

    return wnd
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
	log.debugf("window {} instantiated.", name)

	wdata := window_data(WndMainData, wnd)
	init_imgui(&wdata.imgui_state, window)

	init()
	immediate_init()

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
	imsdl.process_event(event, &imgui_state.sdl_state)

	input_handle_sdl2(event)

	window_event := event.window
}

@(private="file")
render :: proc(using wnd:^Window) {
	wnd_data := window_data(WndMainData, wnd)

	draw_settings.screen_width = cast(f32)wnd.size.x
	draw_settings.screen_height = cast(f32)wnd.size.y

	col := [4]f32{.2, .8, .7, 1}
	gl.ClearColor(col.r, col.g, col.b, col.a)
	gl.Clear(gl.COLOR_BUFFER_BIT|gl.DEPTH_BUFFER_BIT|gl.STENCIL_BUFFER_BIT)

	imsdl.new_frame()

    io := imgui.get_io()
	
	imgui.new_frame()
	immediate_begin(dgl.Vec4i{0, 0, wnd.size.x, wnd.size.y})

	draw_game()

	immediate_end(game.immediate_draw_wireframe)

	imgui.end_frame()
	imgui.render()
	draw_data := imgui.get_draw_data();

	imgl.imgui_render(draw_data, wnd_data.imgui_state.opengl_state)
	sdl.GL_SwapWindow(wnd.window)
}

@(private="file") 
imgui_test :: proc(io: ^imgui.IO) {
    overlay_flags: imgui.Window_Flags = .NoDecoration | 
                                        .AlwaysAutoResize | 
                                        .NoSavedSettings | 
                                        .NoFocusOnAppearing | 
                                        .NoNav | 
                                        .NoMove
	imgui.begin("Test", nil, overlay_flags)
	{
		for i in 0..<5 {
			imgui.radio_button("", io.mouse_down[i])
			if i != 4 do imgui.same_line()
		}

		@static value:i32
		imgui.slider_int("Value", &value, 0, 64, "Value:%d")

		@static vec3i: [3]int
		imgui.slider_int3("Int3Slider", &vec3i, 0, 255)

		@static f3:Vec3
		imgui.slider_float3("Slider3Test", &f3, 0, 1)

	    imgui.text_unformatted("YOU WIN!!!")
	}
	imgui.end()

}

@(private="file")
update :: proc(using wnd:^Window) {
	update_game()
	render(wnd)
	input_after_update_sdl2()
}