package main

import "core:time"
import "core:log"
import "core:fmt"
import "core:strings"
import "core:math/linalg"

import sdl "vendor:sdl2"
import gl "vendor:OpenGL"

import "pac:imgui"
import "pac:assimp"

// import dsh "dshader"

// import "dshader"
import "dgl"

Game :: struct {
    window : ^Window,

    basic_shader : dgl.Shader,

    main_light : LightData,

    scene      : Scene,

    camera     : Camera,
    test_image : dgl.Image,
    test_obj   : GameObject,
    vao        : u32,
}

game : Game

GameObject :: struct {
    mesh      : TriangleMesh,
    transform : Transform
}

draw_game :: proc() {
    using linalg
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

    imgui.slider_float3("camera position", &game.camera.position, -100, 100)
    imgui.slider_float3("camera forward", &game.camera.forward, -1, 1)

    if imgui.collapsing_header("MainLight") {
        imgui.color_picker4("color", &game.main_light.color)
        imgui.slider_float3("direction", &game.main_light.direction, -1, 1)

        game.main_light.direction = linalg.normalize0(game.main_light.direction)
    }

    @static show_debug_framerate := true
    if get_key_down(.F1) do show_debug_framerate = !show_debug_framerate
    if show_debug_framerate do imgui_debug_framerate()

    gl.BindVertexArray(game.vao)
    set_opengl_state_for_draw_geometry()

    objects := make([dynamic]RenderObject, 0, game.scene.assimp_scene.mNumMeshes)
    defer delete(objects)
    make_render_objects(&game.scene, game.scene.assimp_scene.mRootNode, &objects)
    env := RenderEnvironment{&game.camera, &game.main_light}
    draw_objects(objects[:], &env)

    // draw_mesh(&game.test_obj.mesh, &game.test_obj.transform, &game.camera, &game.main_light)

    // copy_transform := game.test_obj.transform
    // copy_transform.position += {1, 0, 0}

    // draw_mesh(&game.test_obj.mesh, &copy_transform, &game.camera, &game.main_light)

    // scene := game.scene
    // assimp_scene := scene.assimp_scene
    // node := assimp_scene.mRootNode
    // children_count := node.mNumChildren
    
    // for i in 0..<assimp_scene.mNumMeshes {
    //     assimp_mesh_ptr := assimp_scene.mMeshes[i]
    //     mesh := scene.meshes[assimp_mesh_ptr]
    //     draw_mesh(&mesh, &game.test_obj.transform, &game.camera, &game.main_light)
    // }
    
}

@(private="file")
imgui_debug_framerate :: proc() {
    imgui.set_next_window_bg_alpha(.4)
    imgui.set_next_window_pos({10, 10}, .Once, {0, 0})
    imgui.begin("Framerate", nil, .NoTitleBar |
                                  .NoDecoration | 
                                  .AlwaysAutoResize | 
                                  .NoSavedSettings | 
                                  .NoFocusOnAppearing | 
                                  .NoNav | 
                                  .NoMove)

    frame_ms := time.duration_milliseconds(app.duration_frame)
    total_s  := time.duration_seconds(app.duration_total)

    imgui.text_unformatted("Framerate debug window,\nPress F1 to toggle.\n\n")

    imgui.text("Frame time: {} ms", frame_ms)
    imgui.text("Total time: {} s",  total_s)

    imgui.end()
}

update_game :: proc() {
    obj := &game.test_obj
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

    {using obj.transform
        if get_key(.A) {
            orientation = linalg.quaternion_mul_quaternion(orientation, 
                linalg.quaternion_from_euler_angle_y_f32(-.1))
        } 
        if get_key(.D) {
            orientation = linalg.quaternion_mul_quaternion(orientation, 
                linalg.quaternion_from_euler_angle_y_f32(.1))
        } 
    }
}

init_game :: proc() {
    using dgl
    game.test_image = texture_load(DATA_IMG_ICON)
    image_free(&game.test_image)

    gl.GenVertexArrays(1, &game.vao)

	vertex_shader_src :: string(#load("../res/shader/basic_3d_vertex.glsl"))
	fragment_shader_src :: string(#load("../res/shader/basic_3d_fragment.glsl"))

    game.basic_shader = load_shader(vertex_shader_src, fragment_shader_src)

    box_img := texture_load(DATA_IMG_BOX)
    image_free(&box_img)

    mesh_make_cube(&game.test_obj.mesh, game.basic_shader.native_id)
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
        orientation = linalg.quaternion_from_euler_angles_f32(0, 0, 0, .XYZ)
    }

    {// @Test: Uniform location test.
        // log.debugf("matrix_view_projection: {}", dshader.get_uniform_location("matrix_view_projection"))
        // log.debugf("matrix_model: {}",           dshader.get_uniform_location("matrix_model"))
        // log.debugf("matrix_model_direction: {}", dshader.get_uniform_location("matrix_model_direction"))
    }

    {// Load Models
        mushroom := assimp.import_file(
            DATA_MOD_MUSHROOM_FBX,
            cast(u32) assimp.PostProcessPreset_MaxQuality,
            "fbx")
        log.debugf("Load Scene: {}", assimp.string_clone_from_ai_string(&mushroom.mName, context.temp_allocator))
        game.scene.assimp_scene = mushroom
        prepare_scene(&game.scene, mushroom, game.basic_shader.native_id, draw_settings.default_texture_white)
        for i in 0..<mushroom.mNumMeshes {
            m := mushroom.mMeshes[i]
            mname := assimp.string_clone_from_ai_string(&m.mName, context.temp_allocator)
            log.debugf("mesh {}", mname)
        }

        meshes := game.scene.meshes
        for aimesh, mesh in meshes {
            mname := assimp.string_clone_from_ai_string(&aimesh.mName, context.temp_allocator)
            log.debugf("Mesh {}, vertices count: {}", mname, len(mesh.vertices))
        }
    }
}

@(private="file")
make_render_objects :: proc(scene: ^Scene, node: ^assimp.Node, target: ^[dynamic]RenderObject, ite:u32=0) {
    aiscene := scene.assimp_scene

    // log.debugf("On Node: {}, children count: {}, children: {}, meshes count: {}, meta data: {}", 
    //     assimp.string_clone_from_ai_string(&node.mName, context.temp_allocator),
    //     node.mNumChildren, node.mChildren, node.mNumMeshes, node.mMetaData
    // )
    
    // transform_matrix := linalg.matrix_mul(parent_matrix, node.mTransformation)
    for i in 0..<node.mNumMeshes {
        robj : RenderObject
        mesh_id := node.mMeshes[i]
        mesh_ptr := aiscene.mMeshes[mesh_id]
        mesh_name := assimp.string_clone_from_ai_string(&mesh_ptr.mName, context.temp_allocator)
        mesh, ok := &scene.meshes[mesh_ptr]
        assert(ok, fmt.tprintf("MakeRenderObjects: Cannot find mesh: {}", mesh_name))
        robj.mesh = mesh
        robj.transform_matrix = node.mTransformation
        append(target, robj)
        indent : strings.Builder
        strings.builder_init(&indent)
        defer strings.builder_destroy(&indent)
        for i in 0..<ite do strings.write_rune(&indent, '\t')
    }

    for i in 0..<node.mNumChildren {
        child := node.mChildren[i]
        make_render_objects(scene, child, target, ite+1)
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
    mesh_release_rendering_resource(&game.test_obj.mesh)
    gl.DeleteTextures(1, &game.test_image.texture_id)
    assimp.release_import(game.scene.assimp_scene)
    // mesh_release()
}