##VERTEX
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

##FRAGMENT
#version 440 core
out vec4 FragColor;

layout(location = 0) in vec4 _color;
layout(location = 1) in vec2 _uv;

void main() { 
    FragColor = _color;
}
