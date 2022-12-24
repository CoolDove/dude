package dgl

import gl "vendor:OpenGL"
import dsh "./shader"
import "core:log"


@(private="file")
ImmediateDrawElement :: struct {
    shader : u32,
    start, count : u32,
    texture : u32
}

@(private="file")
ImmediateDrawContext :: struct {
    viewport : Vec4i,
    vertices : [dynamic]VertexPCU,
    elements : [dynamic]ImmediateDrawElement,
    vao, basic_shader : u32,

    default_texture_white, default_texture_black : u32

}

@(private="file")
ime_context : ImmediateDrawContext

immediate_init :: proc () {
    gl.GenVertexArrays(1, &ime_context.vao)

    ime_context.default_texture_white = texture_create(4, 4, [4]u8{0xff, 0xff, 0xff, 0xff})
    ime_context.default_texture_black = texture_create(4, 4, [4]u8{0x00, 0x00, 0x00, 0xff})

	vertex_shader_src := `
#version 440 core

layout (location = 0) in vec3 position;
layout (location = 1) in vec4 color;
layout (location = 2) in vec2 uv;

layout(location = 0) out vec2 _uv;
layout(location = 1) out vec4 _color;

uniform vec2 viewport_size;

void main()
{
    vec2 p = vec2(position.x, position.y);
    p /= viewport_size;
    p = p * vec2(2, 2) + vec2(-1, -1);

    gl_Position = vec4(p.x, p.y * -1, 0, 1.0);
	_uv = uv;
    _color = color;
}
	`
	fragment_shader_src :=`
#version 440 core
out vec4 FragColor;

layout(location = 0) in vec2 _uv;
layout(location = 1) in vec4 _color;

uniform sampler2D main_texture;

void main() { 
    vec4 c = texture(main_texture, _uv);
    FragColor = c * _color;
}
	`
    ime_context.basic_shader = load_shader(vertex_shader_src, fragment_shader_src).native_id
}

@(private="file") 
load_shader :: proc(vertex_source, frag_source : string)  -> dsh.Shader {
	shader_comp_vertex := dsh.create_component(.VERTEX_SHADER, vertex_source)
	shader_comp_fragment := dsh.create_component(.FRAGMENT_SHADER, frag_source)
	shader := dsh.create(&shader_comp_vertex, &shader_comp_fragment)
	dsh.destroy_components(&shader_comp_vertex, &shader_comp_fragment)
	return shader
}

immediate_begin :: proc (viewport: Vec4i) {
    clear(&ime_context.vertices)
    clear(&ime_context.elements)
    ime_context.viewport = viewport
}
immediate_end :: proc () {
    using ime_context
    gl.BindVertexArray(vao)

    gl.Viewport(viewport.x, viewport.y, viewport.z, viewport.w)

    gl.Enable(gl.BLEND)
    gl.BlendEquation(gl.FUNC_ADD)
    gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

    vbuffer : u32
    gl.GenBuffers(1, &vbuffer)
    defer gl.DeleteBuffers(1, &vbuffer)
    gl.BindBuffer(gl.ARRAY_BUFFER, vbuffer)
    gl.BufferData(gl.ARRAY_BUFFER, len(vertices) * size_of(VertexPCU), raw_data(vertices), gl.STREAM_DRAW)

    current_shader :u32= 0
    format_set := true

    loc_viewport_size :i32= -1
    loc_main_texture  :i32= -1

    for e in elements {
        if e.shader != current_shader || format_set {
            current_shader = e.shader
            loc_viewport_size, loc_main_texture = switch_shader(current_shader)
            gl.Uniform2f(
                loc_viewport_size, 
                cast(f32)(viewport.z - viewport.x), 
                cast(f32)(viewport.w - viewport.y))
            format_set = false
        }

        gl.ActiveTexture(gl.TEXTURE0)
        if e.texture != 0 { gl.BindTexture(gl.TEXTURE_2D, e.texture) }
        else { gl.BindTexture(gl.TEXTURE_2D, ime_context.default_texture_white) }
        gl.Uniform1i(loc_main_texture, 0)

        gl.DrawArrays(gl.TRIANGLES, cast(i32)e.start, cast(i32)e.count)
    }
}

// return uniform location
@(private="file")
switch_shader :: proc(shader : u32) -> (viewport_size, main_texture : i32) {
    gl.UseProgram(shader)
    set_vertex_format_PCU(shader)

    viewport_size = gl.GetUniformLocation(shader, "viewport_size")
    main_texture  = gl.GetUniformLocation(shader, "main_texture")
    return viewport_size, main_texture
}

/*
(0,0)-------------*
|                 |
|    viewport     |
|                 |
*-------------(w,h)
*/
immediate_quad :: proc (leftup, size: Vec2, color: Vec4) -> ^ImmediateDrawElement {
    element := ImmediateDrawElement{
        ime_context.basic_shader,
        cast(u32)len(ime_context.vertices), 6,
        0
    }

    rightdown := leftup + size
    vertices := &ime_context.vertices
    /*
      a------b
      |      |
      |      |
      c------d
    */
    a := VertexPCU{
        Vec3{leftup.x, leftup.y, 0},
        color,
        Vec2{0, 1},
    }
    b := VertexPCU{
        Vec3{rightdown.x, leftup.y, 0},
        color,
        Vec2{1, 1},
    }
    c := VertexPCU{
        Vec3{leftup.x, rightdown.y, 0},
        color,
        Vec2{0, 0},
    }
    d := VertexPCU{
        Vec3{rightdown.x, rightdown.y, 0},
        color,
        Vec2{1, 0},
    }
    append(vertices, a, b, c, b, d, c)
    append(&ime_context.elements, element)
    return &ime_context.elements[len(ime_context.elements) - 1]
}

immediate_texture :: proc(leftup, size: Vec2, color: Vec4, texture : u32) -> ^ImmediateDrawElement {
    quad := immediate_quad(leftup, size, color)
    quad.texture = texture
    return quad
}