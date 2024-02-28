#version 440 core

#include "dude"

layout (location = 0) in vec2 position;
layout (location = 1) in vec2 uv;
layout (location = 2) in vec4 color;

layout (location = 0) out vec2 _uv;
layout (location = 1) out vec4 _color;

void main()
{
    vec2 pos = transform_point_local2world(position, transform_position, transform_scale, transform_angle);
    pos = transform_point_world2camera(pos);
    gl_Position = vec4(pos.x, pos.y, 0.5, 1.0);
	_uv = uv;
    _color = color;
}
