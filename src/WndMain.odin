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
import dsh "dgl/shader"
import dbuf "dgl/buffer"
import dva "dgl/vertex_array"

WndMainData :: struct {
	imgui_state : ImguiState,
	vertices : [15]f32,

	shader : dsh.Shader,
	vertex_buffer : dbuf.Buffer,
	vertex_array : dva.VertexArray
}

ImguiState :: struct {
	sdl_state : imsdl.SDL_State,
	opengl_state : imgl.OpenGL_State,
}

create_main_window :: proc (allocator:=context.allocator, loc := #caller_location) -> Window {
	wnd := window_get_basic_template("MillionUV")

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

	wdata := window_data(WndMainData, wnd)
	using wdata

	// prepare gl rendering data
	vertices = [?]f32{
		-.5, -.5,  0,   0, 0,
		 .5, -.5,  0,   0, 1,
		  0,  .5,  0,   1, 0
	}

	vertex_buffer = dbuf.create()
	
	dbuf.store(&vertex_buffer, size_of(vertices), raw_data(vertices[:]), .DYNAMIC_DRAW)

	vertex_shader_src := `

#version 330 core

layout (location = 0) in vec3 aPos;
layout (location = 1) in vec2 uv;

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
	shader = load_shader(vertex_shader_src, fragment_shader_src)
	if shader.native_id != 0 do dsh.bind(&shader)

	{
		pos := dva.VertexAttribute{"position", 3, .FLOAT, .Float, false}
		uv := dva.VertexAttribute{"uv", 2, .FLOAT, .Float, false}
		vertex_array = dva.create(&vertex_buffer, pos, uv)
	}

	init_imgui(&imgui_state, window)
}

@(private="file") 
load_shader :: proc(vertex_source, frag_source : string)  -> dsh.Shader {
	shader_comp_vertex := dsh.create_component(.VERTEX_SHADER, vertex_source)
	shader_comp_fragment := dsh.create_component(.FRAGMENT_SHADER, frag_source)
	shader := dsh.create(&shader_comp_vertex, &shader_comp_fragment)
	dsh.destroy_components(&shader_comp_vertex, &shader_comp_fragment)
	return shader
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
	col *= [4]f32{0..<4 = math.sin(cast(f32)total_ms * .004) * .5 + 1}

    gl.Viewport(0, 0, i32(size.x), i32(size.y))
    gl.Scissor(0, 0, i32(size.x), i32(size.y))
	gl.ClearColor(col.r, col.g, col.b, col.a)
	gl.Clear(gl.COLOR_BUFFER_BIT|gl.DEPTH_BUFFER_BIT|gl.STENCIL_BUFFER_BIT)

	render_gltest(wnd);

	imsdl.new_frame()

    io := imgui.get_io()
	
	imgui.new_frame()

    overlay_flags: imgui.Window_Flags = .NoDecoration | 
                                        .AlwaysAutoResize | 
                                        .NoSavedSettings | 
                                        .NoFocusOnAppearing | 
                                        .NoNav | 
                                        .NoMove
	imgui.begin("Test", nil, overlay_flags)
	{
		imgui_logger_checkboxex()

		for i in 0..<5 {
			imgui.radio_button("", io.mouse_down[i])
			if i != 4 do imgui.same_line()
		}

		@static test_col : [4]f32
		imgui.color_picker4("Color", cast(^Vec4)&test_col)

		@static value:i32
		imgui.slider_int("Value", &value, 0, 64, "Value:%d")

		@static vec3i: Vec3i
		imgui.slider_int3("Int3Slider", &vec3i, 0, 255)

		@static f2:Vec2
		imgui.slider_float2("Slider2Test", &f2, 0, 1)
		@static f3:Vec3
		imgui.slider_float3("Slider3Test", &f3, 0, 1)
		@static f4:Vec4
		imgui.slider_float4("Slider4Test", &f4, 0, 1)

	    imgui.text_unformatted("YOU WIN!!!")
	}
	imgui.end()

	imgui.end_frame()
	imgui.render()
	draw_data := imgui.get_draw_data();

	imgl.imgui_render(draw_data, imgui_state.opengl_state)
	sdl.GL_SwapWindow(wnd.window)
}

@(private="file")
imgui_logger_checkboxex :: proc() {
	logger := context.logger
	
	using log.Option
	level_before := .Level in logger.options
	level_after  := level_before
	time_before := .Time in logger.options
	time_after  := time_before
	line_before := .Line in logger.options
	line_after := line_before

	imgui.checkbox("Level", &level_after)
	imgui.checkbox("Time", &time_after)
	imgui.checkbox("Line", &line_after)

	dirty := false 

	if level_after != level_before {
		dirty = true
		if level_after do incl(&logger.options, log.Option.Level)
		else do excl(&logger.options, log.Option.Level)
	}
	if time_after != time_before {
		if time_after do incl(&logger.options, log.Option.Time)
		else do excl(&logger.options, log.Option.Time)
	}
	if line_after != time_before {
		if line_after do incl(&logger.options, log.Option.Line)
		else do excl(&logger.options, log.Option.Line)
	}
	if dirty {
		context.logger = logger
	}
}


@(private="file")
render_gltest :: proc(using wnd:^Window) {
	wdata := window_data(WndMainData, wnd);
	using wdata

	total_ms := time.duration_milliseconds(app.duration_total) 
	randseed := rand.create(cast(u64)total_ms)

	new_data := [?]f32 {
		rand.float32(&randseed),
		rand.float32(&randseed),
		rand.float32(&randseed),
	}

	dbuf.set(&vertex_buffer, 0, 3 * size_of(u8), raw_data(new_data[:]))

	// gl.BindVertexArray(vao)
	dva.bind(&vertex_array)
	dsh.bind(&shader)

	gl.DrawArrays(gl.TRIANGLES, 0, 3)

}


@(private="file")
update_proc :: proc(using wnd:^Window) {
}