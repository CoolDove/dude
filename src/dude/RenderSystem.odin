package dude

import "core:log"
import "core:strings"
import "core:slice"
import "core:slice/heap"
import "core:math/linalg"

import gl "vendor:OpenGL"

import "dgl"
import "ecs"

@(private="file")
render_game_vao : u32

// Currently pickup the first camera as the main camera.
render_world :: proc(world: ^ecs.World) {
    camera : ^Camera = get_main_camera(world)
    light : ^Light = get_main_light(world)

    if camera == nil || light == nil do return;

    camera_transform := ecs.get_component(world, camera.entity, Transform)

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
        // TODO: Setup OpenGL render states.
        sprites := ecs.get_components(world, SpriteRenderer)
        transforms := make([dynamic]Transform, 0, len(sprites))
        defer delete(transforms)
        for sp in sprites {
            transform := ecs.get_component(world, sp.entity, Transform)
            append(&transforms, 
                transform^ if transform != nil else 
                Transform{orientation=linalg.quaternion_from_euler_angles(cast(f32)0,0,0, .XYZ)})
        }
        sorted_indices := slice.sort_by_with_indices(transforms[:],
            proc(i,j:Transform)->bool{return i.position.z<j.position.z},
        )

        // TODO: handle rotation
        for i in sorted_indices {
            sprite := sprites[i]
            transform := transforms[i]
            using sprite
            if !enable do continue
            leftup := Vec2{transform.position.x, transform.position.y} - size * pivot
            immediate_texture(leftup, size, sprite.color, texture_id)

            // TODO: Sprite Rendering.
            // render_sprite(&sprite, env)

            // {// Render the sprite.
            //     for v in &default_sprite_quad.vertices {
            //         v.color = sprite.color// update the color
            //     }
            //     render_mesh_upload(default_sprite_quad)
            //     default_sprite_quad.vbo
            // }
        }
    }
}

@(private="file")
default_sprite_quad : ^RenderMesh(VertexPCNU)
/*
  a------b
  |      |
  |      |
  c------d
  a: (-1, 1) (0, 1)
  b: (1, 1) (1, 1)
  c: (-1, -1) (0, 0)
  d: (1, -1) (1, 0)
*/
@(private="file")
init_default_sprite_quad :: proc() -> ^RenderMesh(VertexPCNU) {
    rmesh := new(RenderMesh(VertexPCNU))
    a := VertexPCNU{ position = {-1, -1, 0}, uv = {0, 0}, }
    b := VertexPCNU{ position = {1, 1, 0}, uv = {1, 1}, }
    c := VertexPCNU{ position = {-1, -1, 0}, uv = {0, 0}, }
    d := VertexPCNU{ position = {1, -1, 0}, uv = {1, 0}, }
    append(&rmesh.vertices, a, b, c, d)
    indices := [6]u32{0, 2, 1, 1, 2, 3}
    render_mesh_upload(rmesh, indices[:])
    return rmesh
}

@(private="file")
calc_sprite_matrix :: proc(sprite: ^SpriteRenderer) -> linalg.Matrix4x4f32 {
    return linalg.MATRIX4F32_IDENTITY
}

render_sprite :: proc(sprite: ^SpriteRenderer, env: ^RenderEnvironment) {

}


// Temporary
@(private="file")
mesh_renderer_to_render_object :: proc(mesh: MeshRenderer) -> RenderObject {
    robj : RenderObject
    robj.mesh = mesh.mesh
    transform := ecs.get_component(mesh.component, Transform)
    if transform != nil {
        robj.transform_matrix = dgl.matrix_srt(transform.scale, transform.orientation, transform.position)
    }
    return robj
}