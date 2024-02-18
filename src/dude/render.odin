package dude

import "dgl"


RenderPass :: struct {
	target : dgl.FramebufferId,
	viewport : Vec4,
	robjs : [dynamic]RenderObject,
}

RenderObject :: union {
	RObjMesh,
}

RObjMesh :: struct {
	shader: dgl.ShaderId,
	material: dgl.Material,
	mesh: dgl.Mesh,
}


RenderCameraViewport :: struct {
	viewport_size : Vec2,
}
RenderCameraDefault2D :: struct {
	position : Vec2,
}

render_pass_init :: proc(layer: ^RenderPass) {
	layer.robjs = make([dynamic]RenderObject)
}
render_pass_release :: proc(layer: ^RenderPass) {
	delete(layer.robjs)
	layer.robjs = nil
}

@(private="file")
test_mesh : dgl.Mesh 
@(private="file")
test_mesh_triangle : dgl.Mesh 


@(private="file")
mat_red : dgl.Material
@(private="file")
mat_green : dgl.Material

@(private="file")
test_shader : dgl.ShaderId
@(private="file")
test_shader_uniform : UniformsTestShader


UniformsTestShader :: struct {
	color: dgl.UniformLocVec4,
}

test_render_init :: proc() {
	using dgl
	mb : MeshBuilder
	mesh_builder_init(&mb, VERTEX_FORMAT_P2U2); defer mesh_builder_release(&mb)

	mesh_builder_add_vertices(&mb,
		{v4={-0.5, -0.5, 0,0}},
		{v4={0.5,  -0.5, 1,0}},
		{v4={-0.5, 0.5,  0,1}},
		{v4={0.5,  0.5,  1,1}},
	)
	mesh_builder_add_indices(&mb, 0,1,2, 1,3,2)
	test_mesh = mesh_builder_create(mb)

	mesh_builder_clear(&mb)
	mesh_builder_add_vertices(&mb,
		{v4={-1.0, -1.0, 0,0}},
		{v4={1.0,  -1.0, 1,0}},
		{v4={-1.0, 1.0,  0,1}},
	)
	mesh_builder_add_indices(&mb, 0,1,2)
	test_mesh_triangle = mesh_builder_create(mb)

	test_shader = shader_load_from_sources(SHADER_SRC_VERT, SHADER_SRC_FRAG)
	uniform_load(&test_shader_uniform, test_shader)

	material_init(&mat_red, test_shader)
	material_set(&mat_red, test_shader_uniform.color, Vec4{1,0.05,0.05, 1})
	material_init(&mat_green, test_shader)
	material_set(&mat_green, test_shader_uniform.color, Vec4{0.05,1,0.05, 1})
}
test_render_release :: proc() {
	dgl.material_release(&mat_red)
	dgl.material_release(&mat_green)
	dgl.mesh_delete(&test_mesh)
	dgl.shader_destroy(test_shader)
}

test_render :: proc() {
	dgl.shader_bind(test_shader)
	dgl.uniform_set(test_shader_uniform.color, Vec4{1,0.2,0.1,1.0})
	dgl.material_upload(mat_red)
	dgl.draw_mesh(test_mesh)
	dgl.material_upload(mat_green)
	dgl.draw_mesh(test_mesh_triangle)
}

SHADER_SRC_VERT :: `
#version 440 core

layout (location = 0) in vec2 position;
layout (location = 1) in vec2 uv;

layout (location = 0) out vec2 _uv;

void main()
{
    gl_Position = vec4(position.x, position.y, 0, 1.0);
	_uv = uv;
}
`
SHADER_SRC_FRAG :: `
#version 440 core
out vec4 FragColor;

layout(location = 0) in vec2 _uv;

uniform vec4 color;

void main() {
    FragColor = vec4(_uv.x, _uv.y, 0,1) * color;
}
`

