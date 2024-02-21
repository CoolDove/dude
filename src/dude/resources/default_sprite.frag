#version 440 core
out vec4 FragColor;

layout(location = 0) in vec2 _uv;

uniform vec4 color;

void main() {
    FragColor = vec4(_uv.x, _uv.y, 0,1) * color;
}
