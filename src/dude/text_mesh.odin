package dude


import "dgl"
import "core:fmt"
import "vendor/fontstash"

// Return the height
mesher_text_p2u2c4 :: proc(mb: ^dgl.MeshBuilder, text: string, size: f32, color: Color, region : Vec2={-1,-1}) -> f32 {
	fs := &rsys.fontstash_context
    fontstash.BeginState(fs); defer fontstash.EndState(fs)
	fontstash.SetSize(fs, size)
	fontstash.SetSpacing(fs, 1)
	fontstash.SetBlur(fs, 0)
	fontstash.SetAlignHorizontal(fs, .LEFT)
	fontstash.SetAlignVertical(fs, .BASELINE)
	fontstash.SetFont(fs, rsys.font_unifont.fontid)

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
        overflow := region.x != -1 && iter.nextx > region.x
        if newline || overflow {
            iter.nextx = 0
            iter.nexty += size
            height += size
        }
        if !newline {
            using q
            mesher_quad_p2u2c4(mb, {x1-x0,y1-y0}, {0,0}, {x0,y0}, {s0,t0}, {s1,t1}, {color,color,color,color})
        }
	}
	return height
}