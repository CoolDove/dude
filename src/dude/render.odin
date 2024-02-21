package dude

import "core:log"
import "core:slice"
import "dgl"

// Reserve to 4
UNIFORM_BLOCK_SLOT_CAMERA :: 0

// Draw mesh: Do some basic transform which you can write your own shader to customize.
// Draw sprite: Draw a unit quad with the same 
// You can draw meshes, sprites (which actually draws a unit quad with a sprite shader) in a pass
RenderPass :: struct {
    // Differs from the viewport in camera, which is for transform calculation. This one defines how
    //  you output to the framebuffer. (This is what passed into gl.Viewport(...) before rendering)
    viewport : Vec4i,
	target : dgl.FramebufferId, // 0 means the default framebuffer.
	camera : RenderCamera,

    clear : RenderClear,

	robjs : [dynamic]RenderObject,

    using impl : RenderPassImplData,
}

RenderClear :: struct {
    color : Vec4,
    depth : f64,
    stencil : i32,

    mask : dgl.ClearMasks,
}

// Implementation necessary data, which you cannot access from outside.
@(private="file")
RenderPassImplData :: struct {
    robjs_sorted : [dynamic]^RenderObject, // This shall be sorted every time before you draw the pass.
    camera_ubo : dgl.UniformBlockId,
}

RenderObject :: struct {
    using transform : RenderTransform,
    material : ^dgl.Material,
	obj : union {
        RObjMesh, RObjSprite,
    },
    // impl
    _utable_transform : UniformTableTransform,
}

UniformTableTransform :: struct {
    transform_position, transform_scale : dgl.UniformLocVec2,
    transform_angle : dgl.UniformLocF32,
}

// TODO: Rename RenderTransform to Transform after the old Transform can be removed.
RenderTransform :: struct {
    position : Vec2,
    scale : Vec2, // For sprite this is size.
    angle : f32,
    order : i32, // Objects with smaller order would be drawn earlier.
}

RObjMesh :: struct { // Just a mesh in 2D world space, with position-z always 0.
    // When the shader is nil, you mean draw the mesh with a builtin mesh shader.
	mesh : dgl.Mesh,
}
RObjSprite :: struct { // A sprite in 2D world space.
	// When the shader is nil, you mean draw the sprite with a builtin sprite shader. If you 
    //  want to use a custom sprite shader, you might have to copy the transforming code in the 
    //  builtin sprite shader.
    texture : u32,
}

RenderCamera :: struct {
    using data : CameraUniformData,
}
CameraUniformData :: struct {
    position : Vec2,
    angle : f32,
    size : f32,
    viewport : Vec2,
}

render_pass_init :: proc(pass: ^RenderPass) {
	pass.robjs = make([dynamic]RenderObject)
	pass.robjs_sorted = make([dynamic]^RenderObject)

    pass.camera_ubo = dgl.ubo_create(size_of(CameraUniformData))
    pass.clear.mask = {.Color,.Depth,.Stencil}
}
render_pass_release :: proc(pass: ^RenderPass) {
	delete(pass.robjs)
    if len(pass.robjs_sorted) > 0 do delete(pass.robjs_sorted)
	pass.robjs = nil
	pass.robjs_sorted = nil
    if pass.camera_ubo != 0 {
        dgl.ubo_release(&pass.camera_ubo)
    }
}

render_pass_draw :: proc(pass: ^RenderPass) {
    dgl.framebuffer_bind(pass.target)
    dgl.state_set_viewport(pass.viewport)

    {// ## Clear
        using pass.clear
        dgl.framebuffer_clear(mask, color,depth,stencil)
    }
    
    // ## Upload camera data to uniform block.
    dgl.ubo_update_with_object(pass.camera_ubo, &pass.camera.data)
    dgl.ubo_bind(pass.camera_ubo, UNIFORM_BLOCK_SLOT_CAMERA)

    // TODO: Sort all the render objects.
    for obj in &pass.robjs {
        if obj._utable_transform.transform_position == 0 && obj._utable_transform.transform_scale == 0 {
            dgl.uniform_load(&obj._utable_transform, obj.material.shader)
        }

        dgl.material_upload(obj.material^) // This binds the shader.

        utable_transform := obj._utable_transform
        dgl.uniform_set_vec2(utable_transform.transform_position, obj.position)
        dgl.uniform_set_vec2(utable_transform.transform_scale, obj.scale)
        dgl.uniform_set_f32(utable_transform.transform_angle, obj.angle)

        if robj_mesh, ok := obj.obj.(RObjMesh); ok {
            dgl.draw_mesh(robj_mesh.mesh)
        } else {
            log.errorf("Render: Render object type not supported, currently we can only render mesh.")
        }
    }
    // ## Sort all render objects.
    dgl.framebuffer_bind_default()
}

// Test rendering.

@(private="file")
test_pass : RenderPass

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
	material_set(&mat_red, test_shader_uniform.color, Vec4{1,0.25,0.3, 1})
	material_init(&mat_green, test_shader)
	material_set(&mat_green, test_shader_uniform.color, Vec4{0.05,1,0.05, 1})

    // Pass initialization
    render_pass_init(&test_pass)

    test_pass.viewport = {0,0,320,320}
    test_pass.camera.viewport = {320,320}
    test_pass.camera.size = 32
    test_pass.clear.color = {.2,.2,.2, 1}

    append(&test_pass.robjs, RenderObject{
        RenderTransform{scale={1,1}}, 
        &mat_red,
        RObjMesh{
            mesh = test_mesh,
        },
        {},
    })
}

test_render_release :: proc() {
	dgl.material_release(&mat_red)
	dgl.material_release(&mat_green)
	dgl.mesh_delete(&test_mesh)
	dgl.mesh_delete(&test_mesh_triangle)
	dgl.shader_destroy(test_shader)

    render_pass_release(&test_pass)
}

test_render :: proc() {
    render_pass_draw(&test_pass)
}

SHADER_SRC_VERT :: `
#version 440 core


// --- This part should be moved to 'dude' shaderlib.
layout(std140, binding = 0) uniform Camera {
    vec2 position;
    float angle;
    float size;
    vec2 viewport;
} camera;

uniform vec2 transform_position;
uniform vec2 transform_scale;
uniform float transform_angle;

vec2 transform_point(vec2 point, vec2 position, vec2 scale, float angle) {
    vec2 p = point;
    p = p * scale;
    float sa = sin(angle);
    float ca = cos(angle);
    p = vec2(p.x * ca + p.y * sa, p.y * ca - p.x * sa);
    return p + position;
}

// ---


layout (location = 0) in vec2 position;
layout (location = 1) in vec2 uv;

layout (location = 0) out vec2 _uv;

void main()
{
    vec2 pos = transform_point(position, transform_position, transform_scale, transform_angle);
    gl_Position = vec4(pos.x, pos.y, 0.5, 1.0);
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
