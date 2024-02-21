#version 440 core
out vec4 FragColor;

layout(location = 0) in vec2 _uv;

uniform vec4 color;
uniform int texture;

void main() {
    FragColor = color;
}
