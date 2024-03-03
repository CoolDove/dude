package dude


import "dgl"
import "core:fmt"
import "vendor/fontstash"

mesher_text_p2u2c4 :: proc(mb: ^dgl.MeshBuilder, text: string, size: f32, color: Color) {
	fs := &rsys.fontstash_context
    fontstash.BeginState(fs); defer fontstash.EndState(fs)
	fontstash.SetSize(fs, size)
	fontstash.SetSpacing(fs, 1)
	fontstash.SetBlur(fs, 0)
	fontstash.SetAlignHorizontal(fs, .LEFT)
	fontstash.SetAlignVertical(fs, .BASELINE)
	fontstash.SetFont(fs, rsys.fontid_unifont)

    // dgl.mesh_builder_init(&mb, dgl.VERTEX_FORMAT_P2U2C4); defer dgl.mesh_builder_release(&mb)

	iter := fontstash.TextIterInit(fs, 0, 0, text)
	prev_iter := iter
	q: fontstash.Quad
	for fontstash.TextIterNext(fs, &iter, &q) {
		if iter.previousGlyphIndex == -1 { // can not retrieve glyph?
			iter = prev_iter
			fontstash.TextIterNext(fs, &iter, &q) // try again
			if iter.previousGlyphIndex == -1 {
				break
			} 
		}
		prev_iter = iter
        { using q
            mesher_quad_p2u2c4(mb, {x1-x0,y1-y0}, {0,0}, {x0,y0}, {s0,t0}, {s1,t1}, {color,color,color,color})
        }
	}
}