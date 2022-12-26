package main

import "core:time"
import "core:log"

import dgl "dgl"
import sdl "vendor:sdl2"

import gl "vendor:OpenGL"

import imgui "pac:imgui"

import linalg "core:math/linalg"

import dsh "dgl/shader"

Game :: struct {
    window : ^Window,

    basic_shader : dsh.Shader,

    main_light : dgl.LightData,

    camera     : dgl.Camera,
    test_image : dgl.Image,
    test_obj   : GameObject,
    vao        : u32,

    // GamePlay
    // rotate     : f32,

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
        imgui.image(cast(imgui.Texture_ID)cast(uintptr)img.texture_id, {64, 64}, {1, 1}, {0, 0})
        img_gallery_x += cast(f32)img.size.x + 10
    }

    imgui.slider_float3("camera position", &game.camera.position, -10, 10)

    if imgui.collapsing_header("MainLight") {
        imgui.color_picker4("color", &game.main_light.color)
        imgui.slider_float3("direction", &game.main_light.direction, -1, 1)

        game.main_light.direction = linalg.normalize0(game.main_light.direction)
    }

    imgui_debug_framerate()

    gl.BindVertexArray(game.vao)
    dgl.set_opengl_state_for_draw_geometry()
    dgl.draw_mesh(&game.test_obj.mesh, &game.test_obj.transform, &game.camera, &game.main_light)
    
}

@(private="file")
imgui_debug_framerate :: proc() {
    imgui.set_next_window_bg_alpha(.4)
    imgui.set_next_window_pos({10, 10}, .Once, {0, 0})
    imgui.begin("Window", nil, .NoResize |.NoTitleBar | .NoMove | .AlwaysAutoResize)

    frame_ms := time.duration_milliseconds(app.duration_frame)
    total_s  := time.duration_seconds(app.duration_total)

    imgui.text("Frame time: {} ms", frame_ms)
    imgui.text("Total time: {} s",  total_s)

    imgui.end()
}


update_game :: proc() {
    obj := &game.test_obj
    {using game.camera
        if get_key(.J) && fov < 89 do fov += 1
        if get_key(.K) && fov > 1  do fov -= 1
    }

    {using obj.transform
        if get_key(.A) {
            orientation = linalg.quaternion_mul_quaternion(auto_cast orientation, 
                auto_cast linalg.quaternion_from_euler_angle_y_f32(-.1))
        } 
        if get_key(.D) {
            orientation = linalg.quaternion_mul_quaternion(auto_cast orientation, 
                auto_cast linalg.quaternion_from_euler_angle_y_f32(.1))
        } 
    }
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
layout(location = 3) out mat4 _mat_local_to_world_direction;

// Matrixs
uniform mat4 matrix_view_projection;
uniform mat4 matrix_model;

void main()
{
    _mat_local_to_world_direction = transpose(inverse(matrix_model));
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
layout(location = 3) in mat4 _mat_local_to_world_direction;

uniform sampler2D main_texture;

uniform vec3 light_direction;
uniform vec4 light_color;// xyz: color, z: nor using

void main() {
    vec4 c = texture(main_texture, _uv);

    // FragColor = c * _color + vec4(_normal.x, _normal.y, _normal.z, 0) * 0.01;
    vec4 normal_vec4 = vec4(_normal.x, _normal.y, _normal.z, 1);
    normal_vec4 = _mat_local_to_world_direction * normal_vec4;
    vec3 world_normal = vec3(normal_vec4.x, normal_vec4.y, normal_vec4.z);

    float n_dot_l = dot(normalize(world_normal), light_direction);
    n_dot_l = n_dot_l * 2 + 1;

    FragColor = c * _color * n_dot_l * light_color;
    FragColor.a = 1.0;

    // FragColor = vec4(n_dot_l, n_dot_l, n_dot_l, 1);
}
	`
    game.basic_shader = load_shader(vertex_shader_src, fragment_shader_src)

    box_img := dgl.texture_load("./res/texture/box.png")
    dgl.image_free(&box_img)

    dgl.make_cube(&game.test_obj.mesh, game.basic_shader.native_id)
    game.test_obj.mesh.submeshes[0].texture = box_img.texture_id

    { using game.camera
        position = {0, 0, 3.5}
        fov  = 45
        near = .1
        far  = 300
        // orientation = cast(quaternion128)linalg.quaternion_from_forward_and_up(Vec3{0, 0, 1}, Vec3{0, 1, 0})
        forward = {0, 0, -1}
        scale = {1, 1, 1}
    }

    { using game.main_light
        color = {1, .8, .8, 1}
        direction = {0, -1, 0}
    }

    { using game.test_obj.transform
        scale = {1, 1, 1}
        orientation = cast(quaternion128)linalg.quaternion_from_euler_angles_f32(0, 0, 0, .XYZ)
    }

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
