package main

import "core:time"
import "core:log"
import "core:fmt"
import "core:strings"
import "core:math/linalg"

import sdl "vendor:sdl2"
import gl "vendor:OpenGL"

when ODIN_DEBUG do import "pac:imgui"
import "pac:assimp"

import "dgl"

Game :: struct {
    using settings : ^GameSettings,
    window : ^Window,

    basic_shader : dgl.Shader,

    main_light : LightData,

    scene      : Scene,

    camera     : Camera,
    test_image : dgl.Image,

    immediate_draw_wireframe : bool,

    vao        : u32,
    
    // Temp
    font_unifont : ^DynamicFont,
    font_inkfree : ^DynamicFont,
    ttf_test_texture_id : u32,

    test_value : f32,
    tweened_color : Vec4,
}

GameSettings :: struct {
    status_window_alpha : f32
}

game : Game

GameObject :: struct {
    mesh      : TriangleMesh,
    transform : Transform,
}

draw_game :: proc() {
	using dgl

    wnd := game.window

	wnd_size := Vec2{cast(f32)wnd.size.x, cast(f32)wnd.size.y}
	immediate_quad(Vec2{wnd_size.x * 0.05, 0}, Vec2{wnd_size.x * 0.9, 20}, Vec4{ 1, 0, 0, 0.2 })
	immediate_quad(Vec2{40, 10}, Vec2{120, 20}, Vec4{ 0, 1, .4, 0.2 })
	immediate_quad(Vec2{10, 120}, Vec2{90, 20}, Vec4{ 1, 1, 1, 0.9 })

    immediate_text(game.font_inkfree, "The wind is passing through.", {100, 100}, {1, .6, .2, 1})
    immediate_text(game.font_unifont, "有欲望而无行动者滋生瘟疫。", {100, 500}, {.9, .2, .8, .5})
    immediate_text(game.font_unifont, "Press T to show the tweeeeeen。", {100, 350}, {.9, .2, .8, .5})

    if game.test_value > 0.0 {
        text := fmt.tprintf("Tweening: {}", game.test_value)
        pos :Vec2= {game.test_value * wnd_size.x, wnd_size.y * 0.5}
        immediate_text(game.font_inkfree, text, pos, game.tweened_color)
    }

    if game.settings.status_window_alpha > 0 do draw_status()

    gl.BindVertexArray(game.vao)
    set_opengl_state_for_draw_geometry()

    objects := make([dynamic]RenderObject, 0, game.scene.assimp_scene.mNumMeshes)
    defer delete(objects)
    recursive_make_render_objects(&game.scene, game.scene.assimp_scene.mRootNode, &objects)
    env := RenderEnvironment{&game.camera, &game.main_light}
    draw_objects(objects[:], &env)
}

when ODIN_DEBUG {
draw_game_imgui :: proc() {
    imgui.checkbox("immediate draw wireframe", &game.immediate_draw_wireframe)

    imgui.slider_float3("camera position", &game.camera.position, -100, 100)
    imgui.slider_float3("camera forward", &game.camera.forward, -1, 1)

    if imgui.collapsing_header("MainLight") {
        imgui.color_picker4("color", &game.main_light.color)
        imgui.slider_float3("direction", &game.main_light.direction, -1, 1)
        game.main_light.direction = linalg.normalize0(game.main_light.direction)
    }
}
}

@(private="file")
draw_status :: proc() {
    frame_ms := time.duration_milliseconds(app.duration_frame)
    framerate := cast(i32)(1000.0/frame_ms)
    color := Vec4{.1, 1, .1, 1}
    color.a *= game.settings.status_window_alpha

    immediate_text(game.font_unifont, fmt.tprintf("FPS: {}", framerate), {10, 32+10}, color)
    immediate_text(game.font_unifont, fmt.tprintf("Fullscreen: {}", game.window.fullscreen), 
        {10, 32+10+32+10}, color)
}

update_game :: proc() {
    {using game.camera
        if get_key(.J) && fov < 89 do fov += 1
        if get_key(.K) && fov > 1  do fov -= 1
        if get_mouse_button(.Right) {
            motion := get_mouse_motion()
            r := linalg.quaternion_from_euler_angles(- motion.y * 0.01, - motion.x * 0.01, 0, .XYZ)
            orientation = linalg.quaternion_mul_quaternion(orientation, r)
            forward = linalg.quaternion_mul_vector3(r, forward)
        }
    }
    {using game
        if get_key_down(.F1) {
            using game.settings
            if status_window_alpha == 0 do tween(&status_window_alpha, 1.0, 0.2)
            else if status_window_alpha == 1 do tween(&status_window_alpha, 0.0, 0.2)
        }
        if get_key_down(.F2) do immediate_draw_wireframe = !immediate_draw_wireframe
        if get_key_down(.F11) {
            switch window.fullscreen {
            case .Fullscreen:
                window->toggle_fullscreen(.Windowed)
            case .FullscreenDesktop:
                window->toggle_fullscreen(.Windowed)
            case .Windowed:
                window->toggle_fullscreen(.Fullscreen)
            }
        } 

        if get_key_down(.T) {
            game.test_value = 1.0
            tween(&game.test_value, 0, 0.8)->set_easing(easing_proc_outexpo)
            game.tweened_color = {1, 0, 0, 1}
            tween(&game.tweened_color, Vec4{0, 0, 1, 0}, 0.8)->set_on_complete(
                proc(d:rawptr){log.debugf("End")}, nil)
        } 
    }

    tween_update()
}

init_game :: proc() {
    using dgl

    game.settings = new(GameSettings)

    game.test_image = texture_load(DATA_IMG_ICON)
    image_free(&game.test_image)

    gl.GenVertexArrays(1, &game.vao)

	vertex_shader_src :: string(#load("../res/shader/basic_3d_vertex.glsl"))
	fragment_shader_src :: string(#load("../res/shader/basic_3d_fragment.glsl"))

    game.basic_shader = load_shader(vertex_shader_src, fragment_shader_src)

    box_img := texture_load(DATA_IMG_BOX)
    image_free(&box_img)

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
        direction = linalg.normalize(Vec3{-0.9, .3, 0}) 
    }

    {// Load Models
        mushroom := assimp.import_file(
            DATA_MOD_MUSHROOM_FBX,
            cast(u32) assimp.PostProcessPreset_MaxQuality,
            "fbx")
        game.scene.assimp_scene = mushroom
        prepare_scene(&game.scene, mushroom, game.basic_shader.native_id, draw_settings.default_texture_white)
        for i in 0..<mushroom.mNumMeshes {
            m := mushroom.mMeshes[i]
            mname := assimp.string_clone_from_ai_string(&m.mName, context.temp_allocator)
        }

        meshes := game.scene.meshes
        for aimesh, mesh in meshes {
            mname := assimp.string_clone_from_ai_string(&aimesh.mName, context.temp_allocator)
            log.debugf("Mesh {} loaded, vertices count: {}", mname, len(mesh.vertices))
        }
    }

    {// Dynamic font
        game.font_unifont = font_load(raw_data(DATA_UNIFONT_TTF), 32)
        game.font_inkfree = font_load(raw_data(DATA_INKFREE_TTF), 32)
    }

    tween_init()


}

@(private="file")
recursive_make_render_objects :: proc(scene: ^Scene, node: ^assimp.Node, target: ^[dynamic]RenderObject, ite:u32=0) {
    aiscene := scene.assimp_scene

    for i in 0..<node.mNumMeshes {
        robj : RenderObject
        mesh_ptr := aiscene.mMeshes[node.mMeshes[i]]
        mesh, ok := &scene.meshes[mesh_ptr]
        mesh_name := assimp.string_clone_from_ai_string(&mesh_ptr.mName, context.temp_allocator)
        assert(ok, fmt.tprintf("MakeRenderObjects: Cannot find mesh: {}", 
            mesh_name))
        robj.mesh = mesh
        robj.transform_matrix = assimp.matrix_convert(node.mTransformation)
        append(target, robj)
        indent : strings.Builder
        strings.builder_init(&indent)
        defer strings.builder_destroy(&indent)
        for i in 0..<ite do strings.write_rune(&indent, '\t')

        node_name := assimp.string_clone_from_ai_string(&node.mName, context.temp_allocator)
        // log.debugf("Prepare mesh {} for node {}", mesh_name, node_name)
    }

    for i in 0..<node.mNumChildren {
        child := node.mChildren[i]
        recursive_make_render_objects(scene, child, target, ite+1)
    }
}


@(private="file")
load_shader :: proc(vertex_source, frag_source : string)  -> dgl.Shader {
	shader_comp_vertex := dgl.shader_create_component(.VERTEX_SHADER, vertex_source)
	shader_comp_fragment := dgl.shader_create_component(.FRAGMENT_SHADER, frag_source)
	shader := dgl.shader_create(&shader_comp_vertex, &shader_comp_fragment)
	dgl.shader_destroy_components(&shader_comp_vertex, &shader_comp_fragment)
	return shader
}

quit_game :: proc() {
    tween_destroy()

    for key, mesh in &game.scene.meshes {
        log.debugf("Destroy Mesh: {}", strings.to_string(mesh.name))
        mesh_destroy(&mesh)
    }

    font_destroy(game.font_unifont)
    font_destroy(game.font_inkfree)

    log.debug("QUIT GAME")
    assimp.release_import(game.scene.assimp_scene)

    free(game.settings)

}