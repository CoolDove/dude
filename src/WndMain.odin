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
	vao, vbo, shader_program : u32, 
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

	// data := window_data(WndMainData, wnd);
	wdata := window_data(WndMainData, wnd)
	using wdata

	// prepare gl rendering data
	vertices = [?]f32{
		-.5, -.5,  0,
		 .5, -.5,  0,
		  0,  .5,  0
	}

	gl.GenVertexArrays(1, &vao)
	gl.BindVertexArray(vao)

	gl.GenBuffers(1, &vbo)
	gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
	gl.BufferData(gl.ARRAY_BUFFER, size_of(vertices), &vertices, gl.STATIC_DRAW)

	vertex_shader_src := `

#version 330 core

layout (location = 0) in vec3 aPos;

void main()
{
    gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0);
}
	`
	fragment_shader_src :=`
#version 440 core
out vec4 FragColor;

void main()
{
    FragColor = vec4(1.0f, 0.5f, 0.2f, 1.0f);
} 
	`

	vertex_shader := compile_shader_src(vertex_shader_src, gl.VERTEX_SHADER)
	fragment_shader := compile_shader_src(fragment_shader_src, gl.FRAGMENT_SHADER)

	shader_program = gl.CreateProgram()

	gl.AttachShader(shader_program, vertex_shader)
	gl.AttachShader(shader_program, fragment_shader)
	gl.LinkProgram(shader_program)
	gl.DeleteShader(vertex_shader)
	gl.DeleteShader(fragment_shader)

	link_success : i32
	gl.GetProgramiv(shader_program, gl.LINK_STATUS, &link_success)
	if link_success == 0 {
		info_length:i32
		info_buf : [512]u8
		gl.GetProgramInfoLog(shader_program, 512, &info_length, &info_buf[0]);
		log.debugf("Failed to link shader program, because: \n%s\n", info_buf)
	} else {
		log.debugf("Shader Program is initialized.")
		gl.UseProgram(shader_program)
	}

	gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * size_of(f32), 0);
	gl.EnableVertexAttribArray(0)

	init_imgui(&imgui_state, window)
}

@(private="file") 
compile_shader_src :: proc(src:string, shader_type:u32) -> u32 {
	cstr := strings.clone_to_cstring(src, context.temp_allocator)

	shader_obj := gl.CreateShader(shader_type)
	gl.ShaderSource(shader_obj, 1, &cstr, nil)
	gl.CompileShader(shader_obj)

	success : i32;
	gl.GetShaderiv(shader_obj, gl.COMPILE_STATUS, &success)

	if success == 0 {
		shader_log_length:i32
		info_buf : [512]u8
		gl.GetShaderInfoLog(shader_obj, 512, &shader_log_length, &info_buf[0])
		log.debugf("Failed to compile shader because: \n%s\n", info_buf);
		return 0;
	} else {
		log.debugf("Shader compiled! ID: {}.", shader_obj)
		return shader_obj;
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

    gl.Viewport(0, 0, i32(size.x), i32(size.y))
    gl.Scissor(0, 0, i32(size.x), i32(size.y))
	gl.ClearColor(col.r, col.g, col.b, col.a)
	gl.Clear(gl.COLOR_BUFFER_BIT|gl.DEPTH_BUFFER_BIT|gl.STENCIL_BUFFER_BIT)

	render_gltest(wnd);

	imsdl.new_frame()

    io := imgui.get_io()
	imgui_context := imgui.get_current_context()
	imgui_viewport := imgui.get_main_viewport()
	
	imgui.new_frame()

	imgui_viewport.size = io.display_size

    imgui.set_next_window_pos(imgui.Vec2{10, 10})
    imgui.set_next_window_bg_alpha(0.2)
    overlay_flags: imgui.Window_Flags = .NoDecoration | 
                                        .AlwaysAutoResize | 
                                        .NoSavedSettings | 
                                        .NoFocusOnAppearing | 
                                        .NoNav | 
                                        .NoMove
	imgui.begin("Test", nil, overlay_flags)
	imgui.button("HELLO DOVE")
    imgui.text_unformatted("YOU WIN!!!")
	imgui.end()

	// FIXME: [ imgui ] display size in draw_data is not updated.
	imgui.end_frame()
	imgui.render()
	draw_data := imgui.get_draw_data();

	// log.debugf("draw data display size: {}", draw_data.display_size)
	imgl.imgui_render(draw_data, imgui_state.opengl_state)
	sdl.GL_SwapWindow(wnd.window)
}

@(private="file")
render_gltest :: proc(using wnd:^Window) {
	wdata := window_data(WndMainData, wnd);
	using wdata
	gl.UseProgram(shader_program)
	gl.BindVertexArray(vao)

	gl.DrawArrays(gl.TRIANGLES, 0, 3)

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
