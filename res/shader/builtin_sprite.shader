##VERTEX

#version 440 core

layout (location = 0) in vec3 position;
layout (location = 1) in vec4 color;
layout (location = 2) in vec3 normal;
layout (location = 3) in vec2 uv;

layout(location = 0) out vec2 _uv;
layout(location = 1) out vec3 _normal;
layout(location = 2) out vec4 _color;

// Matrixs
uniform mat4 matrix_view_projection;
uniform mat4 matrix_model;

void main()
{
    vec4 wpos = matrix_model * vec4(position.x, position.y, position.z, 1);
    gl_Position = matrix_view_projection * wpos;
	_uv = uv;
    _color = color;
    _normal = normal;// not correct
}

##FRAGMENT

#version 440 core
out vec4 FragColor;

layout(location = 0) in vec2 _uv;
layout(location = 1) in vec3 _normal;
layout(location = 2) in vec4 _color;

uniform sampler2D main_texture;

void main() {
    vec4 c = texture(main_texture, _uv);
    FragColor = c;
    FragColor.a = 1.0;
}