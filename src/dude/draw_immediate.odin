﻿package dude

import gl "vendor:OpenGL"
import "core:log"
import "core:strings"

import "dgl"


@(private="file")
ImmediateDrawElement :: struct {
    shader : u32,
    start, count : u32,
    texture : u32,
}

@(private="file")
ImmediateDrawContext :: struct {
    viewport : Vec4i,
    vertices : [dynamic]VertexPCU,
    elements : [dynamic]ImmediateDrawElement,

    // OpenGL
    vao : u32,
    basic_shader, font_shader : u32,
}

@(private="file")
ime_context : ImmediateDrawContext

immediate_begin :: proc (viewport: Vec4i) {
    if ime_context.vao == 0 {// init
        using ime_context
        gl.GenVertexArrays(1, &vao)
        basic_shader = res_get_shader("shader/builtin_immediate_basic.shader").id
        font_shader  = res_get_shader("shader/builtin_immediate_font.shader").id
    }

    clear(&ime_context.vertices)
    clear(&ime_context.elements)
    ime_context.viewport = viewport
}
@(private="file")
set_opengl_state_for_draw_immediate :: proc() {
    gl.Disable(gl.DEPTH_TEST)
    // gl.DepthMask(false)

    gl.Enable(gl.BLEND)
    gl.BlendEquation(gl.FUNC_ADD)
    gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

    gl.Enable(gl.CULL_FACE)
    gl.CullFace(gl.BACK)
}

immediate_end :: proc (wireframe:= false) {
    using ime_context
    set_opengl_state_for_draw_immediate()
    gl.BindVertexArray(vao)

    gl.Viewport(viewport.x, viewport.y, viewport.z, viewport.w)

    vbuffer : u32
    gl.GenBuffers(1, &vbuffer)
    defer gl.DeleteBuffers(1, &vbuffer)
    gl.BindBuffer(gl.ARRAY_BUFFER, vbuffer)
    gl.BufferData(gl.ARRAY_BUFFER, len(vertices) * size_of(VertexPCU), raw_data(vertices), gl.STREAM_DRAW)

    current_shader :u32= 0
    format_set := true

    loc_viewport_size :i32= -1
    loc_main_texture  :i32= -1

    default_tex_white := res_get_texture("texture/white.tex")

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
        else { gl.BindTexture(gl.TEXTURE_2D, default_tex_white.id) }
        gl.Uniform1i(loc_main_texture, 0)

        gl.DrawArrays(gl.TRIANGLES, cast(i32)e.start, cast(i32)e.count)
    }

    // Draw wireframe
    if wireframe {
        gl.Disable(gl.BLEND)

        polygon_mode_stash : u32
        gl.GetIntegerv(gl.POLYGON_MODE, cast(^i32)&polygon_mode_stash)
        gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE)

        gl.UseProgram(basic_shader)
        dgl.set_vertex_format_PCU(basic_shader)
        loc_viewport_size, loc_main_texture = switch_shader(basic_shader)
        gl.Uniform2f(
            loc_viewport_size, 
            cast(f32)(viewport.z - viewport.x), 
            cast(f32)(viewport.w - viewport.y))

        for e in elements {
            gl.ActiveTexture(gl.TEXTURE0)
            gl.BindTexture(gl.TEXTURE_2D, default_tex_white.id) 
            gl.Uniform1i(loc_main_texture, 0)
            gl.DrawArrays(gl.TRIANGLES, cast(i32)e.start, cast(i32)e.count)
        }

        gl.PolygonMode(gl.FRONT_AND_BACK, polygon_mode_stash)
    }


}

// return uniform location
@(private="file")
switch_shader :: proc(shader : u32) -> (viewport_size, main_texture : i32) {
    gl.UseProgram(shader)
    dgl.set_vertex_format_PCU(shader)

    viewport_size = gl.GetUniformLocation(shader, "viewport_size")
    main_texture  = gl.GetUniformLocation(shader, "main_texture")
    return viewport_size, main_texture
}



// NOTE: How to add a new immediate draw element
// Push some new vertices to the ime_context.vertices, 
// and mark the start and end in the ImmediateDrawElement.

/*
(0,0)-------------*
|                 |
|    viewport     |
|                 |
*-------------(w,h)
*/
immediate_quad :: proc (leftup, size: Vec2, color: Color) -> ^ImmediateDrawElement {
    element := ImmediateDrawElement{
        ime_context.basic_shader,
        cast(u32)len(ime_context.vertices), 6,
        0}

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
    append(vertices, a, c, b, b, c, d)
    append(&ime_context.elements, element)
    return &ime_context.elements[len(ime_context.elements) - 1]
}

immediate_texture :: proc(leftup, size: Vec2, color: Color, texture : u32) -> ^ImmediateDrawElement {
    quad := immediate_quad(leftup, size, color)
    quad.texture = texture
    return quad
}

immediate_measure_text_width :: proc(font: ^DynamicFont, text: string) -> f32 {
    for r in text {
        if r == ' ' do continue
        glyph := font_get_glyph_id(font, r)
        if !font_is_glyph_loaded(font, glyph) {
            if !font_load_glyph(font, glyph) {
                log.errorf("Empty glyph `{}` in font.", r)
            }
        }
    }

    o : Vec2

    // One draw element per rune currently.
    for r, ind in text {
        if r == '\n' || r == '\t' do continue // Just ignore.
        glyph := font_get_glyph_info(font, r)
        if glyph != nil {
            o += {cast(f32)glyph.advance_h * font.scale, 0}
        } else {// for space
            o += {cast(f32)font_get_space_advance(font) * font.scale, 0}
        }
    }
    return o.x
}

immediate_text :: proc(font: ^DynamicFont, text: string, origin: Vec2, color: Color) {
    for r in text {
        if r == ' ' do continue
        glyph := font_get_glyph_id(font, r)
        if !font_is_glyph_loaded(font, glyph) {
            if !font_load_glyph(font, glyph) {
                log.errorf("Empty glyph `{}` in font.", r)
            }
        }
    }

    o := origin

    // One draw element per rune currently.
    last_rune := ' '
    for r, ind in text {
        if r == '\n' || r == '\t' do continue

        glyph := font_get_glyph_info(font, r)

        if glyph != nil {
            elem : ImmediateDrawElement
            elem.start = cast(u32) len(ime_context.vertices)
            elem.count = 0
            quad := make_quad(color)
            a, b, c, d := &quad[0], &quad[1], &quad[2], &quad[3]
            w, h       :f32= cast(f32)glyph.width, cast(f32)glyph.height
            xoff, yoff :f32= cast(f32)glyph.xoff, cast(f32)glyph.yoff
            kern := font_get_kern(font, font_get_glyph_id(font, last_rune), font_get_glyph_id(font, r))
            for v in &quad {
                v.position = v.position * {w + cast(f32)kern * font.scale, h, 1}
                v.position += {o.x + xoff, o.y + yoff, 0}
            }
            o += {cast(f32)glyph.advance_h * font.scale, 0}
            last_rune = r

            append(&ime_context.vertices, a^, c^, b^, b^, c^, d^)
            elem.count += 6

            elem.shader = ime_context.font_shader
            if r != ' ' do elem.texture = font_get_glyph_info(font, r).texture_id
            append(&ime_context.elements, elem)
        } else {// for space
            o += {cast(f32)font_get_space_advance(font) * font.scale, 0}
            last_rune = r
        }
    }
}

// The triangle data should be: {a, c, b, b, c, d}
@(private="file")
make_quad :: proc(color: Vec4) -> [4]VertexPCU {
    /*
      a:(0, 0) d:(1, 1)
      a------b
      |      |
      |      |
      c------d
    */
    a := VertexPCU{
        Vec3{0, 0, 0},
        color,
        Vec2{0, 1},
    }
    b := VertexPCU{
        Vec3{1, 0, 0},
        color,
        Vec2{1, 1},
    }
    c := VertexPCU{
        Vec3{0, 1, 0},
        color,
        Vec2{0, 0},
    }
    d := VertexPCU{
        Vec3{1, 1, 0},
        color,
        Vec2{1, 0},
    }

    return { a, b, c, d } 
}