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
    // test_obj   : GameObject,
    vao        : u32,
    
    // Temp
    ttf_test_texture_id : u32,
    ttf_x, ttf_y, ttf_z, ttf_d, ttf_heart : RuneTex,
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

    @static debug_texture := true
    imgui.checkbox("debug_texture", &debug_texture)
    img := &game.test_image
    if debug_texture {
        // img_gallery_x :f32= 0
        // size :f32= 512
        // immediate_texture({img_gallery_x, wnd_size.y - size}, {size, size}, {1, 1, 1, 1},
        //     game.ttf_test_texture_id)
        // img_gallery_x += size + 10
        // immediate_texture(
        //     {img_gallery_x, cast(f32)wnd_size.y - cast(f32)img.size.y},
        //     {auto_cast img.size.x, auto_cast img.size.y},
        //     {1, 1, 1, 1},
        //     img.texture_id
        // )
        // imgui.image(cast(imgui.Texture_ID)cast(uintptr)img.texture_id, {64, 64}, {1, 1}, {0, 0})
        // img_gallery_x += cast(f32)img.size.x + 10
    }

    {
        draw_rune :: proc(xoffset: ^f32, r: ^RuneTex, posy, scale: f32) {
            immediate_texture({xoffset^, posy}, {r.width * scale, r.height * scale}, {1, 1, 1, 1},
                r.id)
            xoffset^ += r.width * scale;
        }
        xoffset :f32= 0
        posy :f32= 100
        scale :f32= 3
        draw_rune(&xoffset, &game.ttf_z, posy, scale)
        draw_rune(&xoffset, &game.ttf_d, posy, scale)
        draw_rune(&xoffset, &game.ttf_heart, posy, scale)
        draw_rune(&xoffset, &game.ttf_y, posy, scale)
        draw_rune(&xoffset, &game.ttf_x, posy, scale)
        draw_rune(&xoffset, &game.ttf_y, posy, scale)
        // size :f32= 64
        // immediate_texture({xoffset, wnd_size.y - size}, {size, size}, {1, 1, 1, 1},
        //     game.ttf_y)
        // xoffset += size
        // immediate_texture({xoffset, wnd_size.y - size}, {size, size}, {1, 1, 1, 1},
        //     game.ttf_x)
        // xoffset += size
        // immediate_texture({xoffset, wnd_size.y - size}, {size, size}, {1, 1, 1, 1},
        //     game.ttf_y)
        // xoffset += size
        // immediate_quad({xoffset, wnd_size.y - size}, {size, size}, {1, 1, 1, 1})
        // xoffset += size
        // immediate_texture({xoffset, wnd_size.y - size}, {size, size}, {1, 1, 1, 1},
        //     game.ttf_z)
        // xoffset += size
        // immediate_texture({xoffset, wnd_size.y - size}, {size, size}, {1, 1, 1, 1},
        //     game.ttf_d)
        // xoffset += size
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
    recursive_make_render_objects(&game.scene, game.scene.assimp_scene.mRootNode, &objects)
    env := RenderEnvironment{&game.camera, &game.main_light}
    draw_objects(objects[:], &env)

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

    {// Load font(test)
        // game.ttf_test_texture_id = ttf_test()
        game.ttf_x = get_rune_texture('x', 0.1)
        game.ttf_y = get_rune_texture('y', 0.1)
        game.ttf_z = get_rune_texture('z', 0.1)
        game.ttf_d = get_rune_texture('d', 0.1)
        game.ttf_heart = get_rune_texture('♥', 0.1)
    }

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
    for key, mesh in &game.scene.meshes {
        log.debugf("Destroy Mesh: {}", strings.to_string(mesh.name))
        mesh_destroy(&mesh)
    }
    log.debug("QUIT GAME")
    assimp.release_import(game.scene.assimp_scene)
}