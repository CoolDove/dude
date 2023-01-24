package dude

import "core:os"
import "core:strings"
import "core:time"
import "core:math"
import "core:log"
import "core:math/linalg"

import gl "vendor:OpenGL"
import "dgl"
import "ecs"

// Gizmos is drawn in world space.
// So a camera is needed.

@(private="file")
GizmosDrawContext :: struct {
    // State
    vao : u32,
    mtx   : linalg.Matrix4x4f32,
    color : Color,
    camera : ^Camera,
    drawing : bool,

    // Data
    lines : [dynamic]LineSeg,

    // Res
    gizmos_shader : u32,
}
@(private="file")
LineSeg :: [2]VertexPCU

@(private="file")
gizmos_context : GizmosDrawContext

gizmos_begin :: proc(cam: ^Camera) {
    using gizmos_context
    if !gizmos_inited() do gizmos_init()
    mtx = linalg.MATRIX4F32_IDENTITY
    color = COLORS.WHITE
    camera = cam
    clear(&lines)
    drawing = true
}
gizmos_end :: proc() {
    using gizmos_context
    if !drawing || camera == nil do return
    gl.BindVertexArray(vao)

    vbuffer : u32
    gl.GenBuffers(1, &vbuffer)
    defer gl.DeleteBuffers(1, &vbuffer)
    gl.BindBuffer(gl.ARRAY_BUFFER, vbuffer)
    gl.BufferData(gl.ARRAY_BUFFER, len(lines) * size_of(VertexPCU) * 2, raw_data(lines), gl.STREAM_DRAW)

    gl.UseProgram(gizmos_shader)
    dgl.set_vertex_format_PCU(gizmos_shader)

    cam_transform := ecs.get_component(camera.world, camera.entity, Transform)
    assert(cam_transform != nil, "Camera should have a `Transform` component.")
    mat_view_projection := dgl.matrix_camera_vp_perspective(
        cam_transform.position, 
        cam_transform.orientation,
        camera.fov, camera.near, camera.far,
        cast(f32)game.window.size.x/cast(f32)game.window.size.y,
    )

    uni_loc_matrix_view_projection := gl.GetUniformLocation(gizmos_shader, "matrix_view_projection")
    gl.UniformMatrix4fv(uni_loc_matrix_view_projection, 
        1, false, linalg.matrix_to_ptr(&mat_view_projection))

    polygon_mode_stash : u32
    gl.GetIntegerv(gl.POLYGON_MODE, cast(^i32)&polygon_mode_stash)
    gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE)
    gl.DrawArrays(gl.LINES, 0, cast(i32)len(lines) * 2)
    gl.PolygonMode(gl.FRONT_AND_BACK, polygon_mode_stash)

    drawing = false
}

gizmos_set_color :: proc(color: Color) {
    if !gizmos_context.drawing do return
    gizmos_context.color = color
}

gizmos_line :: proc(positions : ..Vec3) {
    using gizmos_context
    if !drawing do return
    for i in 0..<len(positions)-1 {
        a := VertexPCU {
            positions[i],
            color,
            {0,0},
        }
        b := VertexPCU {
            positions[i+1],
            color,
            {0,0},
        }
        append(&lines, LineSeg{a, b})
    }
}

@(private="file")
gizmos_inited :: #force_inline proc() -> bool {
    return gizmos_context.vao != 0
}

@(private="file")
gizmos_init :: proc() {
    using gizmos_context
    gl.GenVertexArrays(1, &gizmos_context.vao)
    gizmos_shader = dgl.shader_load_vertex_and_fragment(
        SHADER_SRC_GIZMOS_VERTEX, SHADER_SRC_GIZMOS_FRAGMENT).id
}

@(private="file")
set_opengl_state_for_draw_gizmos :: proc() {
    gl.Enable(gl.DEPTH_TEST)
    gl.Disable(gl.BLEND)
}


@(private="file")
SHADER_SRC_GIZMOS_VERTEX :: `
#version 440 core

layout (location = 0) in vec3 position;
layout (location = 1) in vec4 color;
layout (location = 2) in vec2 uv;

layout(location = 0) out vec4 _color;
layout(location = 1) out vec2 _uv;

uniform mat4 matrix_view_projection;

void main()
{
    vec4 wpos = vec4(position.x, position.y, position.z, 1);
    gl_Position = matrix_view_projection * wpos;
    _color = color;
    _uv = uv;
}
`
@(private="file")
SHADER_SRC_GIZMOS_FRAGMENT :=`
#version 440 core
out vec4 FragColor;

layout(location = 0) in vec4 _color;
layout(location = 1) in vec2 _uv;

void main() { 
    FragColor = _color;
}
`