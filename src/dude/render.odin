package dude

import "core:log"
import "core:math"
import "core:slice"
import "dgl"

import hla "collections/hollow_array"
import "vendor/fontstash"

// What's the `ex` in RenderObject?
//  ex.x: Vertex color multiplier, 0 to disable vertex color, 1 to use.
//  ex.y: ......


// Reserved up to 8, when you want to make your own custom uniform block, the slot should be greater 
//  than 8.
UNIFORM_BLOCK_SLOT_CAMERA :: 0
UNIFORM_BLOCK_SLOT_DUDE :: 1

// You cannot use more than 16 textures in a material. Cuz dude's render system may want to set the 
//  texture after a material is applied, it'll use a texture slot began from 16.
MAX_TEXTURES_FOR_MATERIAL :: 16

RenderPass :: struct {
    // Differs from the viewport in camera, which is for transform calculation. This one defines how
    //  you output to the framebuffer. (This is what passed into gl.Viewport(...) before rendering)
    viewport : Vec4i,
	target : dgl.FramebufferId, // 0 means the default framebuffer.
	camera : RenderCamera,

    clear : RenderClear,
    blend : dgl.GlStateBlend,

	robjs :  hla.HollowArray(RenderObject),

    using impl : RenderPassImplData,
}

RenderDataDude :: struct {
    time_total : f32,
    padding : f32,
}

// Implementation necessary data, which you cannot access from outside.
@(private="file")
RenderPassImplData :: struct {
    // Immediate draw
    immediate_draw_ctx : ImmediateDrawContext,

    robjs_sorted : [dynamic]^RenderObject, // This shall be sorted everytime you draw the pass.
    camera_ubo : dgl.UniformBlockId,
}

// RenderObject doesn't allocate anything.
RenderObject :: struct {
    using transform : RenderTransform, // Transform is not used for screen space render objects (mesh and sprite) for now.
    material : ^Material,
	obj : RObj,
    order : i32, // Objects with smaller order would be drawn earlier.
    ex : RenderObjectEx, // x: vertex color factor.
}
RenderObjectEx :: struct {
    vertex_color_on : f32,
    screen_space : f32,
    padding1 : f32,
    padding2 : f32,
}

UniformTableTransform :: struct {
    position : dgl.UniformLocVec2 `uniform:"transform_position"`,
    scale : dgl.UniformLocVec2 `uniform:"transform_scale"`,
    angle : dgl.UniformLocF32 `uniform:"transform_angle"`,
}
UniformTableGeneral :: struct {
    color : dgl.UniformLocVec4 `uniform:"color"`,
    texture : dgl.UniformLocTexture `uniform:"main_texture"`,
    ex : dgl.UniformLocVec4,
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
}

RObj :: union {
    RObjMesh, RObjMeshScreen, 
    RObjImmediateScreenMesh,
    RObjSprite, RObjSpriteScreen, 
    RObjTextMesh,
    RObjHandle, RObjCustom, RObjCommand,
}

RObjMesh :: struct {
    mesh : dgl.Mesh,
    ex : Vec4, // 0 means no vertex color used, 1 means full.
    mode : MeshMode,
}
RObjImmediateScreenMesh :: struct {
    mesh : dgl.Mesh,
    mode : MeshMode,
	color : Color,
    texture : u32,
}
RObjMeshScreen :: distinct RObjMesh

RObjTextMesh :: struct {
    text_mesh : dgl.Mesh,
    color : Color,
}
RObjTextMeshScreen :: distinct RObjTextMesh

// NOTE: When you create a `Lines` mode mesh, the indices buffer is not used.
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
RObjSpriteScreen :: distinct RObjSprite
RObjCustom :: #type proc()

RenderCamera :: struct {
    using data : CameraUniformData,
}
CameraUniformData :: struct {
    position : Vec2,
    angle : f32,
    size : f32, // 1 unit in world space takes 2*size pixels on screen(viewport).
    viewport : Vec2,
}

RenderSystem :: struct {
    temp_mesh_builder : dgl.MeshBuilder,
    fontstash_context : fontstash.FontContext,
    fontstash_data : FontstashData,

    // Builtin resources
    mesh_unit_quad : dgl.Mesh,

    shader_default_mesh : Shader,
    material_default_mesh : Material,

    shader_default_sprite : Shader,
    material_default_sprite : Material,

    shader_default_text : Shader,
    material_default_text : Material,

    shader_default_screen_mesh : Shader,
    material_default_screen_mesh : Material,

    shader_default_screen_sprite : Shader,
    material_default_screen_sprite : Material,

    texture_default_white : dgl.TextureId,
    texture_default_black : dgl.TextureId,

    render_data_dude : RenderDataDude,
    render_data_dude_ubo : dgl.UniformBlockId,

    fontid_unifont : int,
}

FontstashData :: struct {
    atlas : dgl.TextureId,
}

rsys : RenderSystem

render_init :: proc() {
    using rsys

    // Textures
    texture_default_white = dgl.texture_create_with_color(4,4, {255,255,255,255})
    texture_default_black = dgl.texture_create_with_color(4,4, {0,0,0,255})

    render_data_dude_ubo = dgl.ubo_create(size_of(render_data_dude))
    dgl.ubo_bind(render_data_dude_ubo, UNIFORM_BLOCK_SLOT_DUDE)

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

    {using shader_default_text
        shader_init(&shader_default_text, 
            #load("./resources/default_mesh.vert"),
            #load("./resources/default_text.frag"))
        material_init(&material_default_text, &shader_default_text)
    }

    {using shader_default_screen_mesh
        shader_init(&shader_default_screen_mesh, 
            #load("./resources/default_screen_mesh.vert"),
            #load("./resources/default_mesh.frag"))
        material_init(&material_default_screen_mesh, &shader_default_screen_mesh)
        material_set_vec4(&material_default_screen_mesh,  utable_general.color, {1,1,1,1})
        material_set_texture(&material_default_screen_mesh, utable_general.texture, rsys.texture_default_white)
    }

    {using shader_default_screen_sprite
        shader_init(&shader_default_screen_sprite, 
            #load("./resources/default_screen_sprite.vert"),
            #load("./resources/default_sprite.frag"))
        material_init(&material_default_screen_sprite, &shader_default_screen_sprite)
        material_set_vec4(&material_default_screen_sprite,  utable_general.color, {1,1,1,1})
        material_set_texture(&material_default_screen_sprite, utable_general.texture, rsys.texture_default_white)
    }

    // Meshes
    {using dgl
        mesh_builder_init(&temp_mesh_builder, VERTEX_FORMAT_P2U2)
        mesher_quad(&temp_mesh_builder, {1,1}, {0,0})
        mesh_unit_quad = mesh_builder_create(temp_mesh_builder)
    }

    // Fontstash
    atlas_size :int= 512
    fontstash.Init(&rsys.fontstash_context, atlas_size, atlas_size, .TOPLEFT)
    rsys.fontstash_context.userData = &rsys
    // FIXME: The texture should be a single channel texture.
    rsys.fontstash_data.atlas = dgl.texture_create_empty(auto_cast atlas_size, auto_cast atlas_size)
    rsys.fontid_unifont = fontstash.AddFontMem(&rsys.fontstash_context, "unifont", #load("./resources/unifont.ttf"), false)
    rsys.fontstash_context.callbackResize = _fontstash_callback_resize
    rsys.fontstash_context.callbackUpdate = _fontstash_callback_update
    _fontstash_callback_update(nil,{},nil)

}

render_release :: proc() {
    using rsys

    dgl.texture_delete(&rsys.fontstash_data.atlas)
    fontstash.Destroy(&fontstash_context)

    dgl.mesh_delete(&mesh_unit_quad)

    material_release(&material_default_mesh)
    shader_release(&shader_default_mesh)

    material_release(&material_default_sprite)
    shader_release(&shader_default_sprite)

    material_release(&material_default_screen_mesh)
    shader_release(&shader_default_screen_mesh)

    material_release(&material_default_screen_sprite)
    shader_release(&shader_default_screen_sprite)
    
    dgl.mesh_builder_release(&temp_mesh_builder)
    dgl.ubo_release(&render_data_dude_ubo)
}

render_update :: proc(time_total : f32) {
    rsys.render_data_dude.time_total = time_total
    dgl.ubo_update_with_object(rsys.render_data_dude_ubo, &rsys.render_data_dude)
}

render_pass_init :: proc(pass: ^RenderPass, viewport: Vec4i) {
	pass.robjs = hla.hla_make(RenderObject, 128)
	pass.robjs_sorted = make([dynamic]^RenderObject)

    pass.camera_ubo = dgl.ubo_create(size_of(CameraUniformData))
    pass.clear.mask = {.Color,.Depth,.Stencil}

    pass.camera.viewport = vec_i2f(Vec2i{viewport.z, viewport.w})
    pass.camera.size = 32
    pass.viewport = viewport

    pass.blend = dgl.GlStateBlendSimp{false, .FUNC_ADD, .SRC_ALPHA, .ONE_MINUS_SRC_ALPHA}

    immediate_init(&pass.immediate_draw_ctx)
}
render_pass_release :: proc(pass: ^RenderPass) {
    immediate_release(&pass.immediate_draw_ctx)

    hla.hla_delete(&pass.robjs)
    if len(pass.robjs_sorted) > 0 {
        delete(pass.robjs_sorted)
	    pass.robjs_sorted = nil
    }

    if pass.camera_ubo != 0 {
        dgl.ubo_release(&pass.camera_ubo)
    }
}

render_pass_add_object :: proc(pass: ^RenderPass, obj: RObj, material: ^Material=nil,
order: i32=0, position:Vec2={0,0}, scale:Vec2={1,1}, angle:f32=0, vertex_color_on:=false) -> RObjHandle {
    return hla.hla_append(&pass.robjs, 
        RenderObject{ 
            obj = obj, 
            material = material,
            order = order,
            ex = {1,0,0,0},
            transform = {
                position=position,
                scale=scale,
                angle=angle,
            },
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
    dgl.state_set_blend(pass.blend)

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

    immediate_confirm(&pass.immediate_draw_ctx); defer immediate_clear(&pass.immediate_draw_ctx)
    for &obj in pass.immediate_draw_ctx.immediate_robjs {
        append(&pass.robjs_sorted, &obj)
    }

    slice.sort_by(pass.robjs_sorted[:], proc(i,j : ^RenderObject) -> bool {
        return i.order < j.order
    })

    for obj in pass.robjs_sorted {
        switch &robj in obj.obj {
        case RObjImmediateScreenMesh: 
            _draw_immediate_screen_mesh(&robj, obj)
        case RObjMeshScreen: 
            _draw_mesh(transmute(^RObjMesh)&robj, obj, &rsys.material_default_screen_mesh)
        case RObjMesh:
            _draw_mesh(&robj, obj, &rsys.material_default_mesh)
        case RObjSpriteScreen: 
            _draw_sprite(transmute(^RObjSprite)&robj, obj, &rsys.material_default_screen_sprite)
        case RObjSprite:
            _draw_sprite(&robj, obj, &rsys.material_default_sprite)
        case RObjTextMesh:
            _draw_text(&robj, obj)
        case RObjHandle:
            log.errorf("Render: Render object type not supported.")
        case RObjCommand:
            execute_render_command(robj)
        case RObjCustom:
            if robj != nil do robj()
        }
    }
    
    dgl.framebuffer_bind_default()
}

@(private="file")
_draw_immediate_screen_mesh :: #force_inline proc(robj: ^RObjImmediateScreenMesh, obj: ^RenderObject) {
    material := &rsys.material_default_screen_mesh
    shader := material.shader
    dgl.material_upload(material.mat)
    uniform_transform(shader.utable_transform, {0,0}, {1,1}, 0,)
    dgl.uniform_set_vec4(shader.utable_general.ex, transmute(Vec4)obj.ex)

    dgl.uniform_set(shader.utable_general.color, robj.color)
    // TODO: 16 is a temporary magic number, only works when you use less than 16 texture slots.
    dgl.uniform_set_texture(shader.utable_general.texture, robj.texture, MAX_TEXTURES_FOR_MATERIAL)
        
    switch robj.mode {
    case .Triangle:
        dgl.draw_mesh(robj.mesh)
    case .Lines:
        dgl.mesh_bind(&robj.mesh)
        dgl.draw_lines(robj.mesh.vertex_count)
    case .LineStrip:
        dgl.mesh_bind(&robj.mesh)
        dgl.draw_linestrip(robj.mesh.vertex_count)
    }
}

@(private="file")
_draw_mesh :: #force_inline proc(robj: ^RObjMesh, obj: ^RenderObject, default_material : ^Material) {
    material := obj.material if (obj.material != nil) else default_material
    shader := material.shader
    dgl.material_upload(material.mat)
    uniform_transform(shader.utable_transform, obj.position, obj.scale, obj.angle)
    dgl.uniform_set_vec4(shader.utable_general.ex, transmute(Vec4)obj.ex)
        
    switch robj.mode {
    case .Triangle:
        dgl.draw_mesh(robj.mesh)
    case .Lines:
        dgl.mesh_bind(&robj.mesh)
        dgl.draw_lines(robj.mesh.vertex_count)
    case .LineStrip:
        dgl.mesh_bind(&robj.mesh)
        dgl.draw_linestrip(robj.mesh.vertex_count)
    }
}

@(private="file")
_draw_sprite :: #force_inline proc(robj: ^RObjSprite, obj: ^RenderObject, default_material: ^Material) {
    material := obj.material if (obj.material != nil) else default_material
    shader := material.shader
    dgl.material_upload(material.mat)
    uniform_transform(material.shader.utable_transform, obj.position, obj.scale, obj.angle)
    dgl.uniform_set_vec4(shader.utable_general.ex, transmute(Vec4)obj.ex)

    dgl.uniform_set(shader.utable_sprite.anchor, robj.anchor)
    dgl.uniform_set(shader.utable_sprite.size, robj.size)
    dgl.uniform_set(shader.utable_general.color, robj.color)
    dgl.uniform_set_texture(shader.utable_general.texture, robj.texture, MAX_TEXTURES_FOR_MATERIAL)

    dgl.draw_mesh(rsys.mesh_unit_quad)
}

@(private="file")
_draw_text :: #force_inline proc(robj: ^RObjTextMesh, obj: ^RenderObject) {
    material := obj.material if (obj.material != nil) else &rsys.material_default_text
    shader := material.shader
    dgl.material_upload(material.mat)
    uniform_transform(shader.utable_transform, obj.position, obj.scale, obj.angle)
    dgl.uniform_set_vec4(shader.utable_general.ex, transmute(Vec4)obj.ex)

    dgl.uniform_set(shader.utable_general.color, robj.color)
    dgl.uniform_set_texture(shader.utable_general.texture, rsys.fontstash_data.atlas, MAX_TEXTURES_FOR_MATERIAL)
        
    dgl.draw_mesh(robj.text_mesh)
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

// ** Text rendering
@(private="file")
_fontstash_callback_resize :: proc(data: rawptr, w, h: int) {
    fst := &rsys.fontstash_context
    dgl.texture_update(rsys.fontstash_data.atlas, auto_cast fst.width, auto_cast fst.height, fst.textureData, .Red)
}
@(private="file")
_fontstash_callback_update :: proc(data: rawptr, dirtyRect: [4]f32, textureData: rawptr) {
    // Temporary: Just ignore the dirty rect, update the whole texture.
    fst := &rsys.fontstash_context
    dgl.texture_update(rsys.fontstash_data.atlas, auto_cast fst.width, auto_cast fst.height, fst.textureData, .Red)
}