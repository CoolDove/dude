#version 440 core
out vec4 FragColor;

layout(location = 0) in vec2 _uv;

uniform vec4 mesh_color;
uniform sampler2D mesh_texture;

void main() {
    vec4 tex = texture(mesh_texture, _uv);
    FragColor = mesh_color * tex;
}
