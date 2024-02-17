package dgl

import gl "vendor:OpenGL"

GlStateViewport :: Vec4i

GlStateBlend :: union {
    GlStateBlendSimp, GlStateBlendEx,
}
GlStateBlendSimp :: struct {
    enable : bool,
    equation : i32,
    src,dst : i32,
}
GlStateBlendEx :: struct {
    enable : bool,
    src_rgb,dst_rgb : i32,
    src_alpha,dst_alpha : i32,
    equation_rgb,equation_alpha : i32,
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
    gl.GetIntegerv(gl.BLEND_SRC, &blend.src)
    gl.GetIntegerv(gl.BLEND_DST, &blend.dst)
    gl.GetIntegerv(gl.BLEND_EQUATION, &blend.equation)
    return blend
}
state_get_blend_ex :: proc() -> GlStateBlend {
    blend : GlStateBlendEx
    gl.GetBooleanv(gl.BLEND, &blend.enable)
    gl.GetIntegerv(gl.BLEND_SRC_RGB, &blend.src_rgb)
    gl.GetIntegerv(gl.BLEND_DST_RGB, &blend.dst_rgb)
    gl.GetIntegerv(gl.BLEND_SRC_ALPHA, &blend.src_alpha)
    gl.GetIntegerv(gl.BLEND_DST_ALPHA, &blend.dst_alpha)
    gl.GetIntegerv(gl.BLEND_EQUATION_RGB, &blend.equation_rgb)
    gl.GetIntegerv(gl.BLEND_EQUATION_ALPHA, &blend.equation_alpha)
    return blend
}
state_set_blend :: proc(blend: GlStateBlend) {
    switch b in blend {
    case GlStateBlendEx:
        if b.enable do gl.Enable(gl.BLEND)
        else do gl.Disable(gl.BLEND)
        gl.BlendEquationSeparate(
            auto_cast b.equation_rgb,
            auto_cast b.equation_alpha)
        gl.BlendFuncSeparate(
            auto_cast b.src_rgb,
            auto_cast b.dst_rgb,
            auto_cast b.src_alpha,
            auto_cast b.dst_alpha)
    case GlStateBlendSimp:
        if b.enable do gl.Enable(gl.BLEND)
        else do gl.Disable(gl.BLEND)
        gl.BlendEquation(auto_cast b.equation)
        gl.BlendFunc(auto_cast b.src, auto_cast b.dst)
    }
}