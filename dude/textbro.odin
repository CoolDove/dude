package dude

import "dgl"
import "core:fmt"
import "core:math"
import "core:unicode/utf8"
import "vendor/fontstash"

TextBro :: struct {
	elems : [dynamic]TextBroElem,
	line_count : int,

	tabstop : int, // How many spaces for a tab, 4 by default.
	line_spacing : f32, // 1.5 by default

	_iter : fontstash.TextIterEx,
}

TextBroElem :: union {
	TextBroChar,
	TextBroNewLine,
	TextBroTab,
}
TextBroChar :: struct {
	r : rune,
	quad, texcoord : Rect,
	next : Vec2,
}
TextBroNewLine :: struct { 
	line_count : int,
}
TextBroTab :: distinct TextBroChar

tbro_init :: proc(tbro: ^TextBro, fontid: DynamicFont, size: f32) {
	tbro.elems = make([dynamic]TextBroElem)

	tbro.tabstop = 4
	tbro.line_spacing = 1.5

	tbro._iter = fontstash.TextIterExInit(&rsys.fontstash_context, fontid.fontid, size, 0,0)
}
tbro_release :: proc(tbro: ^TextBro) {
	delete(tbro.elems)
}

tbro_count_lines :: proc(tbro: ^TextBro) -> int {
	return tbro.line_count
}

tbro_length :: proc(tbro: ^TextBro) -> int {
	return len(tbro.elems)
}
// TODO:
// tbro_goback :: proc(tbro: ^TextBro, count: int) -> bool {
	// if count > len(tbro.elems) do return false
	// for i in 0..<count {
		// e := pop(&tbro.elems)
		// #partial switch v in TextBroElem {
		// case .TextBroNewLine:
			// tbro.line_count -= 1
		// }
	// }
	// length := tbro_length(tbro)
	// if length > 0 {
		// tbro._iter.nextx = tbro.elems[length-1]
		// tbro._iter.nexty = tbro.elems[length-1]
	// }
	// return true
// }

tbro_write_newline :: proc(tbro: ^TextBro) {
	tbro.line_count += 1
	append(&tbro.elems, TextBroNewLine{tbro_count_lines(tbro)})
	tbro._iter.nextx = tbro._iter.x
	tbro._iter.nexty += tbro._iter.scale
}
tbro_write_tab :: proc(tbro: ^TextBro) {
	for i in 0..<tbro.tabstop do fontstash.TextIterExNext(&tbro._iter, ' ')
	append(&tbro.elems, TextBroTab{'\t', {},{}, {tbro._iter.nextx, tbro._iter.nexty}})
}

tbro_write_rune :: proc(tbro: ^TextBro, r: rune) -> int {
	if r == '\n' {
		tbro_write_newline(tbro)
	} else if r == '\t' {
		tbro_write_tab(tbro)
	} else {
		q := fontstash.TextIterExNext(&tbro._iter, r)
		quad := Rect{q.x0, q.y0, q.x1-q.x0, q.y1-q.y0}
		texcoord := Rect{q.s0, q.t0, q.s1-q.s0, q.t1-q.t0}
		append(&tbro.elems, TextBroChar{r, quad, texcoord, {tbro._iter.nextx, tbro._iter.nexty}})
	}
	return tbro_length(tbro)-1
}
tbro_write_string :: proc(tbro: ^TextBro, str: string) -> int {
	data := transmute([]u8)str
	i := 0
	for ; i < len(str); {
		r, offset := utf8.decode_rune_in_bytes(data[i:])
		i += offset
		tbro_write_rune(tbro, r)
	}
	return tbro_length(tbro)-1
}

tbro_export_to_mesh_builder :: proc(tbro: ^TextBro, mb: ^dgl.MeshBuilder, from,to: int, color: Color32) {
	assert(from<=to && from>-1 && to<tbro_length(tbro), fmt.tprintf("TextBro: Invalid export range: {}-{}", from,to))
	if from == to do return
	if mb.vertex_format == dgl.VERTEX_FORMAT_P2U2C4 {
		for i in from..=to {
			g := tbro.elems[i]
			#partial switch v in g {
			case TextBroChar:
				q := v.quad
				t := v.texcoord
				c := col_u2f(color)
				mesher_quad_p2u2c4(mb, {q.w,q.h}, {0,0}, {q.x,q.y}, {t.x,t.y}, {t.x,t.y}+{t.w,t.h}, {c,c,c,c})
			case TextBroNewLine:
			case TextBroTab:
			}
		}
	} else {
		panic("Vertex format not supported")
	}
}
