package main

import "core:time"
import "core:log"
import "core:fmt"
import "core:strings"
import "core:math"
import "core:math/linalg"

import sdl "vendor:sdl2"
import gl "vendor:OpenGL"

when ODIN_DEBUG do import "pac:imgui"
import "pac:assimp"

import "dgl"
import "ecs"

Game :: struct {
    using settings : ^GameSettings,
    window : ^Window,

    main_world : ^ecs.World,

    basic_shader : dgl.Shader,

    // main_light : LightData,

    scene      : Scene,

    // camera     : Camera,
    // test_image : dgl.Image,

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
    status_window_alpha : f32,
}

game : Game

GameObject :: struct {
    mesh      : TriangleMesh,
    transform : Transform,
}

draw_game :: proc() {
	using dgl
    wnd := game.window

    immediate_text(game.font_unifont, "有欲望而无行动者滋生瘟疫。", {100, 500}, {.9, .2, .8, .5})

    if game.settings.status_window_alpha > 0 do draw_status()

}

when ODIN_DEBUG {
draw_game_imgui :: proc() {
    imgui.checkbox("immediate draw wireframe", &game.immediate_draw_wireframe)

    for t, ind in &tweens {
        text := fmt.tprintf("{}: {}", ind, "working" if !t.done else "done.")
        imgui.selectable(text, !t.done)
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
    ecs.world_update(game.main_world)
    tween_update()
}

init_game :: proc() {
    using dgl

    game.settings = new(GameSettings)

    // game.test_image = texture_load(DATA_IMG_ICON)
    // image_free(&game.test_image)

    gl.GenVertexArrays(1, &game.vao)

	vertex_shader_src :: string(#load("../res/shader/basic_3d_vertex.glsl"))
	fragment_shader_src :: string(#load("../res/shader/basic_3d_fragment.glsl"))

    game.basic_shader = load_shader(vertex_shader_src, fragment_shader_src)

    // box_img := texture_load(DATA_IMG_BOX)
    // image_free(&box_img)

    {// Load Models
        mushroom := assimp.import_file(
            DATA_MOD_MUSHROOM_FBX,
            cast(u32) assimp.PostProcessPreset_MaxQuality,
            "fbx")
        game.scene.assimp_scene = mushroom
        // TODO: This is not a `scene`, a fbx should be loaded as a MeshFile or ...
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

    {// Res test
        res_load_texture("texture/box.png")
    }

    {// Init the world
        using game
        using ecs
        main_world = ecs.world_create()
        world := main_world
        ecs.add_system(main_world, render_system_update)

        {// Add the camera and light.
            log.debugf("Create Camera and Light")
            {// main camera
                camera := add_entity(world)
                cam := add_component(world, camera, Camera)
                {using cam
                    position = {0, 0, 3.5}
                    fov  = 45
                    near = .1
                    far  = 300
                    orientation = linalg.quaternion_from_forward_and_up(Vec3{0, 0, 1}, Vec3{0, 1, 0})
                }
                add_component(world, camera, DebugInfo{"MainCamera"})
            }
            {// main light
                light := add_entity(world)
                l : Light
                {using l
                    color = {1, .8, .8, 1}
                    direction = linalg.normalize(Vec3{-0.9, .3, 0}) 
                }
                add_component(world, light, l)
                add_component(world, light, DebugInfo{"MainLight"})
            }
            log.debugf("Camera and Light created ")
        }
        {// Add MeshRenderers.
            recursive_add_mesh_renderer(world, &game.scene, game.scene.assimp_scene.mRootNode)
            log.debugf("MeshRenderers created")
        }
        {// Add test SpriteRenderer.
            dove := ecs.add_entity(main_world)
            sprite := ecs.add_component(main_world, dove, SpriteRenderer)
            sprite.texture_id = res_get_texture("texture/box.png").texture_id
            sprite.size = {64, 64}
            sprite.pos = {0, 0}
            sprite.pivot = {0.0, 0.0}
        }
    }

}

@(private="file")
recursive_add_mesh_renderer :: proc(world: ^ecs.World, scene: ^Scene, node: ^assimp.Node, ite:u32=0) {
    aiscene := scene.assimp_scene

    for i in 0..<node.mNumMeshes {
        mesh_ptr := aiscene.mMeshes[node.mMeshes[i]]
        mesh := &scene.meshes[mesh_ptr]
        if !(mesh_ptr in scene.meshes) {
            mesh_name := assimp.string_clone_from_ai_string(&mesh_ptr.mName, context.temp_allocator)
            log.errorf("MakeRenderObjects: Cannot find mesh: {}", mesh_name)
            return
        }

        ent := ecs.add_entity(world)
        ecs.add_component(world, ent, DebugInfo{})
        // mesh_renderer := ecs.add_component(world, ent, MeshRenderer)
        ecs.add_component(world, ent, 
            DebugInfo{fmt.tprintf("MeshRenderer: {}", strings.to_string(mesh.name))})
    }

    for i in 0..<node.mNumChildren {
        child := node.mChildren[i]
        recursive_add_mesh_renderer(world, scene, child, ite+1)
    }
}

@(private="file")// dead
recursive_make_render_objects :: proc(scene: ^Scene, node: ^assimp.Node, target: ^[dynamic]RenderObject, ite:u32=0) {
    aiscene := scene.assimp_scene

    for i in 0..<node.mNumMeshes {
        robj : RenderObject
        mesh_ptr := aiscene.mMeshes[node.mMeshes[i]]
        mesh, ok := &scene.meshes[mesh_ptr]
        if !ok {
            mesh_name := assimp.string_clone_from_ai_string(&mesh_ptr.mName, context.temp_allocator)
            log.errorf("MakeRenderObjects: Cannot find mesh: {}", mesh_name)
            return
        }
        robj.mesh = mesh
        robj.transform_matrix = assimp.matrix_convert(node.mTransformation)
        append(target, robj)

        node_name := assimp.string_clone_from_ai_string(&node.mName, context.temp_allocator)
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
    ecs.world_destroy(game.main_world)
    
    tween_destroy()

    for key, mesh in &game.scene.meshes {
        log.debugf("Destroy Mesh: {}", strings.to_string(mesh.name))
        mesh_destroy(&mesh)
    }
    assimp.release_import(game.scene.assimp_scene)
    delete(game.scene.meshes)

    font_destroy(game.font_unifont)
    font_destroy(game.font_inkfree)

    log.debug("QUIT GAME")

    free(game.settings)

}