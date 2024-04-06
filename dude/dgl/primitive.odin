package dgl

import gl "vendor:OpenGL"


DrawPrimitive :: struct {
    vao, vbo, ibo : u32,
    count : i32,
}

primitive_draw :: proc(using p: ^DrawPrimitive, shader: u32) {
    if ibo == 0 {
        gl.BindVertexArray(vao)
        gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
        set_vertex_format_PCU(shader)
        gl.DrawArrays(gl.TRIANGLES, 0, count)
    } else {
        // TODO
    }
}

primitive_delete :: proc(using p : ^DrawPrimitive) {
    gl.DeleteVertexArrays(1, &p.vao)
    gl.DeleteBuffers(1, &p.vbo)
    gl.DeleteBuffers(1, &p.ibo)
}

primitive_make_quad_a :: proc(color: Vec4) -> DrawPrimitive {
    /*
      a(0,0)-b
      |      |
      |      |
      c------d(1, 1)
    */
    a := VertexPCU{
        Vec3{0, 0, 0},
        color,
        Vec2{0, 1},
    }
    b := VertexPCU{
        Vec3{1, 0, 0},
        color,
        Vec2{1, 1},
    }
    c := VertexPCU{
        Vec3{0, 1, 0},
        color,
        Vec2{0, 0},
    }
    d := VertexPCU{
        Vec3{1, 1, 0},
        color,
        Vec2{1, 0},
    }
    data := [6]VertexPCU {a,b,c, b,c,d}

    vao, vbo : u32
    gl.GenVertexArrays(1, &vao)
    gl.GenBuffers(1, &vbo)
    gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
    gl.BufferData(gl.ARRAY_BUFFER, 6 * size_of(VertexPCU), raw_data(data[:]), gl.STREAM_DRAW)
    return {
        vao=vao,
        vbo=vbo,
        count=6,
    }
}
