package dude


import "dgl"
import "core:fmt"
import "core:math"
import "vendor/fontstash"

// Return the height
mesher_text_p2u2c4 :: proc(mb: ^dgl.MeshBuilder, font: DynamicFont, text: string, size: f32, color: Color, region : Vec2={-1,-1}, overflow:= false, clamp:=false) -> f32 {
	fs := &rsys.fontstash_context
    fontstash.BeginState(fs); defer fontstash.EndState(fs)
	fontstash.SetSize(fs, size)
	fontstash.SetSpacing(fs, 1)
	fontstash.SetBlur(fs, 0)
	fontstash.SetAlignHorizontal(fs, .LEFT)
	fontstash.SetAlignVertical(fs, .BASELINE)
	fontstash.SetFont(fs, font.fontid)

	iter := fontstash.TextIterInit(fs, 0, 0, text)
	prev_iter := iter
	q: fontstash.Quad
	height : f32
	for fontstash.TextIterNext(fs, &iter, &q) {
		if iter.previousGlyphIndex == -1 { // can not retrieve glyph?
			iter = prev_iter
			fontstash.TextIterNext(fs, &iter, &q) // try again
			if iter.previousGlyphIndex == -1 {
				break
			} 
		}
        prev_iter = iter
        newline := iter.codepoint == '\n'
        overflow := (overflow && (region.x != -1 && iter.nextx > region.x))
        if newline || overflow {
            iter.nextx = 0
            iter.nexty += size
            height += size
        }
        if !newline {
            using q
            clamped := clamp && ((region.x != -1 && (x1 <= 0 || x0 >= region.x)) || (region.y != -1 && (y1 <= 0 || y0 >= region.y)))
            if !clamped {
                if x1 > region.x && x0 < region.x {
                    x11 := region.x
                    s1 = (s1-s0)*((x11-x0)/(x1-x0)) + s0
                    x1 = x11
                } else if x1 > 0 && x0 < 0 {
                    x00 :f32= 0
                    s0 = s1 - ((x1-x00)/(x1-x0))*(s1-s0)
                    x0 = x00
                }
                mesher_quad_p2u2c4(mb, {x1-x0,y1-y0}, {0,0}, {x0,y0}, {s0,t0}, {s1,t1}, {color,color,color,color})
            }
        }
	}
	return height
}

mesher_text_measure :: proc(font: DynamicFont, text: string, size: f32, region : Vec2={-1,-1}, overflow:= false, out_next_pos: ^Vec2=nil) -> Vec2 {

	fs := &rsys.fontstash_context
	fontstash.BeginState(fs); defer fontstash.EndState(fs)
	fontstash.SetSize(fs, size)
	fontstash.SetSpacing(fs, 1)
	fontstash.SetBlur(fs, 0)
	fontstash.SetAlignHorizontal(fs, .LEFT)
	fontstash.SetAlignVertical(fs, .BASELINE)
	fontstash.SetFont(fs, font.fontid)

	iter := fontstash.TextIterInit(fs, 0, 0, text)
	prev_iter := iter
	q: fontstash.Quad
	height : f32

    measure : Vec2
	for fontstash.TextIterNext(fs, &iter, &q) {
		if iter.previousGlyphIndex == -1 { // can not retrieve glyph?
			iter = prev_iter
			fontstash.TextIterNext(fs, &iter, &q) // try again
			if iter.previousGlyphIndex == -1 {
				break
			} 
		}
        prev_iter = iter
        newline := iter.codepoint == '\n'
        overflow := (overflow && (region.x != -1 && iter.nextx > region.x))
        if newline || overflow {
            iter.nextx = 0
            iter.nexty += size
            height += size
        }
        if !newline {
            using q
            x_pos := (x1-x0) + x0
            y_pos := (y1-y0) + y0
            if x_pos > measure.x do measure.x = x_pos
            if y_pos > measure.y do measure.y = y_pos
        }
	}
    if out_next_pos != nil do out_next_pos^ = {iter.nextx, iter.nexty}
	return measure
}


get_font :: proc(font: DynamicFont) -> ^fontstash.Font {
	fs := &rsys.fontstash_context
	return fontstash.__getFont(fs, font.fontid)
}
