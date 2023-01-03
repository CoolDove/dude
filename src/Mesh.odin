package main

import gl "vendor:OpenGL"
import "core:math/linalg"
import "core:log"

TriangleMesh :: struct {
    vertices   : [dynamic]Vec3,
    colors     : [dynamic]Vec4,

    uvs        : [dynamic]Vec2,

    normals    : [dynamic]Vec3,
    tangents   : [dynamic]Vec3,
    bitangents : [dynamic]Vec3,

    submeshes  : [dynamic]SubMesh,

    mesh_pcnu  : MeshPCNU,

    // OpenGL
    vbo        : u32,

}

TriangleIndices :: [3]u32

SubMesh :: struct {
    triangles : [dynamic]TriangleIndices,

    // OpenGL
    ebo       : u32,
    shader    : u32,
    texture    : u32, // Maybe put into material later.
}

mesh_make_cube :: proc(using mesh: ^TriangleMesh, shader: u32) {
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
    append_normal(&normals, { 0, -1,  0}, 4)
    append_normal(&normals, { 0,  0,  1}, 4)
    append_normal(&normals, { 1,  0,  0}, 4)
    append_normal(&normals, { 0,  0, -1}, 4)
    append_normal(&normals, {-1,  0,  0}, 4)
    append_normal(&normals, { 0,  1,  0}, 4)

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

    // pncu := mesh_make_pcnu(mesh)
    // mesh.mesh_pcnu = pncu
}


mesh_is_ready_for_rendering :: proc(using mesh: ^TriangleMesh) -> bool {
    return vbo != 0
}
mesh_prepare_for_rendering :: proc(mesh: ^TriangleMesh) {
    {// Make mesh_pcnu
        using mesh.mesh_pcnu
        length := len(mesh.vertices)
        vertices = make([dynamic]VertexPCNU, 0, length)
        for i in 0..<length {
            vertex : VertexPCNU
            vertex.position = mesh.vertices[i]
            vertex.color    = mesh.colors[i]
            vertex.normal   = mesh.normals[i]
            vertex.uv       = mesh.uvs[i]
            append(&vertices, vertex)
        }
    }

    gl.GenBuffers(1, &mesh.vbo)
    gl.BindBuffer(gl.ARRAY_BUFFER, mesh.vbo)
    data_size := len(mesh.vertices) * size_of(VertexPCNU)
    gl.BufferData(gl.ARRAY_BUFFER, data_size, raw_data(mesh.mesh_pcnu.vertices), gl.STREAM_DRAW)

    for submesh in &mesh.submeshes {
        count := len(submesh.triangles)
        gl.GenBuffers(1, &submesh.ebo)
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, submesh.ebo)
        gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, count * size_of(TriangleIndices), raw_data(submesh.triangles), gl.STREAM_DRAW)
    }
}

mesh_release_rendering_resource :: proc(mesh: ^TriangleMesh) {
    if !mesh_is_ready_for_rendering(mesh) do return;
    gl.DeleteBuffers(1, &mesh.vbo)
    for submesh in &mesh.submeshes do gl.DeleteBuffers(1, &submesh.ebo)
}

MeshPCNU :: struct {
    vertices : [dynamic]VertexPCNU
}
