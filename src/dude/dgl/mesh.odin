package dgl

import "core:math/linalg"
import "core:mem"
import "core:runtime"

import gl "vendor:OpenGL"

VertexFormat :: distinct [VERTEX_MAX_CHANNEL]u8

VERTEX_MAX_CHANNEL :: 8

VERTEX_FORMAT_P2U2 :: VertexFormat{ 2,2, 0,0,0,0,0,0 } // 4
VERTEX_FORMAT_P2U2C4 :: VertexFormat{ 2,2,4, 0,0,0,0,0 } // 8
VERTEX_FORMAT_P3U2N3 :: VertexFormat{ 3,2,3, 0,0,0,0,0 } // 8

Mesh :: struct {
    vao, vertex_buffer, index_buffer : u32,
    vertex_count, index_count : i32,
	vertex_format : VertexFormat,
}


VERTEX_FORMAT_MAX_ATTRIBUTE :: 16
Vertex :: struct #raw_union {
	vfull:VertexMax,
	v16:Vertex16,
	v12:Vertex12,
	v10:Vertex10,
	v8:Vertex8,
	v6:Vertex6,
	v4:Vertex4,
	v2:Vertex2,
}
VertexMax :: distinct [VERTEX_FORMAT_MAX_ATTRIBUTE]f32
Vertex16 :: distinct [16]f32
Vertex12 :: distinct [12]f32
Vertex10 :: distinct [10]f32
Vertex8 :: distinct [8]f32
Vertex6 :: distinct [6]f32
Vertex4 :: distinct [4]f32
Vertex2 :: distinct [2]f32

MeshBuilder :: struct {
	vertex_format : VertexFormat,
	stride : u32,
    vertices : [dynamic]f32,
    indices : [dynamic]u32,
}
mesh_builder_add_vertices :: proc(builder: ^MeshBuilder, vertices: ..Vertex) {
    _mesh_builder_update_stride(builder)
	for v in vertices {
		vertex :[16]f32= transmute([16]f32)v
		for i in 0..<builder.stride {
			append_elem(&builder.vertices, vertex[i])
		}
	}
}

mesh_builder_add_indices :: proc(builder: ^MeshBuilder, indices: ..u32) {
    append_elems(&builder.indices, ..indices)
}

mesh_builder_init :: proc(builder: ^MeshBuilder, vertex_format: VertexFormat, reserve_vertices:i32=0, reserve_indices:i32=0, allocator:= context.allocator) {
    context.allocator = allocator
	builder.vertex_format = vertex_format
    builder.vertices = make_dynamic_array_len_cap([dynamic]f32, 0, reserve_vertices)
    builder.indices = make_dynamic_array_len_cap([dynamic]u32, 0, reserve_indices)
    _mesh_builder_update_stride(builder)
}
mesh_builder_release :: proc(builder: ^MeshBuilder) {
    delete(builder.vertices)
    delete(builder.indices)
    builder^ = {}
}

mesh_builder_reset :: proc(builder: ^MeshBuilder, vertex_format: VertexFormat) {
    clear(&builder.vertices)
    clear(&builder.indices)
    builder.vertex_format = vertex_format
}
mesh_builder_clear :: proc(builder: ^MeshBuilder) {
    clear(&builder.vertices)
    clear(&builder.indices)
}

mesh_builder_create :: proc(using builder: MeshBuilder, no_indices:=false) -> (Mesh, bool) #optional_ok {
    context.allocator = runtime.default_allocator()
    mesh : Mesh
    gl.GenVertexArrays(1, auto_cast &mesh.vao)
    gl.BindVertexArray(mesh.vao)

    gl.GenBuffers(1, &mesh.vertex_buffer)
    gl.BindBuffer(gl.ARRAY_BUFFER, mesh.vertex_buffer)
    gl.BufferData(gl.ARRAY_BUFFER, len(vertices) * size_of(f32), raw_data(vertices), gl.STATIC_DRAW)

    mesh.vertex_count = auto_cast len(builder.vertices) / cast(i32)builder.stride

    if !no_indices {
        gl.GenBuffers(1, &mesh.index_buffer)
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, mesh.index_buffer)
        gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, len(indices) * size_of(u32), raw_data(indices), gl.STATIC_DRAW)
        mesh.index_count = auto_cast len(builder.indices)
    }

	set_vertex_format(builder.vertex_format)

	gl.BindVertexArray(0) // Make sure everything bound to the vao is safe.
	
    return mesh, true
}

@(private="file")
_mesh_builder_update_stride :: #force_inline proc(mb: ^MeshBuilder) {
	stride :u32= 0
	for i in mb.vertex_format do stride += cast(u32)i
	mb.stride = stride
}

mesh_delete :: proc(mesh: ^Mesh) {
    gl.DeleteBuffers(1, &mesh.vertex_buffer)
    gl.DeleteBuffers(1, &mesh.index_buffer)
    gl.DeleteVertexArrays(1, &mesh.vao)
    mesh^ = {}
}

mesh_bind :: proc(using mesh: ^Mesh) {
    gl.BindVertexArray(vao)
}