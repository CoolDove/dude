package dude


import "core:math/linalg"

// Gizmos is drawn in world space.
// So a camera is needed.

@(private="file")
GizmosDrawContext :: struct {
    mtx   : linalg.Matrix4x4f32,
    color : Color,
    lines : [dynamic][2]VertexPCNU,
    mtx_camera_vp : linalg.Matrix4x4f32,
    vao : u32,
}

@(private="file")
gizmos_context : GizmosDrawContext

gizmos_begin :: proc() {

}
gizmos_end :: proc() {
}

gizmos_line :: proc(from, to : Vec3) {

}


@(private="file")
SHADER_SRC_GIZMOS_VERTEX :: `
#version 440 core

layout (location = 0) in vec3 position;
layout (location = 1) in vec4 color;

layout(location = 1) out vec4 _color;

uniform vec2 viewport_size;

void main()
{
    vec2 p = vec2(position.x, position.y);
    p /= viewport_size;
    p = p * 2 - 1;
    gl_Position = vec4(p.x, p.y * -1, 0, 1.0);
    _color = color;
}
`
@(private="file")
SHADER_SRC_GIZMOS_FRAGMENT :=`
#version 440 core
out vec4 FragColor;

layout(location = 1) in vec4 _color;

void main() { 
    FragColor = _color;
}
`