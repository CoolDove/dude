#version 440 core
out vec4 FragColor;

layout(location = 0) in vec2 _uv;
layout(location = 1) in vec3 _normal;
layout(location = 2) in vec4 _color;
layout(location = 3) in mat4 _mat_local_to_world_direction;

uniform sampler2D main_texture;

uniform vec3 light_direction;
uniform vec4 light_color;// xyz: color, z: nor using

void main() {
    vec4 c = texture(main_texture, _uv);

    // FragColor = c * _color + vec4(_normal.x, _normal.y, _normal.z, 0) * 0.01;
    vec4 normal_vec4 = vec4(_normal.x, _normal.y, _normal.z, 0);
    normal_vec4 = _mat_local_to_world_direction * normal_vec4;

    vec3 world_normal = vec3(normal_vec4.x, normal_vec4.y, normal_vec4.z);
    float n_dot_l = dot(normalize(world_normal), light_direction);
    n_dot_l = n_dot_l * 2 + 1;

    FragColor = c * _color * n_dot_l * light_color;
    FragColor.a = 1.0;

    // FragColor = vec4(n_dot_l, n_dot_l, n_dot_l, 1);
}