package dude


import "core:c"
import "core:fmt"
import "core:strings"
import "core:math"
import "core:log"

import gl "vendor:OpenGL"

import "dgl"

import "vendor/fontstash"

DynamicFont :: struct {
    fontid : int,
}

font_load :: proc(data: []u8, name: string) -> DynamicFont {
    fontid := fontstash.AddFontMem(&rsys.fontstash_context, name, data, false)
    return {fontid}
}

font_add_fallback :: proc(base_font, fallback_font : DynamicFont) -> bool {
    return fontstash.AddFallbackFont(&rsys.fontstash_context, base_font.fontid, fallback_font.fontid)
}

font_unload :: proc(font: DynamicFont) {
    // TODO: Remove a font from fontstash (this is not supported by default).
}