package dgl

import gl "vendor:OpenGL"
import dbuf "/buffer"

import "core:log"


// set_vertex_format :: proc(format: string) {
// }

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

    stride :i32= 9 * size_of(f32)
    gl.VertexAttribPointer(P, 3, gl.FLOAT, false, stride, 0)
    gl.VertexAttribPointer(C, 4, gl.FLOAT, false, stride, 3 * size_of(f32))
    gl.VertexAttribPointer(U, 2, gl.FLOAT, false, stride, 7 * size_of(f32))

}

bind_vertex_buffer :: proc(buffer: ^dbuf.Buffer) {
    gl.BindBuffer(gl.ARRAY_BUFFER, buffer.native_id)
}
bind_index_buffer :: proc(buffer: ^dbuf.Buffer) {
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, buffer.native_id)
}

Vec2 :: distinct [2]f32
Vec3 :: distinct [3]f32
Vec4 :: distinct [4]f32

Vec2i :: distinct [2]i32
Vec3i :: distinct [3]i32
Vec4i :: distinct [4]i32

VertexPCU :: struct {
    position : Vec3,
    color    : Vec4,
    uv       : Vec2
}

