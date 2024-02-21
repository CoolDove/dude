package dgl

import gl "vendor:OpenGL"

FramebufferId :: distinct u32

FRAMEBUFFER_DEFAULT :FramebufferId: 0

framebuffer_create :: proc() -> FramebufferId {
    id : u32
    gl.GenFramebuffers(1, &id)
    return auto_cast id
}
framebuffer_destroy :: proc(fbo : FramebufferId) {
    fbo := fbo
    gl.DeleteFramebuffers(1, auto_cast &fbo)
}



framebuffer_current :: proc() -> FramebufferId {
    current : i32
    gl.GetIntegerv(gl.DRAW_FRAMEBUFFER_BINDING, &current)
    assert(current != -1)
    return auto_cast (cast(u32)current)
}

framebuffer_bind_default :: proc() {
    gl.BindFramebuffer(gl.FRAMEBUFFER, 0)
}

framebuffer_is_ready :: proc(fbo : FramebufferId) -> bool {
    current : i32
    gl.GetIntegerv(gl.FRAMEBUFFER_BINDING, &current)
    gl.BindFramebuffer(gl.FRAMEBUFFER, auto_cast fbo)
    if gl.CheckFramebufferStatus(gl.FRAMEBUFFER) == gl.FRAMEBUFFER_COMPLETE {
        gl.BindFramebuffer(gl.FRAMEBUFFER, cast(u32)current)
        return true
    }
    gl.BindFramebuffer(gl.FRAMEBUFFER, cast(u32)current)
    return false
}

framebuffer_bind :: #force_inline proc(fbo : FramebufferId) {
    gl.BindFramebuffer(gl.FRAMEBUFFER, auto_cast fbo)
}
framebuffer_attach_color :: proc(attach_point: u32, texture: u32) {
    assert(attach_point < 33, "DglFramebuffer: attach point out of range.")
    // gl.BindTexture(gl.TEXTURE_2D, texture)
    gl.FramebufferTexture2D(gl.FRAMEBUFFER, cast(u32)(gl.COLOR_ATTACHMENT0 + attach_point), gl.TEXTURE_2D, texture, 0)
}
framebuffer_attach_depth :: proc(texture: u32) {
    gl.BindTexture(gl.TEXTURE_DEPTH, texture)
    gl.FramebufferTexture2D(gl.FRAMEBUFFER, cast(u32)(gl.DEPTH_ATTACHMENT), gl.TEXTURE_2D, texture, 0)
}
framebuffer_attach_stencil :: proc(texture: u32) {
    gl.BindTexture(gl.TEXTURE_2D, texture)
    gl.FramebufferTexture2D(gl.FRAMEBUFFER, cast(u32)(gl.STENCIL_ATTACHMENT), gl.TEXTURE_2D, texture, 0)
}
framebuffer_attach_depth_stencil :: proc(texture: u32) {
    gl.BindTexture(gl.TEXTURE_2D, texture)
    gl.FramebufferTexture2D(gl.FRAMEBUFFER, cast(u32)(gl.DEPTH_STENCIL_ATTACHMENT), gl.TEXTURE_2D, texture, 0)
}
framebuffer_dettach_color :: proc(attach_point: u32) {
    gl.FramebufferTexture2D(gl.FRAMEBUFFER, cast(u32)(gl.COLOR_ATTACHMENT0 + attach_point), gl.TEXTURE_2D, 0, 0)
}


ClearMasks :: bit_set[ClearMask]
ClearMask :: enum u32 {
    Color = 1,
    Depth = 1<<2,
    Stencil = 1<<3,
}
framebuffer_clear :: proc(mask: ClearMasks, color: Vec4={}, depth: f64=0, stencil: i32=0) {
    clear_bit : u32
    if .Color in mask {
        clear_bit |= gl.COLOR_BUFFER_BIT
        gl.ClearColor(color.r,color.g,color.b,color.a)
    }
    if .Depth in mask {
        clear_bit |= gl.DEPTH_BUFFER_BIT
        gl.ClearDepth(depth)
    } 
    if .Stencil in mask {
        clear_bit |= gl.STENCIL_BUFFER_BIT
        gl.ClearStencil(stencil)
    } 
    gl.Clear(clear_bit)
}
