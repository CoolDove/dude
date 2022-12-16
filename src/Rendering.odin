package main

import dbuf "dgl/buffer"
import dva "dgl/vertex_array"
import dsh "dgl/shader"

current_render_context : RenderContext

// NOTE(Dove): Rendering design
// RenderObjects: Static / Immediate
// In `Update` build RenderObject,
RenderObject :: struct {
    // vertex_array : dva.VertexArray,
    shader : ^dsh.Shader,
    vertex_array : ^dva.VertexArray,
    vertex_buffer, index_buffer : dbuf.Buffer,
    vertex_count, index_count : u32,
}

RenderRepository :: struct {
    vertex_arrays : map[string]dva.VertexArray,
    shaders : map[string]dsh.Shader,
}

RenderContext :: struct {
    static, immediate : [dynamic]RenderObject
}

Mesh :: struct {
    vertices : [dynamic]Vertex,
    triangles : [dynamic]Vec3i
}

Vertex :: struct {
    position : Vec3,
    uv : Vec2
}

render_obj_create :: proc (vao: ^dva.VertexArray, shader: ^dsh.Shader, vertex_buffer, index_buffer : dbuf.Buffer, vertex_count, index_count : u32) -> RenderObject {
    robj : RenderObject
    robj.vertex_array = vao
    robj.shader = shader
    robj.vertex_buffer = vertex_buffer
    robj.index_buffer = index_buffer
    robj.vertex_count = vertex_count
    robj.index_count = index_count
    return robj
}

render_obj_destroy :: proc (robj: ^RenderObject) {
    dbuf.destroy(&robj.vertex_buffer, &robj.index_buffer)
}

render :: proc (render_context: ^RenderContext, objs: []RenderObject) {
}

immediate_quad :: proc() {
    rctx := &current_render_context

}