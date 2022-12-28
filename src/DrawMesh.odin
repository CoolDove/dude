package main

import "core:os"
import "core:strings"
import "core:time"
import "core:math"
import "core:log"
import "core:math/rand"
import "core:math/linalg"

import gl "vendor:OpenGL"

import "dgl"

DrawSettings :: struct {
    screen_width, screen_height : f32,
    default_texture_white, default_texture_black : u32
}

draw_settings : DrawSettings

init :: proc() {
    draw_settings.default_texture_white = dgl.texture_create(4, 4, [4]u8{0xff, 0xff, 0xff, 0xff})
    draw_settings.default_texture_black = dgl.texture_create(4, 4, [4]u8{0x00, 0x00, 0x00, 0xff})
}

set_opengl_state_for_draw_geometry :: proc() {
    gl.Enable(gl.DEPTH_TEST)
    gl.DepthFunc(gl.LEQUAL)
    // gl.DepthMask(true)

    gl.Disable(gl.BLEND)

    gl.Enable(gl.CULL_FACE)
    gl.CullFace(gl.BACK)
}

// @Speed
// FIXME: The lighting is incorrect.
// TODO: Use precalculated normal matrix instead of calculate in vertex shader.
// TODO: Use uniform block.
// TODO: Hash-based uniform location management.
// TODO: Buffer only once!!!
draw_mesh :: proc(mesh: ^TriangleMesh, transform: ^Transform, camera : ^Camera, light: ^LightData) {
    assert(mesh.submeshes != nil, "Mesh has no submesh")
    using dgl

    if !mesh_is_ready_for_rendering(mesh) do mesh_prepare_for_rendering(mesh)

    mat_view_projection := camera_get_matrix_vp(camera, draw_settings.screen_width/draw_settings.screen_height)
    mat_model := matrix_srt(transform.scale, transform.orientation, transform.position)

    gl.BindBuffer(gl.ARRAY_BUFFER, mesh.vbo)

    for submesh in mesh.submeshes {
        gl.UseProgram(submesh.shader)
        set_vertex_format_PCNU(submesh.shader)
        uni_loc_matrix_view_projection := gl.GetUniformLocation(submesh.shader, "matrix_view_projection")
        uni_loc_matrix_model           := gl.GetUniformLocation(submesh.shader, "matrix_model")
        uni_loc_main_texture           := gl.GetUniformLocation(submesh.shader, "main_texture")
        uni_loc_light_direction        := gl.GetUniformLocation(submesh.shader, "light_direction")
        uni_loc_light_color            := gl.GetUniformLocation(submesh.shader, "light_color")

        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, submesh.ebo)

        { using light
            gl.Uniform4f(uni_loc_light_color, color.x, color.y, color.z, color.w)
            gl.Uniform3f(uni_loc_light_direction, direction.x, direction.y, direction.z)
        }
        
        gl.UniformMatrix4fv(uni_loc_matrix_view_projection, 
            1, false, linalg.matrix_to_ptr(&mat_view_projection))
        gl.UniformMatrix4fv(uni_loc_matrix_model, 
            1, false, linalg.matrix_to_ptr(&mat_model))

        // Set texture.
        gl.ActiveTexture(gl.TEXTURE0)
        if submesh.texture != 0 { gl.BindTexture(gl.TEXTURE_2D, submesh.texture) }
        else { gl.BindTexture(gl.TEXTURE_2D, draw_settings.default_texture_white) }
        gl.Uniform1i(uni_loc_main_texture, 0)

        gl.DrawElements(gl.TRIANGLES, cast(i32)len(submesh.triangles) * 3, gl.UNSIGNED_INT, nil)

    }
}