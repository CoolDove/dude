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
	render_repository : ^RenderRepository,

	static_render_objects    : [dynamic]RenderObject,
	immediate_render_objects : [dynamic]RenderObject
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
	wnd.before_destroy = before_destroy

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
	wdata.render_repository = new(RenderRepository)
	prepare_render_repository(wdata.render_repository)

	basic_shader := &wdata.render_repository.shaders["Basic"]
	basic_vertex_array := &wdata.render_repository.vertex_arrays["Basic"]

	{// make quad
		vertices := [?]f32{
			-.5,  .5,  0,   0, 1,
			 .5,  .5,  0,   1, 1,
			-.5, -.5,  0,   0, 0,
			 .5, -.5,  0,   1, 0
		}
		indices := [?]i32 {
			0, 2, 1,
			1, 3, 2
		}
		vertex_buffer := dbuf.create()
		index_buffer := dbuf.create()
		dbuf.store(&vertex_buffer, size_of(vertices), raw_data(vertices[:]), .DYNAMIC_DRAW)
		dbuf.store(&index_buffer, size_of(indices), raw_data(indices[:]), .DYNAMIC_DRAW)
		quad := render_obj_create(
			basic_vertex_array, basic_shader, 
			vertex_buffer, index_buffer, 
			len(vertices), len(indices))
		append(&static_render_objects, quad)
	}
	{// make triangle
		vertices := [?]f32{
			-.5, -.5,  0,   0, 0,
			 .5, -.5,  0,   0, 1,
			  0,  .5,  0,   1, 0
		}
		indices := [?]i32 {
			0, 1, 2
		}
		vertex_buffer := dbuf.create()
		index_buffer := dbuf.create()
		dbuf.store(&vertex_buffer, size_of(vertices), raw_data(vertices[:]), .DYNAMIC_DRAW)
		dbuf.store(&index_buffer, size_of(indices), raw_data(indices[:]), .DYNAMIC_DRAW)
		triangle := render_obj_create(
			basic_vertex_array, basic_shader, 
			vertex_buffer, index_buffer, 
			len(vertices), len(indices))
		append(&static_render_objects, triangle)
	}

	init_imgui(&imgui_state, window)
}

@(private="file")
prepare_render_repository :: proc(using repo: ^RenderRepository) {
	shaders = make(map[string]dsh.Shader)
	vertex_arrays = make(map[string]dva.VertexArray)

	{
		pos := dva.VertexAttribute{"position", 3, .FLOAT, false}
		uv := dva.VertexAttribute{"uv", 2, .FLOAT, false}
		vertex_arrays["Basic"] = dva.create(pos, uv)
	}
	vertex_shader_src := `
#version 330 core

layout (location = 0) in vec3 aPos;
layout (location = 1) in vec2 aUV;

layout(location = 0) out vec2 uv;

void main()
{
    gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0);
	uv = aUV;
}
	`
	fragment_shader_src :=`
#version 440 core
out vec4 FragColor;

layout(location = 0) in vec2 uv;

void main()
{
    FragColor = vec4(uv.x, uv.y, 0.0, 1.0);
} 
	`
	shaders["Basic"] = load_shader(vertex_shader_src, fragment_shader_src)
}


@(private="file")
before_destroy :: proc(wnd: ^Window) {
	wdata := window_data(WndMainData, wnd)
	// TODO(Dove): Clean Render Repository

	log.debug("Resource clear.")
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
		for i in 0..<5 {
			imgui.radio_button("", io.mouse_down[i])
			if i != 4 do imgui.same_line()
		}

		@static value:i32
		imgui.slider_int("Value", &value, 0, 64, "Value:%d")

		@static vec3i: Vec3i
		imgui.slider_int3("Int3Slider", &vec3i, 0, 255)

		@static f3:Vec3
		imgui.slider_float3("Slider3Test", &f3, 0, 1)

	    imgui.text_unformatted("YOU WIN!!!")

		// if imgui.button("SwitchMesh") {
		// 	if current_robj == &quad do current_robj = &triangle
		// 	else do current_robj = &quad
		// }


	}
	imgui.end()

	imgui.end_frame()
	imgui.render()
	draw_data := imgui.get_draw_data();

	imgl.imgui_render(draw_data, imgui_state.opengl_state)
	sdl.GL_SwapWindow(wnd.window)
}



@(private="file")
render_gltest :: proc(using wnd:^Window) {
	wdata := window_data(WndMainData, wnd);

	current_shader : ^dsh.Shader
	current_vao : ^dva.VertexArray
	for srobj in &wdata.static_render_objects {
		shader := srobj.shader
		vao    := srobj.vertex_array
		if shader != nil && shader != current_shader {
			dsh.bind(shader)
		}
		if vao != nil && vao != current_vao {
			dva.bind(vao)
		}
		dva.attach_vertex_buffer(vao, &srobj.vertex_buffer, 0, vao.stride, 0)
		dva.attach_index_buffer(vao, &srobj.index_buffer)
		gl.DrawElements(gl.TRIANGLES, cast(i32)srobj.index_count, gl.UNSIGNED_INT, nil)
	}
	for srobj in &wdata.immediate_render_objects {
		shader := srobj.shader
		vao    := srobj.vertex_array
		if shader != nil && shader != current_shader {
			dsh.bind(shader)
		}
		if vao != nil && vao != current_vao {
			dva.bind(vao)
		}
		dva.attach_vertex_buffer(vao, &srobj.vertex_buffer, 0, vao.stride, 0)
		dva.attach_index_buffer(vao, &srobj.index_buffer)
		gl.DrawElements(gl.TRIANGLES, cast(i32)srobj.index_count, gl.UNSIGNED_INT, nil)
	}
}

@(private="file")
update_proc :: proc(using wnd:^Window) {
}