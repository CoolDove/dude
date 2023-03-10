package dude

import "core:os"
import "core:strings"
import "core:time"
import "core:math"
import "core:log"
import "core:math/rand"
import "core:math/linalg"

import gl "vendor:OpenGL"

import "dgl"
import "ecs"

set_opengl_state_for_draw_geometry :: proc() {
    gl.Enable(gl.DEPTH_TEST)
    gl.DepthFunc(gl.LEQUAL)
    // gl.DepthMask(true)

    gl.Disable(gl.BLEND)

    gl.Enable(gl.CULL_FACE)
    gl.CullFace(gl.BACK)
}

RenderObject :: struct {
    mesh : ^TriangleMesh,
    transform_matrix: linalg.Matrix4x4f32,
}

RenderEnvironment :: struct {
    camera : ^Camera,
    light  : ^Light,
}

draw_objects :: proc(objects: []RenderObject, env : ^RenderEnvironment) {
    cam := env.camera

    mat_view_projection := calc_camera_vp(env.camera)

    for obj in objects {
        using obj;

        if obj.mesh == nil do continue

        if mesh.submeshes == nil || len(&mesh.submeshes) == 0 {
            log.errorf("Mesh {} has no submesh.", strings.to_string(obj.mesh.name))
            continue
        }
        if mesh.pcnu == nil do mesh_create_pcnu(mesh)
        gl.BindBuffer(gl.ARRAY_BUFFER, mesh.pcnu.vbo)
        mat_model := transform_matrix
        default_tex_white := res_get_texture("texture/white.tex")
        for submesh in &mesh.submeshes {
            if submesh.ebo == 0 {
                log.errorf("Mesh {} is not uploaded.", strings.to_string(obj.mesh.name))
                break
            }
            gl.UseProgram(submesh.shader)
            dgl.set_vertex_format_PCNU(submesh.shader)
            uni_loc_matrix_view_projection := gl.GetUniformLocation(submesh.shader, "matrix_view_projection")
            uni_loc_matrix_model           := gl.GetUniformLocation(submesh.shader, "matrix_model")
            uni_loc_main_texture           := gl.GetUniformLocation(submesh.shader, "main_texture")
            uni_loc_light_direction        := gl.GetUniformLocation(submesh.shader, "light_direction")
            uni_loc_light_color            := gl.GetUniformLocation(submesh.shader, "light_color")

            gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, submesh.ebo)

            {using env.light
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
            else { gl.BindTexture(gl.TEXTURE_2D, default_tex_white.id) }
            gl.Uniform1i(uni_loc_main_texture, 0)

            gl.DrawElements(gl.TRIANGLES, cast(i32)len(submesh.triangles) * 3, gl.UNSIGNED_INT, nil)
        }
    }
}