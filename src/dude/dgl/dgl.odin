package dgl

import gl "vendor:OpenGL"

import "core:log"
import "core:math/linalg"


// A VertexArrayObject should be binded before these `set_vertex_format` things.
set_vertex_format_PCU :: proc(shader: u32) {
    location_position := gl.GetAttribLocation(shader, "position")
    location_color    := gl.GetAttribLocation(shader, "color")
    location_uv       := gl.GetAttribLocation(shader, "uv")

    assert(location_position != -1 && location_color != -1 && location_uv != -1, 
        "DGL Set Vertex Format: attributes in shader doesnt support format `PCU`")

    P, C, U :u32 = cast(u32)location_position, cast(u32)location_color, cast(u32)location_uv

    gl.EnableVertexAttribArray(P)
    gl.EnableVertexAttribArray(C)
    gl.EnableVertexAttribArray(U)

    stride :i32= size_of(VertexPCU)
    gl.VertexAttribPointer(P, 3, gl.FLOAT, false, stride, 0)
    gl.VertexAttribPointer(C, 4, gl.FLOAT, false, stride, 3 * size_of(f32))
    gl.VertexAttribPointer(U, 2, gl.FLOAT, false, stride, 7 * size_of(f32))
}
set_vertex_format_PCNU :: proc(shader: u32) {
    location_position := gl.GetAttribLocation(shader, "position")
    location_color    := gl.GetAttribLocation(shader, "color")
    location_normal   := gl.GetAttribLocation(shader, "normal")
    location_uv       := gl.GetAttribLocation(shader, "uv")

    assert(location_position != -1 && location_color != -1 && location_normal != -1 && location_uv != -1, 
        "DGL Set Vertex Format: attributes in shader doesnt support format `PCNU`")

    P, C, N, U :u32 = cast(u32)location_position, cast(u32)location_color, cast(u32)location_normal, cast(u32)location_uv

    gl.EnableVertexAttribArray(P)
    gl.EnableVertexAttribArray(C)
    gl.EnableVertexAttribArray(N)
    gl.EnableVertexAttribArray(U)

    stride :i32= size_of(VertexPCNU)
    gl.VertexAttribPointer(P, 3, gl.FLOAT, false, stride, 0)
    gl.VertexAttribPointer(C, 4, gl.FLOAT, false, stride, 3 * size_of(f32))
    gl.VertexAttribPointer(N, 3, gl.FLOAT, false, stride, 7 * size_of(f32))
    gl.VertexAttribPointer(U, 2, gl.FLOAT, false, stride, 10 * size_of(f32))
}

Vec2 :: linalg.Vector2f32
Vec3 :: linalg.Vector3f32
Vec4 :: linalg.Vector4f32

Vec2i :: distinct [2]i32
Vec3i :: distinct [3]i32
Vec4i :: distinct [4]i32

VertexTypes :: bit_set[VertexType]

VertexType :: enum u32 {
    PCU, PCNU,
}

VertexPCU :: struct {
    position : Vec3,
    color    : Vec4,
    uv       : Vec2,
}

VertexPCNU :: struct {
    position : Vec3,
    color    : Vec4,
    normal   : Vec3,
    uv       : Vec2,
}