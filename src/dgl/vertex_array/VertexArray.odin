package vertex_array

import "core:log"
import "core:fmt"

import gl "vendor:OpenGL"
import dgl "../"
import dbuf "../buffer"

GLObject :: dgl.GLObject

VertexArray :: struct {
    using obj : GLObject,
    attributes : [dynamic]VertexAttribute
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
    shader_type : AttributeShaderType,
    normalized : bool,
}

create :: proc(buffer: ^dbuf.Buffer, attributes: ..VertexAttribute) -> VertexArray {
    vao : VertexArray
	gl.GenVertexArrays(1, &vao.native_id)
    id := vao.native_id
    offset :u32= 0
    for atb, ind in attributes {
        using atb
        index :u32= cast(u32)ind
        gl.VertexArrayAttribFormat(id, index, count, cast(u32)type, normalized, offset)
        gl.VertexArrayAttribBinding(id, index, index)
        gl.EnableVertexArrayAttrib(id, index)
        offset += get_attribute_size(count, type)
    }
    gl.VertexArrayVertexBuffer(id, 0, buffer.native_id, 0, cast(i32)offset)
    return vao
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
    gl.BindVertexArray(vertex_array.native_id)
}