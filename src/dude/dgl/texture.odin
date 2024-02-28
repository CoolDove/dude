package dgl

import "core:strings"
import "core:c/libc"
import "core:log"

import "vendor:sdl2"
import "vendor:stb/image"
import gl "vendor:OpenGL"


Image :: struct {
    size: Vec2i,
    channels : u32,
    data: rawptr,
}

Texture :: struct {
    size : Vec2i,
    id : TextureId, 
}

TextureId :: u32

Color32 :: distinct [4]u8

TextureType :: enum {
    RGBA, Red,
}


image_load :: proc (path: string) -> Image {
    width, height, channels : libc.int
    data := image.load(strings.clone_to_cstring(path, context.temp_allocator), 
        &width, &height, &channels, 4)

    if data == nil {
        log.errorf("Texture: Failed to load image: {}", path)
        return Image{}
    }
    return Image{{width, height}, cast(u32)channels, data}
}

image_from_mem :: proc(data: []byte) -> Image {
    width, height, channels : libc.int
    data_ := image.load_from_memory(raw_data(data), cast(i32)len(data), &width, &height, &channels, 4)
    if data_ == nil {
        log.errorf("Texture: Failed to load image from memory: {}", data)
        return Image{}
    }
    return Image{{width, height}, cast(u32)channels, data_}
}

image_free :: proc (img: ^Image) {
    image.image_free(img.data)
    img.data = nil
}

texture_load :: proc {
    texture_load_by_path,
    texture_load_from_mem,
}

texture_load_from_mem :: proc(data: []byte, gen_mipmap := false) -> Texture {
    img := image_from_mem(data)
    if img.data == nil do return Texture{}// Failed to load texture.
    defer image_free(&img)

    tex : u32
    gl.GenTextures(1, &tex)
    gl.BindTexture(gl.TEXTURE_2D, tex)

    target :u32= gl.TEXTURE_2D
    gl.TexParameteri(target, gl.TEXTURE_WRAP_S, gl.REPEAT)
    gl.TexParameteri(target, gl.TEXTURE_WRAP_T, gl.REPEAT)
    gl.TexParameteri(target, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
    gl.TexParameteri(target, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

    gl.TexImage2D(target, 0, gl.RGBA, img.size.x, img.size.y, 0, gl.RGBA, gl.UNSIGNED_BYTE, img.data)
    if gen_mipmap do gl.GenerateMipmap(target)
    gl.BindTexture(gl.TEXTURE_2D, 0)
    return Texture{img.size, tex}
}

// Texture
texture_load_by_path :: proc(path: string, gen_mipmap := false) -> Texture {
    img := image_load(path)
    if img.data == nil do return Texture{}
    defer image_free(&img)

    tex : u32
    gl.GenTextures(1, &tex)
    gl.BindTexture(gl.TEXTURE_2D, tex)

    target :u32= gl.TEXTURE_2D
    gl.TexParameteri(target, gl.TEXTURE_WRAP_S, gl.REPEAT)
    gl.TexParameteri(target, gl.TEXTURE_WRAP_T, gl.REPEAT)
    gl.TexParameteri(target, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
    gl.TexParameteri(target, gl.TEXTURE_MAG_FILTER, gl.NEAREST)

    gl.TexImage2D(target, 0, gl.RGBA, img.size.x, img.size.y, 0, gl.RGBA, gl.UNSIGNED_BYTE, img.data)
    if gen_mipmap do gl.GenerateMipmap(target)
    return Texture{img.size, tex}
}

texture_create :: proc {
    texture_create_with_color,
    texture_create_with_buffer,
}

texture_create_empty :: proc(width, height : i32) -> TextureId {
    tex : u32
    gl.GenTextures(1, &tex)
    gl.BindTexture(gl.TEXTURE_2D, tex)

    target :u32= gl.TEXTURE_2D
    gl.TexParameteri(target, gl.TEXTURE_WRAP_S, gl.REPEAT)
    gl.TexParameteri(target, gl.TEXTURE_WRAP_T, gl.REPEAT)
    gl.TexParameteri(target, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
    gl.TexParameteri(target, gl.TEXTURE_MAG_FILTER, gl.NEAREST)

    gl.TexImage2D(target, 0, gl.RGBA, width, height, 0, gl.RGBA, gl.UNSIGNED_BYTE, nil)
    return tex
}
texture_create_with_color :: proc(width, height : int, color : Color32, gen_mipmap := false) -> TextureId {
    tex : u32
    gl.GenTextures(1, &tex)
    gl.BindTexture(gl.TEXTURE_2D, tex)

    target :u32= gl.TEXTURE_2D
    gl.TexParameteri(target, gl.TEXTURE_WRAP_S, gl.REPEAT)
    gl.TexParameteri(target, gl.TEXTURE_WRAP_T, gl.REPEAT)
    gl.TexParameteri(target, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
    gl.TexParameteri(target, gl.TEXTURE_MAG_FILTER, gl.NEAREST)

    data := make([dynamic]Color32, 0, width * height); defer delete(data)
    for i := 0; i < width * height; i += 1 {
        append(&data, color)
    }

    gl.TexImage2D(target, 0, gl.RGBA, cast(i32)width, cast(i32)height, 0, gl.RGBA, gl.UNSIGNED_BYTE, raw_data(data))
    if gen_mipmap do gl.GenerateMipmap(target)
    return tex
}

texture_create_with_buffer :: proc(width, height : int, buffer : []u8, type:TextureType=.RGBA, gen_mipmap := false) -> TextureId {
    tex : u32
    gl.GenTextures(1, &tex)
    gl.BindTexture(gl.TEXTURE_2D, tex)

    target :u32= gl.TEXTURE_2D
    gl.TexParameteri(target, gl.TEXTURE_WRAP_S, gl.REPEAT)
    gl.TexParameteri(target, gl.TEXTURE_WRAP_T, gl.REPEAT)
    gl.TexParameteri(target, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
    gl.TexParameteri(target, gl.TEXTURE_MAG_FILTER, gl.NEAREST)

    w,h :i32= cast(i32)width, cast(i32)height
    texture_update_current(w,h, buffer, type)
    if gen_mipmap do gl.GenerateMipmap(target)
    return tex
}

TextureWrapMode :: enum i32 {
    ClampToEdge = gl.CLAMP_TO_EDGE,
    ClampToBorder = gl.CLAMP_TO_BORDER,
    MirroredRepeat = gl.MIRRORED_REPEAT,
    Repeat = gl.REPEAT,
    MirrorClampToEdge = gl.MIRROR_CLAMP_TO_EDGE,
}
TextureFilterMode :: enum i32 {
    Nearest = gl.NEAREST,
    Linear = gl.LINEAR,
    NearestMipmapNearest = gl.NEAREST_MIPMAP_NEAREST,
    LinearMipmapNearest = gl.LINEAR_MIPMAP_NEAREST,
    NearestMipmapLinear = gl.NEAREST_MIPMAP_LINEAR,
    LinearMipmapLinear = gl.LINEAR_MIPMAP_LINEAR,
}
texture_set_wrap :: proc(texture: TextureId, wrap: TextureWrapMode) {
    gl.BindTexture(gl.TEXTURE_2D, texture)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, transmute(i32)wrap)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, transmute(i32)wrap)
}
texture_set_filter :: proc(texture: TextureId, min, mag: TextureFilterMode) {
    gl.BindTexture(gl.TEXTURE_2D, texture)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, transmute(i32)min)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, transmute(i32)mag)
}

texture_update :: proc(texture : TextureId, w,h : i32, buffer: []u8, type: TextureType=.RGBA) {
    gl.BindTexture(gl.TEXTURE_2D, texture)
    texture_update_current(w,h, buffer, type)
}
texture_update_current :: #force_inline proc(w,h : i32, buffer: []u8, type: TextureType=.RGBA) {
    if type == .RGBA {
        gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, w,h, 0, gl.RGBA, gl.UNSIGNED_BYTE, raw_data(buffer))
    } else if type == .Red {
        gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RED, w,h, 0, gl.RED, gl.UNSIGNED_BYTE, raw_data(buffer))
    } else {
        assert(false, "Texture type not implemented.")
    }
}

texture_delete :: proc(id: ^u32) {
    gl.DeleteTextures(1, id)
}