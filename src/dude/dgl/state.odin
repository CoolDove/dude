package dgl

import gl "vendor:OpenGL"

GlStateViewport :: Vec4i

GlStateBlend :: union {
    GlStateBlendSimp, GlStateBlendEx,
}
GlStateBlendSimp :: struct {
    enable : bool,
    equation : GlBlendEquation,
    src,dst : GlBlendFactor,
}
GlStateBlendEx :: struct {
    enable : bool,
    src_rgb,dst_rgb : GlBlendFactor,
    src_alpha,dst_alpha : GlBlendFactor,
    equation_rgb,equation_alpha : GlBlendEquation,
}

GlBlendFactor :: enum i32 {
    ZERO                        = 0,
    ONE                         = 1,
    SRC_COLOR                   = 0x0300,
    ONE_MINUS_SRC_COLOR         = 0x0301,
    DST_COLOR                   = 0x0306,
    ONE_MINUS_DST_COLOR         = 0x0307,
    SRC_ALPHA                   = 0x0302,
    ONE_MINUS_SRC_ALPHA         = 0x0303,
    DST_ALPHA                   = 0x0304,
    ONE_MINUS_DST_ALPHA         = 0x0305,
    CONSTANT_COLOR              = 0x8001,
    ONE_MINUS_CONSTANT_COLOR    = 0x8002,
    CONSTANT_ALPHA              = 0x8003,
    ONE_MINUS_CONSTANT_ALPHA    = 0x8004,
    SRC_ALPHA_SATURATE          = 0x0308,
    SRC1_COLOR                  = 0x88F9,
    ONE_MINUS_SRC1_COLOR        = 0x88FA,
    SRC1_ALPHA                  = 0x8589,
    ONE_MINUS_SRC1_ALPHA        = 0x88FB,
}
GlBlendEquation :: enum i32 {
    FUNC_ADD                = 0x8006,
    FUNC_SUBTRACT           = 0x800A,
    FUNC_REVERSE_SUBTRACT   = 0x800B,
    MIN                     = 0x8007,
    MAX                     = 0x8008,
}

state_get_viewport :: proc() -> GlStateViewport {
    vp : GlStateViewport
    gl.GetIntegerv(gl.VIEWPORT, auto_cast &vp)
    return vp
}

state_set_viewport :: proc(viewport: GlStateViewport) {
    gl.Viewport(viewport.x, viewport.y, viewport.z, viewport.w)
}

state_get_blend_simple :: proc() -> GlStateBlend {
    blend : GlStateBlendSimp
    gl.GetBooleanv(gl.BLEND, &blend.enable)
    gl.GetIntegerv(gl.BLEND_SRC, auto_cast &blend.src)
    gl.GetIntegerv(gl.BLEND_DST, auto_cast &blend.dst)
    gl.GetIntegerv(gl.BLEND_EQUATION, auto_cast &blend.equation)
    return blend
}
state_get_blend_ex :: proc() -> GlStateBlend {
    blend : GlStateBlendEx
    gl.GetBooleanv(gl.BLEND, &blend.enable)
    gl.GetIntegerv(gl.BLEND_SRC_RGB, auto_cast &blend.src_rgb)
    gl.GetIntegerv(gl.BLEND_DST_RGB, auto_cast &blend.dst_rgb)
    gl.GetIntegerv(gl.BLEND_SRC_ALPHA, auto_cast &blend.src_alpha)
    gl.GetIntegerv(gl.BLEND_DST_ALPHA, auto_cast &blend.dst_alpha)
    gl.GetIntegerv(gl.BLEND_EQUATION_RGB, auto_cast &blend.equation_rgb)
    gl.GetIntegerv(gl.BLEND_EQUATION_ALPHA, auto_cast &blend.equation_alpha)
    return blend
}
state_set_blend :: proc(blend: GlStateBlend) {
    switch b in blend {
    case GlStateBlendEx:
        if b.enable do gl.Enable(gl.BLEND)
        else do gl.Disable(gl.BLEND)
        gl.BlendEquationSeparate(
            transmute(u32)b.equation_rgb,
            transmute(u32)b.equation_alpha)
        gl.BlendFuncSeparate(
            transmute(u32)b.src_rgb,
            transmute(u32)b.dst_rgb,
            transmute(u32)b.src_alpha,
            transmute(u32)b.dst_alpha)
    case GlStateBlendSimp:
        if b.enable do gl.Enable(gl.BLEND)
        else do gl.Disable(gl.BLEND)
        gl.BlendEquation(transmute(u32)b.equation)
        gl.BlendFunc(transmute(u32)b.src, transmute(u32)b.dst)
    }
}