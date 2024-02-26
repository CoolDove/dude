#version 440 core
out vec4 FragColor;

#include "dude"

layout(location = 0) in vec2 _uv;

uniform vec4 color;
uniform sampler2D main_texture;

void main() {
    vec4 tex = texture(main_texture, _uv);
    FragColor = color * tex;
}
