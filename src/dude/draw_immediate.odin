package dude

import gl "vendor:OpenGL"
import "core:log"
import "core:strings"

import "dgl"
import "vendor/fontstash"

ImmediateDrawContext :: struct {
    // These things would be deleted and cleared in the `immediate_clear`.
    immediate_robjs : [dynamic]RenderObject,
    meshes : [dynamic]dgl.Mesh,
    mesh_builder : dgl.MeshBuilder,

    // buffered things
    buffered_type : ImmediateElemType,
    color : Color32,
    texture : u32,
    screen_space : bool,
    material : ^Material,
    order : i32,
}

ImmediateElemType :: enum {
    ScreenMeshP2U2C4, ScreenMeshP2U2, Line,
}

@private
immediate_init :: proc(using ctx: ^ImmediateDrawContext) {
    dgl.mesh_builder_init(&mesh_builder, dgl.VERTEX_FORMAT_P2U2, 64, 64)
    immediate_robjs = make([dynamic]RenderObject)
    meshes = make([dynamic]dgl.Mesh)
}
@private
immediate_release :: proc(using ctx: ^ImmediateDrawContext) {
    dgl.mesh_builder_release(&mesh_builder)
    delete(immediate_robjs)
    delete(meshes)
}

// You should call this when you start to draw immediate objects to prevent that there's no elems in
//  the immediate buffer.
@private
immediate_confirm :: proc(using ctx: ^ImmediateDrawContext) {
    if len(mesh_builder.vertices) <= 0 {
        dgl.mesh_builder_clear(&mesh_builder)
        return
    }
    switch buffered_type {
    case .ScreenMeshP2U2:
        mesh := dgl.mesh_builder_create(mesh_builder)
        append(&meshes, mesh)
        append(&immediate_robjs, 
            RenderObject{ 
                obj = RObjImmediateScreenMesh{mesh=mesh, mode=.Triangle, color=col_u2f(color), texture=texture},
                material = ctx.material,
                ex = {0, 1 if ctx.screen_space else 0, 0,0},
                order = order,
        })
    case .ScreenMeshP2U2C4:
        mesh := dgl.mesh_builder_create(mesh_builder)
        append(&meshes, mesh)
        append(&immediate_robjs, 
            RenderObject{ 
                obj = RObjImmediateScreenMesh{mesh=mesh, mode=.Triangle, texture=ctx.texture},
                ex={1,1 if ctx.screen_space else 0,0,0}, // Use vertex color.
                material = ctx.material,
                order = order,
        })
    case .Line:
        mesh := dgl.mesh_builder_create(mesh_builder, true)
        append(&meshes, mesh)
        append(&immediate_robjs, 
            RenderObject{ 
                obj = RObjImmediateScreenMesh{mesh=mesh, mode=.Lines, color=col_u2f(color), texture=texture},
                material = ctx.material,
                order=order,
        })
    }
}

@private
immediate_clear :: proc(using ctx: ^ImmediateDrawContext) {
    for &mesh in meshes {
        dgl.mesh_delete(&mesh)
    }
    clear(&meshes)
    dgl.mesh_builder_clear(&mesh_builder)
    clear(&immediate_robjs)
}

/*
*------------*(w,h)
|  viewport  |
|            |
*(0,0)-------*
Default texture will be replaced by a default white texture*/
immediate_screen_quad :: proc(pass: ^RenderPass, corner, size: Vec2, color: Color32={255,255,255,255}, texture: u32=0, order: i32=0) {
    ctx := &pass.impl.immediate_draw_ctx
    if _confirm_context(pass, .ScreenMeshP2U2, color, texture, order, true, &rsys.material_default_mesh) {
        dgl.mesh_builder_reset(&ctx.mesh_builder, dgl.VERTEX_FORMAT_P2U2)
    }
    ctx.texture = texture if texture > 0 else rsys.texture_default_white
    mesher_quad_p2u2(&ctx.mesh_builder, size, {0,0}, corner)
}

/*
*------------*(w,h)
|    -iw-    |
|  *------*  |
|  |      || |
|  |      |ih|
|  |      || |
|  *------*  |
|            |
*(0,0)-------*
*/
immediate_screen_quad_9slice :: proc(pass: ^RenderPass, corner,size, inner_size, uv_inner_size: Vec2, color:Color32={255,255,255,255}, texture: u32=0, order:i32=0) {
    ctx := &pass.impl.immediate_draw_ctx
    if _confirm_context(pass, .ScreenMeshP2U2, color, texture, order, true, &rsys.material_default_mesh) {
        dgl.mesh_builder_reset(&ctx.mesh_builder, dgl.VERTEX_FORMAT_P2U2)
    }
    ctx.texture = texture if texture > 0 else rsys.texture_default_white
    
    w_long, w_short := inner_size.x, (size.x - inner_size.x) * 0.5
    h_long, h_short := inner_size.y, (size.y - inner_size.y) * 0.5

    u_long, u_short := uv_inner_size.x, (1-uv_inner_size.x) * 0.5
    v_long, v_short := uv_inner_size.y, (1-uv_inner_size.y) * 0.5

    zero :Vec2: {0,0}
    mesher_quad_p2u2(&ctx.mesh_builder, 
        {w_short, h_short}, zero, corner+{0,0},      
        {0,0}, {u_short, v_short})
    mesher_quad_p2u2(&ctx.mesh_builder,
        {w_long, h_short}, zero, corner+{w_short, 0},
        {u_short,0}, {u_short+u_long, v_short})
    mesher_quad_p2u2(&ctx.mesh_builder, {w_short, h_short}, zero, corner+{w_short+w_long, 0},
        {u_short+u_long, 0}, {1, v_short})

    mesher_quad_p2u2(&ctx.mesh_builder, {w_short, h_long}, zero, corner+{0,h_short},
        {0,v_short}, {u_short, 1-v_short})
    mesher_quad_p2u2(&ctx.mesh_builder, {w_long, h_long}, zero, corner+{w_short,h_short},
        {u_short,v_short}, {u_short+u_long, 1-v_short})
    mesher_quad_p2u2(&ctx.mesh_builder, {w_short, h_long}, zero, corner+{w_short+w_long,h_short},
        {u_short+u_long,v_short}, {1, 1-v_short})

    mesher_quad_p2u2(&ctx.mesh_builder, {w_short, h_short}, zero, corner+{0,h_short+h_long},
        {0,1-v_short}, {u_short,1})
    mesher_quad_p2u2(&ctx.mesh_builder, {w_long, h_short}, zero, corner+{w_short, h_short+h_long},
        {u_short,1-v_short}, {u_short+u_long,1})
    mesher_quad_p2u2(&ctx.mesh_builder, {w_short, h_short}, zero, corner+{w_short+w_long, h_short+h_long},
        {u_short+u_long,1-v_short}, {1,1})
}

immediate_screen_text :: proc(pass: ^RenderPass, text: string, offset: Vec2, size: f32, color:Color={1,1,1,1}, order:i32=0) {
    ctx := &pass.impl.immediate_draw_ctx
    font_atlas := rsys.fontstash_data.atlas
    if _confirm_context(pass, .ScreenMeshP2U2C4, {}, font_atlas, order, true, &rsys.material_default_text) {
        dgl.mesh_builder_reset(&ctx.mesh_builder, dgl.VERTEX_FORMAT_P2U2C4)
    }

    mb := &ctx.mesh_builder
    vstart := dgl.mesh_builder_count_vertex(mb)
    stride := mb.stride
    mesher_text_p2u2c4(mb, text, size, color)
    vend := dgl.mesh_builder_count_vertex(mb)
    v : ^dgl.Vertex8
    for i in vstart..<vend {
        v = auto_cast &mb.vertices[i*cast(int)stride]
        v[0] += offset.x 
        v[1] += offset.y
    }
}

immediate_screen_arrow :: proc(pass: ^RenderPass, from,to : Vec2, width: f32, color:Color32={255,255,255,255}, order:i32=0) {
    ctx := &pass.impl.immediate_draw_ctx
    if _confirm_context(pass, .ScreenMeshP2U2C4, {}, rsys.texture_default_white, order, true, &rsys.material_default_mesh) {
        dgl.mesh_builder_reset(&ctx.mesh_builder, dgl.VERTEX_FORMAT_P2U2C4)
    }
    mesher_arrow_p2u2c4(&ctx.mesh_builder, from,to, width, col_u2f(color))
}

// If the context states are different from the buffered settings, submit the buffered element.
@(private="file")
_confirm_context :: proc(pass: ^RenderPass, type: ImmediateElemType, color: Color32, texture: u32, order: i32, screen_space: bool, material: ^Material) -> bool {
    ctx := &pass.impl.immediate_draw_ctx

    if ctx.buffered_type != type || ctx.color != color || ctx.texture != texture || ctx.order != order || ctx.screen_space != screen_space || ctx.material != material {
        immediate_confirm(ctx)
        ctx.buffered_type = type
        ctx.color = color
        ctx.texture = texture
        ctx.order = order
        ctx.screen_space = screen_space
        ctx.material = material
        return true
    }
    return false
}