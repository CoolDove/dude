package dgl

import "core:mem"
import "core:log"
import gl "vendor:OpenGL"

UniformBlock :: u32

ubo_create :: proc(size: u32) -> u32 {
    ubo : u32
    gl.GenBuffers(1, &ubo)
    gl.BindBuffer(gl.UNIFORM_BUFFER, ubo)
    gl.BufferData(gl.UNIFORM_BUFFER, auto_cast size, nil, gl.STREAM_DRAW)
    return ubo
}

ubo_release :: proc(ubo: ^UniformBlock) {
    gl.DeleteBuffers(1, ubo)
    ubo^ = 0
}

ubo_update :: proc(ubo: UniformBlock, data: []u8) {
    gl.BindBuffer(gl.UNIFORM_BUFFER, ubo)
    gl.BufferSubData(gl.UNIFORM_BUFFER, 0, len(data), raw_data(data))
}
