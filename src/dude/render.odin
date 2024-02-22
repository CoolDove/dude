package dude

import "core:log"
import "core:math"
import "core:slice"
import "dgl"

import hla "collections/hollow_array"


// Reserved up to 8, when you want to make your own custom uniform block, the slot should be greater 
//  than 8.
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

// Implementation necessary data, which you cannot access from outside.
@(private="file")
RenderPassImplData :: struct {
    robjs_sorted : [dynamic]^RenderObject, // This shall be sorted everytime you draw the pass.
    camera_ubo : dgl.UniformBlockId,
}

// RenderObject doesn't allocate anything.
RenderObject :: struct {
    using transform : RenderTransform,
    material : ^Material,
	obj : RObj,
}

UniformTableTransform :: struct {
    position : dgl.UniformLocVec2 `uniform:"transform_position"`,
    scale : dgl.UniformLocVec2 `uniform:"transform_scale"`,
    angle : dgl.UniformLocF32 `uniform:"transform_angle"`,
}
UniformTableGeneral :: struct {
    color : dgl.UniformLocVec4 `uniform:"color"`,
    texture : dgl.UniformLocTexture `uniform:"main_texture"`,
}
UniformTableSprite :: struct {
    anchor : dgl.UniformLocVec4,
    size : dgl.UniformLocVec4,
}

// TODO: Rename RenderTransform to Transform after the old Transform can be removed.
RenderTransform :: struct {
    position : Vec2,
    scale : Vec2, // For sprite this is size.
    angle : f32,
    order : i32, // Objects with smaller order would be drawn earlier.
}

RObj :: union {
    RObjMesh, RObjSprite, RObjHandle, RObjCustom,
}

RObjMesh :: struct {
    mesh : dgl.Mesh,
    utable : UniformTableGeneral,
}
RObjHandle :: hla.HollowArrayHandle(RenderObject) 
RObjSprite :: struct { // A sprite in 2D world space.
	// When the shader is nil, you mean draw the sprite with a builtin sprite shader.
    texture : u32,
    anchor : Vec2, // [0,1]
    size : Vec2, // This differs from scale in transform.

    utable : UniformTableSprite,
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
    temp_mesh_builder : dgl.MeshBuilder,

    // Builtin resources
    mesh_unit_quad : dgl.Mesh,

    shader_default_mesh : Shader,
    material_default_mesh : Material,

    shader_default_sprite : Shader,
    material_default_sprite : Material,

    texture_default_white : dgl.TextureId,
    texture_default_black : dgl.TextureId,
}

@(private="file")
rsys : RenderSystem

render_init :: proc() {
    using rsys

    // Textures
    texture_default_white = dgl.texture_create_with_color(4,4, {255,255,255,255})
    texture_default_black = dgl.texture_create_with_color(4,4, {0,0,0,255})

    // Shaders & Materials
    shader_register_lib("dude", #load("./resources/dude.glsl"))

    {using shader_default_mesh
        shader_init(&shader_default_mesh, 
            #load("./resources/default_mesh.vert"),
            #load("./resources/default_mesh.frag"))
        material_init(&material_default_mesh, &shader_default_mesh)
        material_set_vec4(&material_default_mesh,  utable_general.color, {1,1,1,1})
        material_set_texture(&material_default_mesh, utable_general.texture, rsys.texture_default_white)
    }
    
    {using shader_default_sprite
        shader_init(&shader_default_sprite, 
            #load("./resources/default_sprite.vert"),
            #load("./resources/default_sprite.frag"))
        material_init(&material_default_sprite, &shader_default_sprite)
        material_set_vec4(&material_default_sprite,  utable_general.color, {1,1,1,1})
        material_set_texture(&material_default_sprite, utable_general.texture, rsys.texture_default_white)
    }

    // Meshes
    {using dgl
        mesh_builder_init(&temp_mesh_builder, VERTEX_FORMAT_P2U2)
        mesh_builder_add_vertices(&temp_mesh_builder, 
            {v4={0,0,  0,0}},
            {v4={1,0,  1,0}},
            {v4={0,1,  0,1}},
            {v4={1,1,  1,1}},
        )
        mesh_builder_add_indices(&temp_mesh_builder, 0,1,2, 1,3,2)
        mesh_unit_quad = mesh_builder_create(temp_mesh_builder)
    }
}

render_release :: proc() {
    using rsys

    dgl.mesh_delete(&mesh_unit_quad)

    material_release(&material_default_mesh)
    shader_release(&shader_default_mesh)

    material_release(&material_default_sprite)
    shader_release(&shader_default_sprite)
    
    dgl.mesh_builder_release(&temp_mesh_builder)
}


render_pass_init :: proc(pass: ^RenderPass, viewport: Vec4i) {
	pass.robjs = hla.hla_make(RenderObject, 128)
	pass.robjs_sorted = make([dynamic]^RenderObject)

    pass.camera_ubo = dgl.ubo_create(size_of(CameraUniformData))
    pass.clear.mask = {.Color,.Depth,.Stencil}

    pass.camera.viewport = vec_i2f(Vec2i{viewport.z, viewport.w})
    pass.camera.size = 32
    pass.viewport = viewport
}
render_pass_release :: proc(pass: ^RenderPass) {
    hla.hla_delete(&pass.robjs)
    if len(pass.robjs_sorted) > 0 do delete(pass.robjs_sorted)
	pass.robjs_sorted = nil
    if pass.camera_ubo != 0 {
        dgl.ubo_release(&pass.camera_ubo)
    }
}

render_pass_add_object :: proc(pass: ^RenderPass, obj: RObj, material: ^Material,
order: i32=0, position:Vec2={0,0}, scale:Vec2={1,1}, angle:f32=0) -> RObjHandle {
    return hla.hla_append(&test_pass.robjs, 
        RenderObject{ 
            obj = obj, 
            material = material,
            transform = {
                position=position,
                scale=scale,
                angle=angle,
                order=order },
    })
}

RenderClear :: struct {
    color : Vec4,
    depth : f64,
    stencil : i32,

    mask : dgl.ClearMasks,
}

render_pass_draw :: proc(pass: ^RenderPass) {
    dgl.framebuffer_bind(pass.target)
    dgl.state_set_viewport(pass.viewport)
    blend_before := dgl.state_get_blend_simple(); defer dgl.state_set_blend(blend_before)
    dgl.state_set_blend(dgl.GlStateBlendSimp{true, .FUNC_ADD, .SRC_ALPHA, .ONE_MINUS_SRC_ALPHA})

    {// ** Clear
        using pass.clear
        dgl.framebuffer_clear(mask, color,depth,stencil)
    }
    
    // ** Upload camera data to uniform block.
    dgl.ubo_update_with_object(pass.camera_ubo, &pass.camera.data)
    dgl.ubo_bind(pass.camera_ubo, UNIFORM_BLOCK_SLOT_CAMERA)

    // TODO: Sort all the render objects.
    robj_idx : int
    for obj in hla.hla_ite(&pass.robjs, &robj_idx) {
        if robj_mesh, ok := obj.obj.(RObjMesh); ok {
            material := obj.material if (obj.material != nil) else &rsys.material_default_mesh
            dgl.material_upload(material.mat)
            uniform_transform(material.shader.utable_transform, obj.position, obj.scale, obj.angle)
                
            dgl.draw_mesh(robj_mesh.mesh)
        } else if robj_custom, ok := obj.obj.(RObjCustom); ok {
            // TODO: Write a better one.
            if robj_custom != nil do robj_custom()
        } else {
            log.errorf("Render: Render object type not supported, currently we can only render mesh.")
        }
    }
    
    dgl.framebuffer_bind_default()
    
}



// ** Test rendering.
@(private="file")
test_pass : RenderPass

@(private="file")
test_mesh_triangle : dgl.Mesh 


@(private="file")
mat_red : Material
@(private="file")
mat_green : Material

@(private="file")
test_texture : dgl.Texture

triangle : RObjHandle

UniformsTestShader :: struct {
	color: dgl.UniformLocVec4,
}

test_render_init :: proc() {
    {
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

        mesh_builder_clear(&mb)
        mesh_builder_add_vertices(&mb,
            {v4={-1.0, -1.0, 0,0}},
            {v4={1.0,  -1.0, 1,0}},
            {v4={-1.0, 1.0,  0,1}},
        )
        mesh_builder_add_indices(&mb, 0,1,2)
        test_mesh_triangle = mesh_builder_create(mb)

        test_texture = texture_load_from_mem(#load("./resources/dude.png"))
    }

    utable_general := rsys.shader_default_mesh.utable_general
	material_init(&mat_red, &rsys.shader_default_mesh)
	material_set(&mat_red, utable_general.color, Vec4{1,0.6,0.8, 1})
	material_set(&mat_red, utable_general.texture, test_texture.id)
	material_init(&mat_green, &rsys.shader_default_mesh)
	material_set(&mat_green, utable_general.color, Vec4{0.8,1,0.6, 1})
	material_set(&mat_green, utable_general.texture, test_texture.id)

    // Pass initialization
    render_pass_init(&test_pass, {0,0, 320, 320})

    test_pass.viewport = {0,0,320,320}
    test_pass.camera.viewport = {320,320}
    test_pass.camera.size = 32
    test_pass.clear.color = {.2,.2,.2, 1}

    render_pass_add_object(&test_pass, cast(RObjCustom)robj_grid, nil, order=-999)
    render_pass_add_object(&test_pass, RObjMesh{mesh=rsys.mesh_unit_quad}, &mat_red)
    render_pass_add_object(&test_pass, RObjMesh{mesh=rsys.mesh_unit_quad}, nil, position={1,1})
    triangle = render_pass_add_object(&test_pass, RObjMesh{mesh=test_mesh_triangle}, &mat_green, position={0,0})

    robj_grid :: proc() {// Temporary: This is bad.
        mb := &rsys.temp_mesh_builder
        dgl.mesh_builder_reset(mb, dgl.VERTEX_FORMAT_P2U2)

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
        mesh := dgl.mesh_builder_create(mb^, true); defer dgl.mesh_delete(&mesh)
        dgl.mesh_bind(&mesh)

        dgl.material_upload(rsys.material_default_mesh.mat)

        shader := rsys.material_default_mesh.shader
        uniform_transform(shader.utable_transform, Vec2{}, Vec2{1,1}, 0)
        dgl.uniform_set(shader.utable_general.color, Vec4{.1,.1,.1, 1.0})

        polygon_mode_stash : u32
        dgl.draw_lines(mesh.vertex_count)
    }
}

test_render_release :: proc() {
    dgl.texture_delete(&test_texture.id)
    
	material_release(&mat_red)
	material_release(&mat_green)
	dgl.mesh_delete(&test_mesh_triangle)

    render_pass_release(&test_pass)
}

test_render :: proc(delta: f32) {
    @static time : f32 = 0
    time += delta

    viewport := app.window.size

    test_pass.viewport = Vec4i{0,0, viewport.x, viewport.y}
    test_pass.camera.viewport = vec_i2f(viewport)

    test_pass.camera.angle = 0.06 * math.sin(time*0.8)

    camera := &test_pass.camera
    t := hla.hla_get_pointer(triangle)
    move_speed :f32= 3.0
    if get_key(.A) do t.position.x -= move_speed * delta
    else if get_key(.D) do t.position.x += move_speed * delta
    if get_key(.W) do t.position.y += move_speed * delta
    else if get_key(.S) do t.position.y -= move_speed * delta
    
    render_pass_draw(&test_pass)
}