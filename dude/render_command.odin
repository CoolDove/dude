package dude


import "dgl"


// ** Render commands
RObjCommand :: union {
    RObjCmdBlend, 
    RObjCmdScissor, 

    RObjCmdAttachColor, 
    RObjCmdAttachDepth, 

    RObjCmdBindFramebuffer, 
    RObjCmdRestoreFramebuffer
}
RObjCmdBlend :: distinct dgl.GlStateBlend
RObjCmdScissor :: struct {
    scissor : Vec4i,
    enable : bool,
}
RObjCmdAttachColor :: struct {
    slot : u32,
    texture : u32,
}
RObjCmdAttachDepth :: struct {
    texture : u32,
}
RObjCmdBindFramebuffer :: struct {
    framebuffer : dgl.FramebufferId
}
RObjCmdRestoreFramebuffer :: struct {
}



rcmd_set_blend :: proc(blend: dgl.GlStateBlend) -> RObjCommand {
    return cast(RObjCmdBlend)blend
}
rcmd_attach_color :: proc(texture: u32, attach_point: u32) -> RObjCommand {
    return RObjCmdAttachColor{attach_point, texture}
}
rcmd_attach_depth :: proc(texture: u32) -> RObjCommand {
    return RObjCmdAttachDepth{texture}
}
rcmd_bind_framebuffer :: proc(fbo: dgl.FramebufferId) -> RObjCommand {
    return RObjCmdBindFramebuffer{fbo}
}
rcmd_restore_framebuffer :: proc() -> RObjCommand {
    return RObjCmdRestoreFramebuffer{}
}

@private
execute_render_command :: proc(pass: ^RenderPass, cmd: RObjCommand) {
    switch cmd in cmd {
    case RObjCmdBlend:
        dgl.state_set_blend(cast(dgl.GlStateBlend)cmd)
    case RObjCmdScissor:
        dgl.state_set_scissor(cmd.scissor, cmd.enable)
    case RObjCmdAttachColor:
        dgl.framebuffer_attach_color(cmd.slot, cmd.texture)
    case RObjCmdAttachDepth:
        dgl.framebuffer_attach_depth(cmd.texture)
    case RObjCmdBindFramebuffer:
        dgl.framebuffer_bind(cmd.framebuffer)
    case RObjCmdRestoreFramebuffer:
        dgl.framebuffer_bind(pass.target)
    }
}