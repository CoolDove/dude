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

DynamicFont :: struct {
    scale  : f32,

    glyphs : [dynamic]GlyphInfo,


    atlas_id : u32,
    atlas_width, atlas_height : u32,

    font_info : ttf.fontinfo,
}

GlyphInfo :: struct {
    r : rune,
    texture_id : u32,
    width, height, xoff, yoff : int,

    // Draw Data
    // atlas_x, atlas_y, atlas_width, atlas_height : f32, // uv coordinate in font atlas
}

font_get_glyph :: proc(font: ^DynamicFont, r: rune) -> ^GlyphInfo {
    g := ttf.FindGlyphIndex(&font.font_info, r)
    return &font.glyphs[g]
}

font_load_glygh :: proc(font: ^DynamicFont, r: rune) {
    info := &font.font_info
    glyph := ttf.FindGlyphIndex(info, r)
    w, h, x, y : c.int

    bitmap := ttf.GetGlyphBitmap(info, font.scale, font.scale, glyph, &w, &h, &x, &y)

    g := &font.glyphs[glyph]
    g.r = r
    g.texture_id = upload_bitmap_texture(bitmap, w, h)
    g.width, g.height = cast(int) w, cast(int) h
    g.xoff, g.yoff = cast(int) x, cast(int) y
    log.debugf("Glyph '{}' loaded. {}", r, g)
}

@(private="file")
upload_bitmap_texture :: proc(data: [^]byte, width, height : i32) -> u32 {
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

    gl.TexImage2D(target, 0, gl.R8, width, height, 0, gl.RED, gl.UNSIGNED_BYTE, data)

    return tex
}

font_load :: proc {
    font_load_from_mem,
}

font_load_from_mem :: proc(data: [^]byte, scale: f32) -> ^DynamicFont {
    font_info : ttf.fontinfo

    if !ttf.InitFont(&font_info, data, 0) {
        log.errorf("Failed to load ttf.")
        return nil
    }

    glyphs_count := font_info.numGlyphs

    dfont := new(DynamicFont)
    dfont.scale = scale
    dfont.font_info = font_info
    dfont.glyphs = make([dynamic]GlyphInfo, glyphs_count, glyphs_count)

    return dfont
}


font_destroy :: proc(font: ^DynamicFont) {
    delete(font.glyphs)
    free(font)
}

get_rune_texture :: proc(r: rune, scale: f32) -> RuneTex {
    font : ttf.fontinfo
    
    if !ttf.InitFont(&font, raw_data(DATA_UNIFONT_TTF), 0) {
        log.errorf("Failed to load ttf.")
    } else {
        log.debugf("TTF loaded. Num of glyphs: {}", font.numGlyphs)
    }
    
    width, height, xoffset, yoffset : c.int
    bitmap := ttf.GetCodepointBitmap(&font, scale, scale, r, &width, &height, &xoffset, &yoffset)
    defer ttf.FreeBitmap(bitmap, nil)

    log.debugf("Bitmap for '{}' generated, width:{}, height:{}, offset: {},{}", r, width, height, xoffset, yoffset)

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