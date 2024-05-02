package dude

import "dgl"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:unicode/utf8"
import "vendor/fontstash"


/* TODO
- Handle multiple lines.
- Handle iterate back.
- Implement some basic styles.
*/

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

tbro_next_pos :: proc(tbro: ^TextBro, idx: int) -> Vec2 {
	if idx < 0 do return {0,0}
	g := tbro.elems[idx]
	switch v in g {
	case TextBroNewLine:
		panic("Not handled: text bro next pos of newline")
	case TextBroChar:
		return v.next
	case TextBroTab:
		return v.next
	}
	return {}
}

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

// ** export

TextBroExportConfig :: struct {
	// Basic
	color : Color32,
	transform : linalg.Matrix3f32,

	// Clamping happens before transformation, so the rect is in local space.
	clamp_enable : bool,
	clamp_rect : Rect,

	// Styles
	underline : bool,
}

tbro_config_clamp :: proc(cfg: ^TextBroExportConfig, enable: bool, rect: Rect) {
	cfg.clamp_enable = enable
	cfg.clamp_rect = rect
}

tbro_export_to_mesh_builder :: proc(tbro: ^TextBro, mb: ^dgl.MeshBuilder, from,to: int, config: TextBroExportConfig) {
	assert(from<=to && from>-1 && to<tbro_length(tbro), fmt.tprintf("TextBro: Invalid export range: {}-{}", from,to))

	if mb.vertex_format == dgl.VERTEX_FORMAT_P2U2C4 {
		for i in from..=to {
			g := tbro.elems[i]
			#partial switch v in g {
			case TextBroChar:
				q := v.quad
				t := v.texcoord
				if config.clamp_enable do q,t = _clamp_quad(q,t, config.clamp_rect)
				c := col_u2f(config.color)
				mesher_quad_p2u2c4(mb, {q.w,q.h}, {0,0}, {q.x,q.y}, {t.x,t.y}, {t.x,t.y}+{t.w,t.h}, {c,c,c,c}, transform=config.transform)
			case TextBroNewLine:
			case TextBroTab:
			}
		}
		if config.underline {
			panic("not implemented")
		}
	} else {
		panic("Vertex format not supported")
	}

	_clamp_quad :: proc(quad, texcoord, clamper: Rect) -> (q,t: Rect) {
		qmin, qmax :Vec2= {quad.x,quad.y}, {quad.x,quad.y}+{quad.w,quad.h}
		cmin, cmax :Vec2= {clamper.x,clamper.y}, {clamper.x,clamper.y}+{clamper.w,clamper.h}

		// Completely clamped
		if qmin.x>=cmax.x || qmin.y>=cmax.y || qmax.x<=cmin.x || qmax.y<=cmin.y do return {}, {}

		q, t = quad, texcoord

		if qmin.x<cmin.x {
			q.x = cmin.x
			q.w = math.clamp(qmax.x-q.x, 0, quad.w)
			t.x = (q.x-qmin.x)/quad.w * texcoord.w + texcoord.x
			t.w = texcoord.w-(t.x-texcoord.x)
		}
		if qmax.x>cmax.x {
			q.w = math.clamp(cmax.x - q.x, 0, quad.w)
			t.w = (texcoord.x+texcoord.w) - (qmax.x - cmax.x)/quad.w*texcoord.w - t.x
		}

		if qmin.y<cmin.y {
			q.y = cmin.y
			q.h = math.clamp(qmax.y-q.y, 0, quad.h)
			t.y = (q.y-qmin.y)/quad.h * texcoord.h + texcoord.y
			t.h = texcoord.h-(t.y-texcoord.y)
		}
		if qmax.y>cmax.y {
			q.h = math.clamp(cmax.y - q.y, 0, quad.h)
			t.h = (texcoord.y+texcoord.h) - (qmax.y - cmax.y)/quad.h*texcoord.h - t.y
		}
		return
	}

}
