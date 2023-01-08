package main


import "core:c"
import "core:fmt"
import "core:strings"
import "core:math"
import "core:log"

import gl "vendor:OpenGL"

import "dgl"

import ttf "vendor:stb/truetype"

RuneTex :: struct {
    id : u32,
    width, height : f32,
}

get_rune_texture :: proc(r: rune, scale: f32) -> RuneTex {
    font : ttf.fontinfo
    // if !ttf.InitFont(&font, raw_data(DATA_INKFREE_TTF), 0) {
    if !ttf.InitFont(&font, raw_data(DATA_UNIFONT_TTF), 0) {
        log.errorf("Failed to load ttf.")
    } else {
        log.debugf("TTF loaded. Num of glyphs: {}", font.numGlyphs)
    }
    
    width, height, xoffset, yoffset : c.int
    bitmap := ttf.GetCodepointBitmap(&font, scale, scale, r, &width, &height, &xoffset, &yoffset)
    defer ttf.FreeBitmap(bitmap, nil)

    log.debugf("Bitmap for '{}' generated, width:{}, height:{}, offset: {},{}", r, width, height, xoffset, yoffset)

    // for y in 0..<height {
    //     for x in 0..<width {
    //         c := bitmap[y * width + x]
    //         if c > 128 do fmt.print("@")
    //         else do fmt.print(".")
    //     }
    //     fmt.print("\n")
    // }

    tex : u32
    gl.GenTextures(1, &tex)
    gl.BindTexture(gl.TEXTURE_2D, tex)

    gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1)

    target :u32= gl.TEXTURE_2D
    gl.TexParameteri(target, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
    gl.TexParameteri(target, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
    gl.TexParameteri(target, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
    gl.TexParameteri(target, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
    
    testb : strings.Builder
    strings.builder_init(&testb, 0, 16)
    defer strings.builder_destroy(&testb)

    gl.TexImage2D(target, 0, gl.R8, width, height, 0, gl.RED, gl.UNSIGNED_BYTE, bitmap)
    // gl.TexImage2D(target, 0, gl.RGBA, cast(i32)width, cast(i32)height, 0, gl.RGBA, gl.UNSIGNED_BYTE, raw_data(buffer.buf))
    // gl.TexSubImage2D(tex, 0, 0, 0, width, height, gl.R8, gl.UNSIGNED_BYTE, raw_data(buffer.buf))

    log.debugf("bitmap uploaded")
    // id := dgl.texture_create_with_buffer(cast(int)width, cast(int)height, buffer.buf[:width*height*4])
    return RuneTex{tex, cast(f32)width, cast(f32)height}
}