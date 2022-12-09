package main

import "core:fmt"
import "core:os"
import "core:strings"
import "core:time"
import "core:math"
import "core:log"

import sdl  "vendor:sdl2"
import gl   "vendor:OpenGL"

import imgl "pac:imgui/impl/opengl"
import imsdl "pac:imgui/impl/sdl"

import "pac:imgui"


WndMainData :: struct {
	imgui_state : ImguiState,
	vertices : [9]f32,
	vbo:u32, 
}

ImguiState :: struct {
	sdl_state : imsdl.SDL_State,
	opengl_state : imgl.OpenGL_State,
}

create_main_window :: proc (allocator:=context.allocator, loc := #caller_location) -> Window {
	wnd := window_get_basic_template("Dove")

	wnd.handler = handler
	wnd.render = render_proc
	wnd.update = update_proc
	// wnd.renderer_flags = {.ACCELERATED, .PRESENTVSYNC, .TARGETTEXTURE}

	wnd.after_instantiate = after_instantiate

    return wnd
}

@(private="file")
after_instantiate :: proc(using wnd: ^Window) {
	fmt.printf("window {} instantiated.\n", name)

	// data := window_data(WndMainData, wnd);
	wdata := window_data(WndMainData, wnd)
	using wdata

	imgui.create_context()
	imgui.style_colors_dark()

	imsdl.setup_state(&imgui_state.sdl_state)
	imgl.setup_state(&imgui_state.opengl_state)

	// prepare gl rendering data
	vertices = [?]f32{
		-.5,  .5,  0,
		 .5, -.5,  0,
		  0,  .5,  0
	}

	gl.GenBuffers(1, &vbo)
	gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
	gl.BufferData(gl.ARRAY_BUFFER, size_of(vertices), &vertices, gl.STATIC_DRAW)
	
	vertex_shader_src := strings.clone_to_cstring(`
#version 330 core
layout (location = 0) in vec3 aPos

void main()
{
    gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0)
}
	`, context.temp_allocator)

	vertex_shader := gl.CreateShader(gl.VERTEX_SHADER)
	length :i32
	gl.ShaderSource(vertex_shader, 1, &vertex_shader_src, &length)
	gl.CompileShader(vertex_shader)

	success : i32;
	gl.GetShaderiv(vertex_shader, gl.COMPILE_STATUS, &success)

	if success == 0 {
		shader_log_length:i32
		info_buf : [dynamic]u8
		defer delete(info_buf)
		gl.GetShaderInfoLog(vertex_shader, 512, &shader_log_length, raw_data(info_buf))
		fmt.printf("Failed to compile shader because: %s\n", info_buf);
	} else {
		fmt.printf("Shader compiled!\n")
	}
}


@(private="file")
handler :: proc(using wnd:^Window, event:sdl.Event) {
	wnd_data := window_data(WndMainData, wnd)
	using wnd_data
	imsdl.process_event(event, &imgui_state.sdl_state)

	window_event := event.window


	#partial switch eid := window_event.event; eid {
	case .CLOSE :{
		window_destroy(wnd)
	}
	}
}

@(private="file")
render_proc :: proc(using wnd:^Window) {
	wnd_data := window_data(WndMainData, wnd)
	using wnd_data

	col := [4]f32{.2, .8, .7, 1}
	total_ms := time.duration_milliseconds(app.duration_total)
	col *= [4]f32{0..<4 = math.sin(cast(f32)total_ms * .01) * .5 + 1}

	gl.ClearColor(col.r, col.g, col.b, col.a)
	gl.Clear(gl.COLOR_BUFFER_BIT|gl.DEPTH_BUFFER_BIT|gl.STENCIL_BUFFER_BIT)

	render_gltest(wnd);

    imsdl.update_display_size(window)
    imsdl.update_mouse(&imgui_state.sdl_state, window)
    imsdl.update_dt(&imgui_state.sdl_state)
	imgui.new_frame()

    imgui.set_next_window_pos(imgui.Vec2{10, 10})
    imgui.set_next_window_bg_alpha(0.2)
    overlay_flags: imgui.Window_Flags = .NoDecoration | 
                                        .AlwaysAutoResize | 
                                        .NoSavedSettings | 
                                        .NoFocusOnAppearing | 
                                        .NoNav | 
                                        .NoMove
	imgui.begin("Test", nil, overlay_flags)
	imgui.button("hello dove", imgui.Vec2{200, 10})
    imgui.text_unformatted("Press Esc to close the application")
    imgui.text_unformatted("Press Tab to show demo window")
	imgui.end()

    io := imgui.get_io()

    gl.Viewport(0, 0, i32(io.display_size.x), i32(io.display_size.y))
    gl.Scissor(0, 0, i32(io.display_size.x), i32(io.display_size.y))

	imgui.render()
	imgl.imgui_render(imgui.get_draw_data(), imgui_state.opengl_state)
	sdl.GL_SwapWindow(wnd.window)
}

@(private="file")
render_gltest :: proc(using wnd:^Window) {

}


@(private="file")
update_proc :: proc(using wnd:^Window) {
}

@(private="file")
render_slashes :: proc(renderer:^sdl.Renderer, count, interval:u32) {
	sdl.SetRenderDrawColor(renderer, 0, 0, 0, 255)

	xa, xb :i32= 10, 20
	for i in 0..<count {
		y :i32= cast(i32)( (i + 1) * interval )
	    sdl.RenderDrawLine(renderer, xa, y, xb, y)
	}
}
