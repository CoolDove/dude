package dude


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

// NOTE: The Data of DynamicFont
// You load the dynamic font from a loaded .ttf data,
// the data buffer should be keeped well when the dynamic font is in work.
DynamicFont :: struct {
    scale  : f32,

    glyphs : [dynamic]GlyphInfo,

    atlas_id : u32,
    atlas_width, atlas_height : u32,

    font_info : ttf.fontinfo,

    data_buffer : []byte, // If loaded from a file.
}

GlyphInfo :: struct {
    texture_id : u32,
    width, height, xoff, yoff : i32,
    advance_h, advance_v, left_side_bearing : i32,

    // Draw Data
    // atlas_x, atlas_y, atlas_width, atlas_height : f32, // uv coordinate in font atlas
}

font_load :: proc {
    font_load_from_path,
    font_load_from_mem,
}
font_destroy :: proc(font: ^DynamicFont) {
    if font.data_buffer != nil do delete(font.data_buffer)

    for glyph in &font.glyphs {
        if glyph.texture_id != 0 do gl.DeleteTextures(1, &glyph.texture_id)
    }
    delete(font.glyphs)
    free(font)
}

font_default_glyph :: proc(font: ^DynamicFont, r: rune) -> ^GlyphInfo {
    // TODO: impl this, default glyph
    return nil
}

font_get_glyph_id :: #force_inline proc(font: ^DynamicFont, r: rune) -> i32 {
    return ttf.FindGlyphIndex(&font.font_info, r)
}

font_get_glyph_info :: #force_inline proc(font: ^DynamicFont, r: rune) -> ^GlyphInfo {
    g := ttf.FindGlyphIndex(&font.font_info, r)
    if ! font_does_glyph_exist(font, g) do return nil
    return &font.glyphs[g]
}

// NOTE: `glyph` version is faster than `codepoint` version.

// Returns if the glyph data has been loaded.
font_is_glyph_loaded :: #force_inline proc(font: ^DynamicFont, index: i32) -> bool {
    if cast(bool) ttf.IsGlyphEmpty(&font.font_info, index) do return false
    glyph := &font.glyphs[index]
    return glyph.width != 0 && glyph.height != 0
}
font_is_codepoint_loaded :: #force_inline proc(font: ^DynamicFont, r: rune) -> bool {
    glyph := font_get_glyph_info(font, r)
    return glyph.width != 0 && glyph.height != 0
}

// Returns if the glyph is empty in the font file.
font_does_codepoint_exist :: #force_inline proc(font: ^DynamicFont, r: rune) -> bool {
    info := &font.font_info
    return font_does_glyph_exist(font, ttf.FindGlyphIndex(info, r))
}

font_does_glyph_exist :: #force_inline proc(font: ^DynamicFont, index: i32) -> bool {
    info := &font.font_info
    return ! cast(bool) ttf.IsGlyphEmpty(info, index)
}

// Return false means glyph doesn't exist.
font_load_glyph :: proc(font: ^DynamicFont, glyph: i32) -> bool {
    info := &font.font_info
    // glyph := ttf.FindGlyphIndex(info, r)
    if !font_does_glyph_exist(font, glyph) do return false

    w, h, x, y : c.int
    bitmap := ttf.GetGlyphBitmap(info, font.scale, font.scale, glyph, &w, &h, &x, &y)

    g := &font.glyphs[glyph]
    g.texture_id = upload_bitmap_texture(bitmap, w, h)
    g.width, g.height = w, h
    g.xoff, g.yoff = x, y

    ttf.GetGlyphHMetrics(info, glyph, &g.advance_h, &g.left_side_bearing)
    ttf.FreeBitmap(bitmap, nil)

    return true
}
font_load_codepoint :: #force_inline proc(font: ^DynamicFont, r: rune) -> bool {
    result := font_load_glyph(font, ttf.FindGlyphIndex(&font.font_info, r))
    if result do log.debugf("Codepoint: {} loaded.", r)
    return result
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

font_get_kern :: #force_inline proc(font: ^DynamicFont, prev, next: i32) -> i32 {
    return ttf.GetGlyphKernAdvance(&font.font_info, prev, next)
}

font_get_space_advance :: #force_inline proc(font: ^DynamicFont) -> i32 {
    advance : i32
    ttf.GetCodepointHMetrics(&font.font_info, ' ', &advance, nil)
    return advance
}

font_load_from_path :: #force_inline proc(path: string, px: f32) -> ^DynamicFont {
    log.errorf("font_load_from_path is not ready for now.")
    return nil
}
font_load_from_mem :: proc(data: [^]byte, px: f32) -> ^DynamicFont {
    font_info : ttf.fontinfo
    if !ttf.InitFont(&font_info, data, 0) {
        log.errorf("Failed to load ttf.")
        return nil
    }

    scale := ttf.ScaleForPixelHeight(&font_info, px)

    glyphs_count := font_info.numGlyphs

    dfont := new(DynamicFont)
    dfont.scale = scale
    dfont.font_info = font_info
    dfont.glyphs = make([dynamic]GlyphInfo, glyphs_count, glyphs_count)
    dfont.data_buffer = nil

    return dfont
}