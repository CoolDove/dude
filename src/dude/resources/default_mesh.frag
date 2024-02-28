#version 440 core
out vec4 FragColor;

#include "dude"

layout(location = 0) in vec2 _uv;
layout(location = 1) in vec4 _color;

uniform vec4 color;
uniform vec4 ex;
uniform sampler2D main_texture;

void main() {
    vec4 tex = texture(main_texture, _uv);
    FragColor = mix(color * tex, _color * tex, ex.x);
}