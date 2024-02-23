package dude

import "core:log"
import "core:math"
import "core:slice"
import "dgl"

import hla "collections/hollow_array"

// Reserved up to 8, when you want to make your own custom uniform block, the slot should be greater 
//  than 8.
UNIFORM_BLOCK_SLOT_CAMERA :: 0

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
    anchor : dgl.UniformLocVec2,
    size : dgl.UniformLocVec2,
}

// TODO: Rename RenderTransform to Transform after the old Transform can be removed.
RenderTransform :: struct {
    position : Vec2,
    scale : Vec2, // For sprite this is size.
    angle : f32,
    order : i32, // Objects with smaller order would be drawn earlier.
}

RObj :: union {
    RObjMesh, RObjSprite, RObjHandle, RObjCustom, RObjCommand,
}

RObjMesh :: struct {
    mesh : dgl.Mesh,
    mode : MeshMode,
    utable : UniformTableGeneral,
}
MeshMode :: enum {
    Triangle, Lines, LineStrip,
}
RObjHandle :: hla.HollowArrayHandle(RenderObject) 
RObjSprite :: struct { // A sprite in 2D world space.
	color : Color,
    texture : u32,
    anchor : Vec2, // [0,1]
    size : Vec2, // This differs from scale in transform.
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

render_pass_add_object :: proc(pass: ^RenderPass, obj: RObj, material: ^Material=nil,
order: i32=0, position:Vec2={0,0}, scale:Vec2={1,1}, angle:f32=0) -> RObjHandle {
    return hla.hla_append(&pass.robjs, 
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

render_pass_remove_object :: proc(obj: RObjHandle) {
    hla.hla_remove_handle(obj)
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

    // ** Sort all the render objects.
    robj_idx : int
    clear(&pass.robjs_sorted)
    for obj in hla.hla_ite(&pass.robjs, &robj_idx) {
        append(&pass.robjs_sorted, obj)
    }
    slice.sort_by(pass.robjs_sorted[:], proc(i,j : ^RenderObject) -> bool {
        return i.order < j.order
    })

    for obj in pass.robjs_sorted {
        if robj_mesh, ok := obj.obj.(RObjMesh); ok {
            material := obj.material if (obj.material != nil) else &rsys.material_default_mesh
            shader := material.shader
            dgl.material_upload(material.mat)
            uniform_transform(shader.utable_transform, obj.position, obj.scale, obj.angle)
                
            switch robj_mesh.mode {
            case .Triangle:
                dgl.draw_mesh(robj_mesh.mesh)
            case .Lines:
                dgl.mesh_bind(&robj_mesh.mesh)
                dgl.draw_lines(robj_mesh.mesh.vertex_count)
            case .LineStrip:
                dgl.mesh_bind(&robj_mesh.mesh)
                dgl.draw_linestrip(robj_mesh.mesh.vertex_count)
            }
        } else if robj_sprite, ok := obj.obj.(RObjSprite); ok {
            material := obj.material if (obj.material != nil) else &rsys.material_default_sprite
            shader := material.shader
            dgl.material_upload(material.mat)
            uniform_transform(material.shader.utable_transform, obj.position, obj.scale, obj.angle)
            // TODO: 16 is a temporary magic number, only works when you use less than 16 texture slots.
            dgl.uniform_set_texture(shader.utable_general.texture, robj_sprite.texture, 16)
            dgl.uniform_set(shader.utable_sprite.anchor, robj_sprite.anchor)
            dgl.uniform_set(shader.utable_sprite.size, robj_sprite.size)
            dgl.uniform_set(shader.utable_general.color, robj_sprite.color)

            dgl.draw_mesh(rsys.mesh_unit_quad)
        } else if robj_cmd, ok := obj.obj.(RObjCommand); ok {
            execute_render_command(robj_cmd)
        } else if robj_custom, ok := obj.obj.(RObjCustom); ok {
            // TODO: Write a better one.
            if robj_custom != nil do robj_custom()
        } else {
            log.errorf("Render: Render object type not supported, currently we can only render mesh.")
        }
    }
    
    dgl.framebuffer_bind_default()
    
}

RObjCommand :: union {
    dgl.GlStateBlend, RObjCmdRenderTarget,
}
RObjCmdRenderTarget :: struct {
    texture : u32,
    attach_point: u32,
}

// ** Render object commands
robjcmd_set_blend :: proc(blend: dgl.GlStateBlend) -> RObjCommand {
    return blend
}
robjcmd_attach_render_texture :: proc(texture: u32, attach_point: u32) -> RObjCommand {
    return RObjCmdRenderTarget{texture, attach_point}
}

@(private="file")
execute_render_command :: proc(cmd: RObjCommand) {
    switch cmd in cmd {
    case dgl.GlStateBlend:
        dgl.state_set_blend(cmd)
    case RObjCmdRenderTarget:
        assert(false, "RenderObject: Command RenderTarget is not supported now.")
        // dgl.framebuffer_attach_color(cmd.attach_point, cmd.texture)
    }
}