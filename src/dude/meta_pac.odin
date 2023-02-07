package dude

import "core:odin/parser"
import "core:odin/ast"
import "core:log"
import "core:fmt"
import "core:strings"
import "core:reflect"
import "core:path/filepath"
import "core:odin/printer"
import "core:odin/tokenizer"
import "core:os"

meta_pac_test :: proc() {
    psr : parser.Parser
    // psr.err = nil
    // psr.warn = nil

    log.debugf("-----------parse src------------")

    file := parse_src(&psr, `
        package builtin

        icon  : Texture
        icon2 : Texture

        logo := Texture {
            scale = 0.1,
            tint  = Color{1, 1, 1, 1},
        }
    `)

    get_value_decls(file)
}

get_value_decls :: proc(file: ^ast.File, allocator:= context.allocator) -> [dynamic]^ast.Value_Decl {
    log.debugf("**file: {}", file.pkg_name)
    for decl in file.decls {
        #partial switch decl_type in decl.derived {
        case ^ast.Value_Decl :
            sb : strings.Builder
            strings.builder_init(&sb)
            defer strings.builder_destroy(&sb)

            value_decl := decl.derived.(^ast.Value_Decl)

            if len(value_decl.names) > 1 do continue

            strings.write_string(&sb, value_decl.names[0].derived.(^ast.Ident).name)
            strings.write_rune(&sb, ':')

            if value_decl.type != nil {
                strings.write_string(&sb, get_type_name(value_decl.type.derived_expr))
            } else if value_decl.values != nil {
                val := value_decl.values[0]
                typename := get_type_name(val.derived_expr.(^ast.Comp_Lit).type.derived_expr)
                strings.write_string(&sb, typename)
            }
            log.debugf("--{}", strings.to_string(sb))
        }
    }
    return nil
}

get_type_name :: proc(expr: ast.Any_Expr) -> string {
    #partial switch t in expr {
    case ^ast.Selector_Expr :
        return t.derived_expr.(^ast.Selector_Expr).field.name
    case ^ast.Ident :
        return t.derived.(^ast.Ident).name
    }
    return ""
}

// ## Parse tool.

parse_src :: proc(p: ^parser.Parser, src: string) -> ^ast.File {
	NO_POS :: tokenizer.Pos{}
	file := ast.new(ast.File, NO_POS, NO_POS)
	file.pkg = nil
	file.src = string(src)
	file.fullpath = "---"
    if parse_file(p, file) {
        free(file)
        return file
    }
    return nil
}

parse_file :: proc(p: ^parser.Parser, file: ^ast.File) -> bool {
    using parser
	zero_parser: {
		p.prev_tok         = {}
		p.curr_tok         = {}
		p.expr_level       = 0
		p.allow_range      = false
		p.allow_in_expr    = false
		p.in_foreign_block = false
		p.allow_type       = false
		p.lead_comment     = nil
		p.line_comment     = nil
	}

	p.tok.flags += {.Insert_Semicolon}

	p.file = file
	tokenizer.init(&p.tok, file.src, file.fullpath, p.err)
	if p.tok.ch <= 0 {
		return true
	}


	advance_token(p)
	consume_comment_groups(p, p.prev_tok)

	docs := p.lead_comment

	p.file.pkg_token = expect_token(p, .Package)
	if p.file.pkg_token.kind != .Package {
		return false
	}

	pkg_name := expect_token_after(p, .Ident, "package")
	if pkg_name.kind == .Ident {
		switch name := pkg_name.text; {
		case is_blank_ident(name): 
            error(p, pkg_name.pos, "invalid package name '_'")
        }
	}
	p.file.pkg_name = pkg_name.text

	pd := ast.new(ast.Package_Decl, pkg_name.pos, end_pos(p.prev_tok))
	pd.docs    = docs
	pd.token   = p.file.pkg_token
	pd.name    = pkg_name.text
	pd.comment = p.line_comment
	p.file.pkg_decl = pd
	p.file.docs = docs

	expect_semicolon(p, pd)

	if p.file.syntax_error_count > 0 {
		return false
	}

	p.file.decls = make([dynamic]^ast.Stmt)

	for p.curr_tok.kind != .EOF {
		stmt := parse_stmt(p)
		if stmt != nil {
			if _, ok := stmt.derived.(^ast.Empty_Stmt); !ok {
				append(&p.file.decls, stmt)
				if es, es_ok := stmt.derived.(^ast.Expr_Stmt); es_ok && es.expr != nil {
					if _, pl_ok := es.expr.derived.(^ast.Proc_Lit); pl_ok {
						error(p, stmt.pos, "procedure literal evaluated but not used")
					}
				}
			}
		}
	}

	return true
}