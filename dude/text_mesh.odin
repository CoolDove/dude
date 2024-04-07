package dude


import "dgl"
import "core:fmt"
import "core:math"
import "vendor/fontstash"

// Return the height
mesher_text_p2u2c4 :: proc(mb: ^dgl.MeshBuilder, font: DynamicFont, text: string, size: f32, color: Color, region : Vec2={-1,-1}) -> f32 {
    standard_size_count :: 6
    standard_sizes :[6]f32= {8,16,32,64,128,256}
    stdsize : f32
    {
        mindiff :f32= 128
        for i in 0..<standard_size_count {
            diff := math.abs(size - standard_sizes[i])
            if diff < mindiff {
                stdsize = standard_sizes[i]
                mindiff = diff
            }
        }
    }
    
	fs := &rsys.fontstash_context
    fontstash.BeginState(fs); defer fontstash.EndState(fs)
	fontstash.SetSize(fs, stdsize)
	fontstash.SetSpacing(fs, 1)
	fontstash.SetBlur(fs, 0)
	fontstash.SetAlignHorizontal(fs, .LEFT)
	fontstash.SetAlignVertical(fs, .BASELINE)
	fontstash.SetFont(fs, font.fontid)

	iter := fontstash.TextIterInit(fs, 0, 0, text)
	prev_iter := iter
	q: fontstash.Quad
	height : f32
	scale : f32 = size/stdsize
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
            iter.nexty += stdsize
            height += stdsize
        }
        if !newline {
            using q

            mesher_quad_p2u2c4(mb, {x1-x0,y1-y0}*scale, {0,0}, {x0,y0} * scale, {s0,t0}, {s1,t1}, {color,color,color,color})
        }
	}
	return height
}

mesher_text_measure :: proc(font: DynamicFont, text: string, size: f32, region : Vec2={-1,-1}) -> Vec2 {
    standard_size_count :: 6
    standard_sizes :[6]f32= {8,16,32,64,128,256}
    stdsize : f32
    {
        mindiff :f32= 128
        for i in 0..<standard_size_count {
            diff := math.abs(size - standard_sizes[i])
            if diff < mindiff {
                stdsize = standard_sizes[i]
                mindiff = diff
            }
        }
    }
    
	fs := &rsys.fontstash_context
    fontstash.BeginState(fs); defer fontstash.EndState(fs)
	fontstash.SetSize(fs, stdsize)
	fontstash.SetSpacing(fs, 1)
	fontstash.SetBlur(fs, 0)
	fontstash.SetAlignHorizontal(fs, .LEFT)
	fontstash.SetAlignVertical(fs, .BASELINE)
	fontstash.SetFont(fs, font.fontid)

	iter := fontstash.TextIterInit(fs, 0, 0, text)
	prev_iter := iter
	q: fontstash.Quad
	height : f32
	scale : f32 = size/stdsize

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
        overflow := region.x != -1 && iter.nextx > region.x
        if newline || overflow {
            iter.nextx = 0
            iter.nexty += stdsize
            height += stdsize
        }
        if !newline {
            using q
            x_pos := (x1-x0)*scale + x0*scale
            y_pos := (y1-y0)*scale + y0*scale
            if x_pos > measure.x do measure.x = x_pos
            if y_pos > measure.y do measure.y = y_pos
        }
	}
	return measure
}