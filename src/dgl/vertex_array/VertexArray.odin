package vertex_array

import "core:log"
import "core:fmt"

import gl "vendor:OpenGL"
import basic "../basic"
import dbuf "../buffer"

GLObject :: basic.GLObject

VertexArray :: struct {
    using obj : GLObject,
    attributes : [dynamic]VertexAttribute,
    stride : u32
}

AttributeType :: enum u32 {
    FLOAT = gl.FLOAT,
    HALF_FLOAT = gl.HALF_FLOAT,
    DOUBLE = gl.DOUBLE,
    FIXED = gl.FIXED,

    BYTE = gl.BYTE,
    UNSIGNED_BYTE = gl.UNSIGNED_BYTE,

    SHORT = gl.SHORT,
    UNSIGNED_SHORT = gl.UNSIGNED_SHORT,

    INT = gl.INT,
    UNSIGNED_INT = gl.UNSIGNED_INT,

    INT_2_10_10_10_REV = gl.INT_2_10_10_10_REV,
    UNSIGNED_INT_2_10_10_10_REV = gl.UNSIGNED_INT_2_10_10_10_REV,
    UNSIGNED_INT_10F_11F_11F_REV = gl.UNSIGNED_INT_10F_11F_11F_REV,
}

// https://www.khronos.org/opengl/wiki/Vertex_Shader
AttributeShaderType :: enum u8 {
    Float, Int, Vector
}

VertexAttribute :: struct {
    name : string,
    count : i32,
    type : AttributeType,
    // shader_type : AttributeShaderType,
    normalized : bool,
}

create :: proc {
    create_without_buffer,
    create_with_buffer,
}

create_without_buffer :: proc(attributes: ..VertexAttribute) -> VertexArray {
    vao : VertexArray
    vao.attributes = make([dynamic]VertexAttribute, 0, len(attributes))

	gl.GenVertexArrays(1, &vao.native_id)
    gl.BindVertexArray(vao.native_id)
    id := vao.native_id
    offset :u32= 0
    for atb, ind in attributes {
        using atb
        index :u32= cast(u32)ind
        gl.VertexArrayAttribFormat(id, index, count, cast(u32)type, normalized, offset)
        gl.VertexArrayAttribBinding(id, index, 0)
        gl.EnableVertexArrayAttrib(id, index)
        size := get_attribute_size(count, type)
        log.debugf("DGL Debug: AttribFormat: {}, size: {}, offset: {}", name, size, offset)
        offset += size
        append(&vao.attributes, atb)
    }
    vao.stride = offset
    return vao
}
create_with_buffer :: proc(vertex_buffer, index_buffer: ^dbuf.Buffer, attributes: ..VertexAttribute) -> VertexArray {
    vao := create_without_buffer(..attributes)

    if vertex_buffer != nil do attach_vertex_buffer(&vao, vertex_buffer, 0, vao.stride, 0)
    if index_buffer != nil do attach_index_buffer(&vao, index_buffer)
    return vao
}

attach_vertex_buffer :: proc(vertex_array: ^VertexArray, buffer: ^dbuf.Buffer, offset, stride, binding_index : u32) {
    bind(vertex_array)
    gl.VertexArrayVertexBuffer(
        vertex_array.native_id,
        binding_index, 
        buffer.native_id, 
        cast(int)offset, cast(i32)stride)
}
attach_index_buffer :: proc(vertex_array: ^VertexArray, buffer: ^dbuf.Buffer) {
    bind(vertex_array)
    gl.VertexArrayElementBuffer(vertex_array.native_id, buffer.native_id)
}


@(private="file") 
get_attribute_size :: proc (#any_int count: u32, type: AttributeType) -> u32 {
    size : u32
    #partial switch type {
    case .FLOAT: size = size_of(f32)
    // ...
    }
    assert(size != 0, 
        fmt.tprintf("DGL Assert, the type for {} is not implemented. Cannot calculate size", type))
    return count * size
}

destroy :: proc(vertex_array: ..^VertexArray) {
    count := cast(i32)len(vertex_array)
    ids := make([dynamic]u32, 0, count)
    for vao in vertex_array {
        delete(vao.attributes)
        append(&ids, vao.native_id)
    }
    gl.DeleteVertexArrays(count, raw_data(ids[:]))
}

bind :: proc(vertex_array: ^VertexArray) {
    if current_vertex_array != vertex_array do gl.BindVertexArray(vertex_array.native_id)
}


@(private="file")
current_vertex_array : ^VertexArray

