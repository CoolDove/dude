package main

import dgl "dgl"
import sdl "vendor:sdl2"

import gl "vendor:OpenGL"

import imgui "pac:imgui"

import linalg "core:math/linalg"

import dsh "dgl/shader"

Game :: struct {
    window : ^Window,

    basic_shader : dsh.Shader,

    camera     : dgl.Camera,
    test_image : dgl.Image,
    test_obj   : GameObject,
    vao        : u32,
}

game : Game

GameObject :: struct {
    mesh      : dgl.TriangleMesh,
    transform : dgl.Transform
}

draw_game :: proc() {
	using dgl

    wnd := game.window

	wnd_size := Vec2{cast(f32)wnd.size.x, cast(f32)wnd.size.y}
	immediate_quad(Vec2{wnd_size.x * 0.05, 0}, Vec2{wnd_size.x * 0.9, 20}, Vec4{ 1, 0, 0, 0.2 })
	immediate_quad(Vec2{40, 10}, Vec2{120, 20}, Vec4{ 0, 1, .4, 0.2 })
	immediate_quad(Vec2{10, 120}, Vec2{90, 20}, Vec4{ 1, 1, 1, 0.9 })

    @static show_icon := false
    imgui.checkbox("show_icon", &show_icon)
    img := &game.test_image
    if show_icon do immediate_texture(
        Vec2{120, 120}, Vec2{auto_cast img.size.x, auto_cast img.size.y}, 
        Vec4{1, 1, 1, 1},
        img.texture_id
    )
    
    imgui.slider_float3("camera position", &game.camera.position, -10, 10)

    gl.BindVertexArray(game.vao)
    dgl.draw_mesh(&game.test_obj.mesh, &game.test_obj.transform, &game.camera)

}

update_game :: proc() {

}

init_game :: proc() {
    game.test_image = dgl.texture_load("./res/texture/walk_icon.png")
    dgl.image_free(&game.test_image)

    gl.GenVertexArrays(1, &game.vao)

	vertex_shader_src := `
#version 440 core

layout (location = 0) in vec3 position;
layout (location = 1) in vec4 color;
layout (location = 2) in vec3 normal;
layout (location = 3) in vec2 uv;

layout(location = 0) out vec2 _uv;
layout(location = 1) out vec3 _normal;
layout(location = 2) out vec4 _color;

uniform mat4 matrix_view_projection;

void main()
{
    gl_Position = matrix_view_projection * vec4(position.x, position.y, position.z, 1);
	_uv = uv;
    _color = color;
    _normal = normal;// not correct
}
	`
	fragment_shader_src :=`
#version 440 core
out vec4 FragColor;

layout(location = 0) in vec2 _uv;
layout(location = 1) in vec3 _normal;
layout(location = 2) in vec4 _color;

uniform sampler2D main_texture;

void main() { 
    vec4 c = texture(main_texture, _uv);
    // FragColor = c * _color + vec4(_normal.x, _normal.y, _normal.z, 0) * 0.01;
    FragColor = c * _color;
    FragColor.a = 1.0;
}
	`
    game.basic_shader = load_shader(vertex_shader_src, fragment_shader_src)

    dgl.make_cube(&game.test_obj.mesh, game.basic_shader.native_id)
    game.camera.fov  = 45
    game.camera.near = .1 
    game.camera.far  = 300
    // game.camera.orientation = cast(quaternion128)linalg.quaternion_from_forward_and_up(Vec3{0, 0, 1}, Vec3{0, 1, 0})
    game.camera.forward = {0, 0, -1}
    game.camera.scale = {1, 1, 1}
}
@(private="file") 
load_shader :: proc(vertex_source, frag_source : string)  -> dsh.Shader {
	shader_comp_vertex := dsh.create_component(.VERTEX_SHADER, vertex_source)
	shader_comp_fragment := dsh.create_component(.FRAGMENT_SHADER, frag_source)
	shader := dsh.create(&shader_comp_vertex, &shader_comp_fragment)
	dsh.destroy_components(&shader_comp_vertex, &shader_comp_fragment)
	return shader
}

// TODO(Dove): This is not called now
quit_game :: proc() {
    gl.DeleteTextures(1, &game.test_image.texture_id)
    // dgl.mesh_release()
}