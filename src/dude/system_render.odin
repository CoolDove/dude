package dude

import "core:log"
import "core:strings"
import "core:slice"
import "core:fmt"
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

    camera_matrix := calc_camera_vp(camera)
    { // Mesh renderer
        set_opengl_state_for_draw_geometry()
        meshes := cast([]MeshRenderer)ecs.get_components(world, MeshRenderer)
        render_objs := slice.mapper(meshes, mesh_renderer_to_render_object)
        defer delete(render_objs)
        render_env := RenderEnvironment{camera, light}
        draw_objects(render_objs, &render_env)
    }

    render_sprites(world, &camera_matrix)

}


@(private="file")
render_sprites :: #force_inline proc(world: ^ecs.World, camera_matrix : ^linalg.Matrix4x4f32) {
    // Currently draw sprite in screen space.
    // TODO: Setup OpenGL render states.
    sprites := ecs.get_components(world, SpriteRenderer)
    transforms := make([dynamic]Transform, 0, len(sprites))
    defer delete(transforms)
    sprite_count := len(sprites)

    world_sprites, screen_sprites := sprite_split(sprites)

    sprite_shader := res_get_shader("shader/builtin_sprite.shader").id
    // Setup sprite rendering
    sprite_quad := get_sprite_quad()
    gl.BindBuffer(gl.ARRAY_BUFFER, sprite_quad.vbo)
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, sprite_quad.ebo)
    gl.UseProgram(sprite_shader)
    dgl.set_vertex_format_PCNU(sprite_shader)
    gl.Disable(gl.CULL_FACE)
    uni_loc_matrix_view_projection := gl.GetUniformLocation(sprite_shader, "matrix_view_projection")
    uni_loc_matrix_model           := gl.GetUniformLocation(sprite_shader, "matrix_model")
    uni_loc_main_texture           := gl.GetUniformLocation(sprite_shader, "main_texture")

    gl.UniformMatrix4fv(uni_loc_matrix_view_projection,
        1, false, linalg.matrix_to_ptr(camera_matrix))
    default_white := res_get_texture("texture/white.tex")

    when DUDE_EDITOR {
        immediate_text(builtin_res.default_font, 
            fmt.tprintf("world: {}", len(world_sprites)), 
            {0, 32}, COLORS.RED)
        immediate_text(builtin_res.default_font, 
            fmt.tprintf("screen: {}", len(screen_sprites)), 
            {0, 100}, COLORS.RED)
    }

    for sp in &world_sprites {// Render world space.
        if !sp.enable do continue
        assert(sp.space == .World, "SpriteRender: Incorrect sprite splitting.")
        mtx := calc_sprite_matrix(&sp)
        gl.UniformMatrix4fv(uni_loc_matrix_model, 
            1, false, linalg.matrix_to_ptr(&mtx))
        gl.ActiveTexture(gl.TEXTURE0)
        if sp.texture_id != 0 { gl.BindTexture(gl.TEXTURE_2D, sp.texture_id) }
        else { gl.BindTexture(gl.TEXTURE_2D, default_white.id) }
        gl.Uniform1i(uni_loc_main_texture, 0)
        gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, nil)
    }
    for sp in &screen_sprites {// Render screen space.
        // TODO
        // log.debugf("Rendering a screen space sprite.")
    }

    
    gl.Enable(gl.CULL_FACE)

}

@(private="file")
sprite_split :: #force_inline proc(sprites: []SpriteRenderer) -> (world, screen: []SpriteRenderer) {
    // [World...Screen]
    length := len(sprites)
    render_sprites := slice.clone(sprites, allocators.frame)
    lptr, rptr := 0, length - 1
    for sp, ind in sprites {
        if sp.space == .World {
            render_sprites[lptr] = sp
            lptr += 1
        } else {
            render_sprites[rptr] = sp
            if ind < length - 1 do rptr -= 1
        }
    }
    return render_sprites[0:lptr], render_sprites[lptr:length]
}


// Temporary
@(private="file")
mesh_renderer_to_render_object :: #force_inline proc(mesh: MeshRenderer) -> RenderObject {
    robj : RenderObject
    robj.mesh = mesh.mesh
    transform := ecs.get_component(mesh.component, Transform)
    if transform != nil {
        robj.transform_matrix = dgl.matrix_srt(transform.scale, transform.orientation, transform.position)
    }
    return robj
}