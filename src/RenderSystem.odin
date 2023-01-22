package main

import "core:log"
import "core:strings"
import "core:slice"

import gl "vendor:OpenGL"

// import "dgl"
import "ecs"

@(private="file")
render_game_vao : u32

render_system_update :: proc(world: ^ecs.World) {
    camera : ^Camera = get_main_camera(world)
    light : ^Light = get_main_light(world)

    assert(camera != nil && light != nil, "Main camera and main light must exist.")

    if render_game_vao == 0 do gl.GenVertexArrays(1, &render_game_vao)
    gl.BindVertexArray(render_game_vao)

    { // Mesh renderer
        set_opengl_state_for_draw_geometry()
        meshes := cast([]MeshRenderer)ecs.get_components(world, MeshRenderer)
        render_objs := slice.mapper(meshes, mesh_renderer_to_render_object)
        defer delete(render_objs)
        render_env := RenderEnvironment{camera, light}
        draw_objects(render_objs, &render_env)
    }

    {// Sprite renderer (current immediately)
        // Currently draw sprite in screen space.
        sprites := ecs.get_components(world, SpriteRenderer)
        for sprite in sprites {
            using sprite
            leftup := pos - size * pivot
            immediate_texture(leftup, size, {1, 1, 1, 1}, texture_id)
        }
    }
}

@(private="file")
get_main_light :: proc(world: ^ecs.World) -> ^Light {
    lights := ecs.get_components(world, Light)
    if lights != nil && len(lights) > 0 do return &lights[0]
    return nil
}

@(private="file")
get_main_camera :: proc(world: ^ecs.World) -> ^Camera {
    cameras := ecs.get_components(world, Camera)
    if cameras != nil && len(cameras) > 0 do return &cameras[0]
    return nil
}

// Temporary
@(private="file")
mesh_renderer_to_render_object :: proc(mesh: MeshRenderer) -> RenderObject {
    robj : RenderObject
    robj.mesh = mesh.mesh
    robj.transform_matrix = mesh.transform_matrix
    return robj
}
