##VERTEX
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
    p = p * 2 - 1;

    gl_Position = vec4(p.x, p.y * -1, 0, 1.0);
	_uv = uv;
    _uv.y = 1 - _uv.y;
    _color = color;
}

##FRAGMENT
#version 440 core
out vec4 FragColor;

layout(location = 0) in vec2 _uv;
layout(location = 1) in vec4 _color;

uniform sampler2D main_texture;

void main() { 
    float c = texture(main_texture, _uv).r;
    FragColor = _color;
    FragColor.a *= c;
}