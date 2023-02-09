package dude

import "core:odin/parser"
import "core:odin/ast"
import "core:log"
import "core:fmt"
import "core:strings"
import "core:runtime"
import "core:reflect"
import "core:strconv"
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

        @private
        color_white :: Color{ 1, 1, 1, 1 }

        @(load="shader/builtin_mesh_opaque.shader")
        shader_default : Shader

        @(load="dude.png")
        dude_logo :: Texture{
            scale = 1.0,
            tint = color_white,
        }

        mat_default := Material {
            shader = shader_default,
        }
        mat_ext := Material {
            shader = extends.shader_default,
        }
    `)

    file_node, ok := file.node.derived.(^ast.File)
    if ok {
        log.debugf("Package name: {}", file_node.pkg_name)

        dpac := generate_package(file_node)
        sb : strings.Builder
        strings.builder_init(&sb)
        defer strings.builder_destroy(&sb)

        for v in dpac.values {
            list_dpac_value(&sb, v)
            strings.write_rune(&sb, '\n')
        }
        log.debugf("\n{}\n", strings.to_string(sb))
    }
}


DPackage :: struct {
    identifiers : map[string]int,
    values : [dynamic]^DPacValue,
}

DPacValue :: struct {
    name  : string,
    type  : string,
    value : union {
        DPacRef,    // reference
        DPacLiteral,// literal
        ^DPacObject,  // field - value pair
    },
    load_path : string,
}

DPacLiteral :: union {
    f32, i32, string,
}
DPacRef :: struct {
    pac, name : string,
}
DPacObject :: struct {
    type   : string,
    fields : []string,
    values : []^DPacValue,
}

list_dpac_value :: proc(sb: ^strings.Builder, v: ^DPacValue, ite:=0) {
    using strings
    tab_builder : Builder
    builder_init(&tab_builder)
    defer builder_destroy(&tab_builder)
    for i in 0..=ite + 1 do write_string(&tab_builder, "  ")
    tab := to_string(tab_builder)

    write_string(sb, fmt.tprintf("{}#{}({})", tab, v.name, v.type))

    #partial switch vtype in v.value {
    case DPacRef:
        ref := v.value.(DPacRef)
        if ref.pac == "" {
            write_string(sb, fmt.tprintf(">[this.{}]\n", ref.name))
        } else {
            write_string(sb, fmt.tprintf(">[{}.{}]\n", ref.pac, ref.name))
        }
    case DPacLiteral:
        lit := v.value.(DPacLiteral)
        write_string(sb, fmt.tprintf(" {}\n", lit))
    case ^DPacObject:
        write_rune(sb, '\n')
        data := v.value.(^DPacObject)
        for i in 0..<len(data.values) {
            subvalue := data.values[i]
            list_dpac_value(sb, subvalue, ite + 1)
        }
    }
}

generate_package :: proc(file: ^ast.File) -> ^DPackage {
    dpac := new (DPackage)
    dpac.values = make([dynamic]^DPacValue, 0, 512)
    for stmt in file.decls {
        decl, ok := stmt.derived_stmt.(^ast.Value_Decl)
        if ok {
            values := generate_value_decl(dpac, decl)
            for v in values {
                append(&dpac.values, v)
            }
        } else {
            log.errorf("Invalid statement in dpackage odin. {}", stmt)
        }
    }
    return dpac
}
generate_value_decl :: proc(dpac: ^DPackage, decl: ^ast.Value_Decl) -> []^DPacValue {
    count  := len(decl.names)
    attributes := decl.attributes

    values := make([]^DPacValue, count)
    for i in 0..<count {
        value : ^DPacValue
        if decl.type != nil {
            value = new(DPacValue)
            value.name = decl.names[i].derived_expr.(^ast.Ident).name
             value.type = decl.type.derived_expr.(^ast.Ident).name
            value.value = nil
        } else {
            value_decl := decl.values[i]
            value = generate_value(dpac, value_decl)
            value.name = decl.names[i].derived_expr.(^ast.Ident).name
        }
        values[i] = value
        {// check attributes
            for atb in attributes {
                log.debugf("attrib: {}", atb.tok)
                for elem in atb.elems {
                    log.debugf("    elem: {}", elem.derived_expr)
                }
            }
        }
    }
    return values
}

generate_value :: proc(dpac: ^DPackage, expr : ^ast.Expr) -> ^DPacValue {
    value := new(DPacValue)
    #partial switch vtype in expr.derived_expr {
    case ^ast.Comp_Lit:
        comp_lit := generate_data(dpac, expr.derived_expr.(^ast.Comp_Lit))
        value.type  = comp_lit.type
        value.value = comp_lit
    case ^ast.Selector_Expr:
        select := expr.derived_expr.(^ast.Selector_Expr)
        pac  := select.expr.derived_expr.(^ast.Ident).name
        name := select.field.derived_expr.(^ast.Ident).name
        value.value = DPacRef{
            pac=pac,
            name=name,
        }
        value.type = "Reference"
    case ^ast.Ident:
        value.value = DPacRef{
            pac="",
            name=expr.derived_expr.(^ast.Ident).name,
        }
        value.type = "Reference"

    case ^ast.Basic_Lit:
        tok := expr.derived_expr.(^ast.Basic_Lit).tok
        value.type = reflect.enum_string(tok.kind)
        value.value = get_literal(&tok)
    case ^ast.Field_Value:
        field_value_pair := expr.derived_expr.(^ast.Field_Value) 
        field := field_value_pair.field.derived_expr.(^ast.Ident).name
        v := generate_value(dpac, field_value_pair.value)
    }
    return value
}

generate_data :: proc(dpac: ^DPackage, complit: ^ast.Comp_Lit) -> ^DPacObject {
    comp := new (DPacObject)
    type := complit.type.derived_expr.(^ast.Ident)
    comp.type = type.name
    count := len(complit.elems)
    comp.fields = make([]string, count)
    comp.values = make([]^DPacValue, count)
    for elem, ind in complit.elems {
        #partial switch vtype in elem.derived_expr {
        case ^ast.Field_Value:
            field_value_pair := elem.derived_expr.(^ast.Field_Value) 
            field := field_value_pair.field.derived_expr.(^ast.Ident).name
            value := generate_value(dpac, field_value_pair.value)
            value.name = field
            comp.fields[ind] = field
            comp.values[ind] = value
        case ^ast.Basic_Lit:
            tok := elem.derived_expr.(^ast.Basic_Lit).tok
            value := new(DPacValue)
            value.type = reflect.enum_string(tok.kind)
            value.value = get_literal(&tok)
            value.name = ""
            comp.values[ind] = value
        }
    }
    return comp
}

get_literal :: proc(tok : ^tokenizer.Token) -> DPacLiteral {
    lit : DPacLiteral
    #partial switch tok.kind {
    case .Ident: fallthrough
    case .String:
        lit = DPacLiteral(tok.text)
    case .Integer:
        i32_value, ok := strconv.parse_int(tok.text)
        assert(ok, "DPac: parse i32 failed.")
        lit = DPacLiteral(cast(i32)i32_value)
    case .Float:
        f32_value, ok := strconv.parse_f32(tok.text)
        assert(ok, "DPac: parse f32 failed.")
        lit = DPacLiteral(cast(f32)f32_value)
    case:
        assert(true, "DPac: invalid literal kind.")
    }
    return lit
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