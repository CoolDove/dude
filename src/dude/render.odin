package dude

import "core:log"
import "core:math"
import "core:slice"
import "dgl"

import hla "collections/hollow_array"

import gl "vendor:OpenGL"

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

	robjs :  hla.HollowArray(RenderObject),

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
        RObjMesh, RObjSprite, RObjHandle, RObjCustom,
    },
    // impl
    _utable_transform : UniformTableTransform,
}

UniformTableTransform :: struct {
    position : dgl.UniformLocVec2 `uniform:"transform_position"`,
    scale : dgl.UniformLocVec2 `uniform:"transform_scale"`,
    angle : dgl.UniformLocF32 `uniform:"transform_angle"`,
}
UniformTableDefaultMesh :: struct {
    color : dgl.UniformLocVec4,
    texture : dgl.UniformLocTexture,
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
RObjHandle :: struct {
    handle : hla.HollowArrayHandle(RenderObject),
}
RObjSprite :: struct { // A sprite in 2D world space.
	// When the shader is nil, you mean draw the sprite with a builtin sprite shader. If you 
    //  want to use a custom sprite shader, you might have to copy the transforming code in the 
    //  builtin sprite shader.
    texture : u32,
}
RObjCustom :: #type proc()

RenderCamera :: struct {
    using data : CameraUniformData,
}
CameraUniformData :: struct {
    position : Vec2,
    angle : f32,
    size : f32,
    viewport : Vec2,
}

RenderSystem :: struct {
    mesh_unit_quad : dgl.Mesh,

    shader_default_mesh : dgl.ShaderId,
    utable_default_mesh : UniformTableDefaultMesh,
    utable_default_mesh_transform : UniformTableTransform,
    material_default_mesh : dgl.Material,

    shader_default_sprite : dgl.ShaderId,
    utable_default_sprite_transform : UniformTableTransform,
    material_default_sprite : dgl.Material,

    temp_mesh_builder : dgl.MeshBuilder,
}

@(private="file")
rsys : RenderSystem

render_init :: proc() {
    using rsys, dgl

    shader_preprocess_add_lib("dude", #load("./resources/dude.glsl"))

    shader_default_mesh = shader_load_from_sources(
        #load("./resources/default_mesh.vert"), 
        #load("./resources/default_mesh.frag"), true)
    dgl.uniform_load(&utable_default_mesh, shader_default_mesh)
    dgl.uniform_load(&utable_default_mesh_transform, shader_default_mesh)
    material_init(&material_default_mesh, shader_default_mesh)
    material_set_vec4(&material_default_mesh, utable_default_mesh.color, {1,1,1,1})
        
    shader_default_sprite = shader_load_from_sources(
        #load("./resources/default_sprite.vert"), 
        #load("./resources/default_sprite.frag"), true)
    dgl.uniform_load(&utable_default_sprite_transform, shader_default_sprite)
    // TODO: sprite utable
    
    mesh_builder_init(&temp_mesh_builder, VERTEX_FORMAT_P2U2)
}

render_release :: proc() {
    using rsys, dgl

    material_release(&material_default_mesh)
    shader_destroy(shader_default_mesh)

    material_release(&material_default_sprite)
    shader_destroy(shader_default_sprite)
    
    mesh_builder_release(&temp_mesh_builder)
}


render_pass_init :: proc(pass: ^RenderPass) {
	pass.robjs = hla.hla_make(RenderObject, 128)// make([dynamic]RenderObject)
	pass.robjs_sorted = make([dynamic]^RenderObject)

    pass.camera_ubo = dgl.ubo_create(size_of(CameraUniformData))
    pass.clear.mask = {.Color,.Depth,.Stencil}
}
render_pass_release :: proc(pass: ^RenderPass) {
	// delete(pass.robjs)
    using hla
    hla_delete(&pass.robjs)
    if len(pass.robjs_sorted) > 0 do delete(pass.robjs_sorted)
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
    robj_idx : int
    for obj in hla.hla_ite(&pass.robjs, &robj_idx) {
        material := obj.material
        if material != nil && obj._utable_transform.position == obj._utable_transform.scale {
            dgl.uniform_load(&obj._utable_transform, material.shader)
        }

        if robj_mesh, ok := obj.obj.(RObjMesh); ok {
            utable_transform : UniformTableTransform 
            if obj.material != nil {
                utable_transform = obj._utable_transform
            } else {
                material = &rsys.material_default_mesh
                utable_transform = rsys.utable_default_mesh_transform
            }
            dgl.material_upload(material^) // This binds the shader.
            dgl.uniform_set_vec2(utable_transform.position, obj.position)
            dgl.uniform_set_vec2(utable_transform.scale, obj.scale)
            dgl.uniform_set_f32(utable_transform.angle, obj.angle)
                
            dgl.draw_mesh(robj_mesh.mesh)
        } else if robj_custom, ok := obj.obj.(RObjCustom); ok {
            // TODO: Write a better one.
            if robj_custom != nil do robj_custom()
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

	test_shader = rsys.shader_default_mesh
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

    hla.hla_append(&test_pass.robjs, RenderObject{ obj = cast(RObjCustom)robj_grid })

    hla.hla_append(&test_pass.robjs, RenderObject{
        RenderTransform{scale={1,1}, position={0,0}}, 
        nil,
        RObjMesh{
            mesh = test_mesh,
        },
        {},
    })

    hla.hla_append(&test_pass.robjs, RenderObject{
        RenderTransform{scale={1,1}, position={-5,0}}, 
        &mat_green,
        RObjMesh{
            mesh = test_mesh_triangle,
        },
        {},
    })

    robj_grid :: proc() {// Temporary: This is bad.
        mb := &rsys.temp_mesh_builder
        dgl.mesh_builder_clear(mb)
        mb.vertex_format = dgl.VERTEX_FORMAT_P2U2

        half_size :int= 20
        unit :f32= 1.0
        size := 2 * half_size

        min := -cast(f32)half_size * unit;
        max := cast(f32)half_size * unit;

        for i in 0..=size {
            x := min + cast(f32)i * unit
            dgl.mesh_builder_add_vertices(mb, {v2={x,min}})
            dgl.mesh_builder_add_vertices(mb, {v2={x,max}})
        }
        for i in 0..=size {
            y := min + cast(f32)i * unit
            dgl.mesh_builder_add_vertices(mb, {v2={min,y}})
            dgl.mesh_builder_add_vertices(mb, {v2={max,y}})
        }
        vao : u32
        vbo : u32
        mesh := dgl.mesh_builder_create(mb^, true); defer dgl.mesh_delete(&mesh)
        gl.BindVertexArray(mesh.vao)
	    set_vertex_format(mb.vertex_format)

        dgl.material_upload(rsys.material_default_mesh)
        dgl.uniform_set(rsys.utable_default_mesh_transform.position, Vec2{})
        dgl.uniform_set(rsys.utable_default_mesh_transform.scale, Vec2{1,1})
        dgl.uniform_set(rsys.utable_default_mesh_transform.angle, 0)

        dgl.uniform_set(rsys.utable_default_mesh.color, Vec4{.1,.1,.1, 1.0})

        polygon_mode_stash : u32
        gl.GetIntegerv(gl.POLYGON_MODE, cast(^i32)&polygon_mode_stash)
        gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE)
        gl.DrawArrays(gl.LINES, 0, cast(i32)len(mb.vertices) * 2)
        gl.PolygonMode(gl.FRONT_AND_BACK, polygon_mode_stash)
    }
}

test_render_release :: proc() {
	dgl.material_release(&mat_red)
	dgl.material_release(&mat_green)
	dgl.mesh_delete(&test_mesh)
	dgl.mesh_delete(&test_mesh_triangle)
	dgl.shader_destroy(test_shader)

    render_pass_release(&test_pass)
}

test_render :: proc(delta: f32) {
    @static time : f32 = 0
    time += delta

    viewport := app.window.size

    test_pass.viewport = Vec4i{0,0, viewport.x, viewport.y}
    test_pass.camera.viewport = vec_i2f(viewport)

    // test_pass.camera.position.x = math.sin(time*0.8)
    test_pass.camera.angle = 0.06 * math.sin(time*0.8)

    camera := &test_pass.camera
    move_speed :f32= 3.0
    if get_key(.A) do camera.position.x -= move_speed * delta
    else if get_key(.D) do camera.position.x += move_speed * delta
    if get_key(.W) do camera.position.y += move_speed * delta
    else if get_key(.S) do camera.position.y -= move_speed * delta
    
    render_pass_draw(&test_pass)
}