package buffer

import "core:log"

import gl "vendor:OpenGL"
import dgl "../"

GLObject :: dgl.GLObject

BufferUsage :: enum u32 {
    STREM_DRAW      = gl.STREAM_DRAW,
    STREAM_READ     = gl.STREAM_READ,
    STREAM_COPY     = gl.STREAM_COPY,
    STATIC_DRAW     = gl.STATIC_DRAW,
    STATIC_READ     = gl.STATIC_READ,
    STATIC_COPY     = gl.STATIC_COPY,
    DYNAMIC_DRAW    = gl.DYNAMIC_DRAW,
    DYNAMIC_READ    = gl.DYNAMIC_READ,
    DYNAMIC_COPY    = gl.DYNAMIC_COPY,
}

BuffferType :: enum u32 {
    VERTEX_BUFFER             = gl.ARRAY_BUFFER,
    COPY_READ_BUFFER          = gl.COPY_READ_BUFFER,
    COPY_WRITE_BUFFER         = gl.COPY_WRITE_BUFFER,
    DRAW_INDIRECT_BUFFER      = gl.DRAW_INDIRECT_BUFFER,
    INDEX_BUFFER              = gl.ELEMENT_ARRAY_BUFFER,
    PIXEL_PACK_BUFFER         = gl.PIXEL_PACK_BUFFER,
    PIXEL_UNPACK_BUFFER       = gl.PIXEL_UNPACK_BUFFER,
    TEXTURE_BUFFER            = gl.TEXTURE_BUFFER,
    UNIFORM_BUFFER            = gl.UNIFORM_BUFFER,
    TRANSFORM_FEEDBACK_BUFFER = gl.TRANSFORM_FEEDBACK_BUFFER,
}

Buffer :: struct {
    using obj : GLObject,
    immutable : bool,
    mapped : bool,
    size : u32,
    usage : BufferUsage,
}

create :: proc () -> Buffer {
    buffer : Buffer
	gl.GenBuffers(1, &buffer.native_id)
    return buffer
}

destroy :: proc (buffers: ..^Buffer) {
    count := cast(i32)len(buffers)
    ids := make([dynamic]u32, 0, count)
    for b, ind in buffers {
        append(&ids, b.native_id)
    }
    gl.DeleteBuffers(count, raw_data(ids))
}

store :: proc(buffer : ^Buffer, #any_int byte_size: u32, data: rawptr, usage: BufferUsage, immutable := false) {
    buffer.immutable = immutable
    buffer.size = byte_size
    if immutable {
        gl.NamedBufferStorage(buffer.native_id, cast(int)byte_size, data, cast(u32)usage)
    } else {
        gl.NamedBufferData(buffer.native_id, cast(int)byte_size, data, cast(u32)usage)
    }
}

set :: proc(buffer: ^Buffer, offset, size: int, data: rawptr) {
    if buffer.immutable {
        log.errorf("DGL Error: Target buffer is immutable, cannot be `set`.")
        return;
    }
    gl.NamedBufferSubData(buffer.native_id, offset, size, data)
}
reset :: proc(buffer: ^Buffer, offset:int= 0, size:int= 0 , data: rawptr = nil) {
    if buffer.immutable {
        log.errorf("DGL Error: Target buffer is immutable, cannot be `reset`.")
        return;
    }
    store(buffer, 0, nil, buffer.usage, buffer.immutable)
    if data != nil {
        set(buffer, offset, size, data)
    }
}

map_data :: proc(buffer: ^Buffer, allocator := context.allocator) -> rawptr {
    return nil
}

upmap_data :: proc(buffer: ^Buffer) {

}