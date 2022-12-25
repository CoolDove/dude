package main

import "core:time"

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

    @static debug_texture := false
    imgui.checkbox("debug_texture", &debug_texture)
    img := &game.test_image
    if debug_texture {
        img_gallery_x :f32= 0
        immediate_texture({img_gallery_x, wnd_size.y - 64}, {64, 64}, {1, 1, 1, 1}, 
            game.test_obj.mesh.submeshes[0].texture)
        img_gallery_x += 64 + 10
        immediate_texture(
            {img_gallery_x, cast(f32)wnd_size.y - cast(f32)img.size.y}, 
            {auto_cast img.size.x, auto_cast img.size.y},
            {1, 1, 1, 1},
            img.texture_id
        )
        img_gallery_x += cast(f32)img.size.x + 10
    }

    imgui.slider_float3("camera position", &game.camera.position, -10, 10)

    gl.BindVertexArray(game.vao)
    dgl.set_opengl_state_for_draw_geometry()
    dgl.draw_mesh(&game.test_obj.mesh, &game.test_obj.transform, &game.camera)
}

update_game :: proc() {
    obj := &game.test_obj

    total_ms := cast(f32)time.duration_milliseconds(app.duration_total) 
    obj.transform.orientation = auto_cast linalg.quaternion_from_euler_angle_y(total_ms * 0.001)

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
uniform mat4 matrix_model;

void main()
{
    vec4 wpos = matrix_model * vec4(position.x, position.y, position.z, 1);
    gl_Position = matrix_view_projection * wpos;
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

    box_img := dgl.texture_load("./res/texture/box.png")
    dgl.image_free(&box_img)

    dgl.make_cube(&game.test_obj.mesh, game.basic_shader.native_id)
    game.test_obj.mesh.submeshes[0].texture = box_img.texture_id

    game.camera.position = {0, 0, 3.5}
    game.camera.fov  = 45
    game.camera.near = .1 
    game.camera.far  = 300
    // game.camera.orientation = cast(quaternion128)linalg.quaternion_from_forward_and_up(Vec3{0, 0, 1}, Vec3{0, 1, 0})
    game.camera.forward = {0, 0, -1}
    game.camera.scale = {1, 1, 1}

    transform := &game.test_obj.transform
    transform.scale = {1, 1, 1}
    transform.orientation = cast(quaternion128)linalg.quaternion_from_euler_angles_f32(0, 0, 0, .XYZ)
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