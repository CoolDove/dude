package dgl

import "core:os"
import "core:strings"
import "core:time"
import "core:math"
import "core:log"
import "core:math/rand"
import "core:math/linalg"

import gl "vendor:OpenGL"

DrawSettings :: struct {
    screen_width, screen_height : f32,
    default_texture_white, default_texture_black : u32
}

draw_settings : DrawSettings

init :: proc() {
    draw_settings.default_texture_white = texture_create(4, 4, [4]u8{0xff, 0xff, 0xff, 0xff})
    draw_settings.default_texture_black = texture_create(4, 4, [4]u8{0x00, 0x00, 0x00, 0xff})
}

TriangleMesh :: struct {
    vertices   : [dynamic]Vec3,
    colors     : [dynamic]Vec4,

    uvs        : [dynamic]Vec2,

    normals    : [dynamic]Vec3,
    tangents   : [dynamic]Vec3,
    bitangents : [dynamic]Vec3,

    submeshes  : [dynamic]SubMesh,

    mesh_pcnu  : MeshPCNU,
}

SubMesh :: struct {
    triangles : [dynamic][3]u32,
    shader    : u32,
    texture    : u32, // Maybe put into material later.
}

make_cube :: proc(using mesh: ^TriangleMesh, shader: u32) {
    vertices  = make([dynamic]Vec3, 0, 6 * 4)
    uvs       = make([dynamic]Vec2, 0, 6 * 4)
    colors    = make([dynamic]Vec4, 0, 6 * 4)
    submeshes = make([dynamic]SubMesh)

    {// position
        a := Vec3{-1,  1, -1}
        b := Vec3{ 1,  1, -1}
        c := Vec3{-1,  1,  1}
        d := Vec3{ 1,  1,  1}
        e := Vec3{-1, -1, -1}
        f := Vec3{ 1, -1, -1}
        g := Vec3{-1, -1,  1}
        h := Vec3{ 1, -1,  1}
        append(&vertices, 
            a, b, c, d,
            c, d, g, h,
            d, b, h, f,
            b, a, f, e,
            a, c, e, g,
            g, h, e, f)
    }

    for v in &mesh.vertices do v *= 0.5

    {// uvs
        a := Vec2{0, 1}
        b := Vec2{1, 1}
        c := Vec2{0, 0}
        d := Vec2{1, 0}
        append(&uvs, 
            a, b, c, d,
            a, b, c, d, 
            a, b, c, d, 
            a, b, c, d, 
            a, b, c, d, 
            c, d, a, b)
    }

    for i in 0..<(6 * 4) do append(&colors, Vec4{1, 1, 1, 1})

    append_normal :: proc(normals: ^[dynamic]Vec3, normal: Vec3, count: u32) {
        for i in 0..<count do append(normals, normal)
    }

    // for i in 0..<(6 * 4) do append(&normals, Vec3{0, 0, 1})
    append_normal(&normals, { 0,  1,  0}, 4)
    append_normal(&normals, { 0,  0, -1}, 4)
    append_normal(&normals, { 1,  0,  0}, 4)
    append_normal(&normals, { 0,  0,  1}, 4)
    append_normal(&normals, {-1,  0,  0}, 4)
    append_normal(&normals, { 0, -1,  0}, 4)

    indices := make([dynamic][3]u32, 0, 6 * 2)

    // FIXME(Dove): Incorrect indices.
    for i in 0..<6 {
        base :u32= cast(u32) i * 4
        append(&indices, 
            [3]u32{base, base + 2, base + 1}, 
            [3]u32{base + 1, base + 2, base + 3})
    }

    triangle_list : SubMesh
    triangle_list.triangles = indices
    triangle_list.shader = shader

    append(&submeshes, triangle_list)

    pncu := mesh_make_pcnu(mesh)
    mesh.mesh_pcnu = pncu
}

mesh_make_pcnu :: proc(mesh: ^TriangleMesh) -> MeshPCNU {
    m : MeshPCNU
    length := len(mesh.vertices)
    m.vertices = make([dynamic]VertexPCNU, 0, length)
    for i in 0..<length {
        vertex : VertexPCNU
        vertex.position = mesh.vertices[i]
        vertex.color    = mesh.colors[i]
        vertex.normal   = mesh.normals[i]
        vertex.uv       = mesh.uvs[i]
        append(&m.vertices, vertex)
    }
    return m
}

MeshPCNU :: struct {
    vertices : [dynamic]VertexPCNU
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
draw_mesh :: proc(mesh: ^TriangleMesh, transform: ^Transform, camera : ^Camera, light: ^LightData) {
    // Maybe i need to set VAO before this.
    assert(mesh.submeshes != nil, "Mesh has no submesh")
    mat_view_projection := camera_get_matrix_vp(camera, draw_settings.screen_width/draw_settings.screen_height)
    mat_model := matrix_srt(transform.scale, transform.orientation, transform.position)

    vbo : u32
    gl.GenBuffers(1, &vbo)
    gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
    defer gl.DeleteBuffers(1, &vbo)

    data_size := len(mesh.vertices) * size_of(VertexPCNU)
    gl.BufferData(gl.ARRAY_BUFFER, data_size, raw_data(mesh.mesh_pcnu.vertices), gl.STREAM_DRAW)

    for sub_mesh in mesh.submeshes {
        gl.UseProgram(sub_mesh.shader)
        set_vertex_format_PCNU(sub_mesh.shader)
        uni_loc_matrix_view_projection := gl.GetUniformLocation(sub_mesh.shader, "matrix_view_projection")
        uni_loc_matrix_model           := gl.GetUniformLocation(sub_mesh.shader, "matrix_model")
        uni_loc_main_texture           := gl.GetUniformLocation(sub_mesh.shader, "main_texture")
        uni_loc_light_direction        := gl.GetUniformLocation(sub_mesh.shader, "light_direction")
        uni_loc_light_color            := gl.GetUniformLocation(sub_mesh.shader, "light_color")

        { using light
            gl.Uniform4f(uni_loc_light_color, color.x, color.y, color.z, color.w)
            gl.Uniform3f(uni_loc_light_direction, direction.x, direction.y, direction.z)
        }
        
        gl.UniformMatrix4fv(uni_loc_matrix_view_projection, 
            1, false, linalg.matrix_to_ptr(&mat_view_projection))
        gl.UniformMatrix4fv(uni_loc_matrix_model, 
            1, false, linalg.matrix_to_ptr(&mat_model))

        ebo : u32
        gl.GenBuffers(1, &ebo)
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo)
        defer gl.DeleteBuffers(1, &ebo)

        // Set texture.
        gl.ActiveTexture(gl.TEXTURE0)
        if sub_mesh.texture != 0 { gl.BindTexture(gl.TEXTURE_2D, sub_mesh.texture) }
        else { gl.BindTexture(gl.TEXTURE_2D, draw_settings.default_texture_white) }
        gl.Uniform1i(uni_loc_main_texture, 0)

        element_buffer_count := len(sub_mesh.triangles) * 3
        element_buffer_size := element_buffer_count * size_of(u32)
        gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, element_buffer_size, raw_data(sub_mesh.triangles), gl.STREAM_DRAW)

        gl.DrawElements(gl.TRIANGLES, cast(i32)element_buffer_count, gl.UNSIGNED_INT, nil)

    }
}