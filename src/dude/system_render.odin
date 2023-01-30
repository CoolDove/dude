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
        sprite_shader := res_get_shader("shader/builtin_sprite.shader").id
        {// Setup sprite rendering
            sprite_quad := get_sprite_quad()
            gl.BindBuffer(gl.ARRAY_BUFFER, sprite_quad.vbo)
            gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, sprite_quad.ebo)
            gl.UseProgram(sprite_shader)
            dgl.set_vertex_format_PCNU(sprite_shader)
            gl.Disable(gl.CULL_FACE)
        }
        uni_loc_matrix_view_projection := gl.GetUniformLocation(sprite_shader, "matrix_view_projection")
        uni_loc_matrix_model           := gl.GetUniformLocation(sprite_shader, "matrix_model")
        uni_loc_main_texture           := gl.GetUniformLocation(sprite_shader, "main_texture")

        mtx_view_projection := calc_camera_vp(camera)
        gl.UniformMatrix4fv(uni_loc_matrix_view_projection,
            1, false, linalg.matrix_to_ptr(&mtx_view_projection))

        default_white := res_get_texture("texture/white.tex")
        for i in sorted_indices {
            sprite := &sprites[i]
            transform := transforms[i]

            if !sprite.enable do continue
            if sprite.space == .World {
                mtx := calc_sprite_matrix(sprite)
                gl.UniformMatrix4fv(uni_loc_matrix_model, 
                    1, false, linalg.matrix_to_ptr(&mtx))

                gl.ActiveTexture(gl.TEXTURE0)
                if sprite.texture_id != 0 { gl.BindTexture(gl.TEXTURE_2D, sprite.texture_id) }
                else { gl.BindTexture(gl.TEXTURE_2D, default_white.id) }
                gl.Uniform1i(uni_loc_main_texture, 0)
                gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, nil)
            } else {
                log.warnf("RenderSystem: Ignore Screen space sprite for now.")
            }
        }
        gl.Enable(gl.CULL_FACE)
    }
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