package dgl

import "core:slice"
import "core:mem"
import "core:log"
import gl "vendor:OpenGL"

UniformBlockId :: u32

ubo_create :: proc(size: u32) -> u32 {
    ubo : u32
    gl.GenBuffers(1, &ubo)
    gl.BindBuffer(gl.UNIFORM_BUFFER, ubo)
    gl.BufferData(gl.UNIFORM_BUFFER, auto_cast size, nil, gl.STREAM_DRAW)
    return ubo
}

ubo_release :: proc(ubo: ^UniformBlockId) {
    gl.DeleteBuffers(1, ubo)
    ubo^ = 0
}

ubo_update :: proc {
    ubo_update_with_bytes,
    ubo_update_with_object,
}
ubo_update_with_bytes :: proc(ubo: UniformBlockId, data: []u8) {
    gl.BindBuffer(gl.UNIFORM_BUFFER, ubo)
    gl.BufferSubData(gl.UNIFORM_BUFFER, 0, len(data), raw_data(data))
}
ubo_update_with_object :: proc(ubo: UniformBlockId, ptr: ^$T) {
    ubo_update(ubo, slice.from_ptr(cast(^u8)ptr, size_of(T)))
}

ubo_bind :: proc(ubo: UniformBlockId, slot: u32) {
    gl.BindBufferBase(gl.UNIFORM_BUFFER, slot, ubo)
}

