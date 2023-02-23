//+private
package dpac

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

types := map[string]typeid { }

// ## Those types are used to present the dpac syntax tree.
// All of them are allocated by the `meta_storage` of the dpackage.
// The dpac ast will be created after call `dpac_init`.
// And the loading process happens when `dpac_load` is called.

generate_meta_from_source :: proc(dpac: ^DPackage, source: string) -> ^DPacMeta {
    context.allocator = dpac.meta_storage.allocator
    psr : parser.Parser
    file := parse_src(&psr, source)
    {// ## Generate meta AST
        dpacmeta := new (DPacMeta)
        strings.builder_init(&dpacmeta.name)
        strings.write_string(&dpacmeta.name, file.pkg_name)
        dpacmeta.symbols = make(map[DPacKey]DPacSymbol, len(file.decls))

        for stmt in file.decls {
            decl, ok := stmt.derived_stmt.(^ast.Value_Decl)
            if ok {
                obj, succ := generate_value_decl(dpac, dpacmeta, decl)
                key := dpac_key(obj.name)
                if succ {
                    // If the key has been in the symbols map, `generate_value_decl` wouldn't have been suceeded.
                    symbol : DPacSymbol
                    symbol.obj = obj
                    map_insert(&dpacmeta.symbols, key, DPacSymbol{obj, DPackageAsset{}})
                } 
            } else {
                log.errorf("Invalid statement in DPacMeta odin. {}", stmt)
            }
        }
        return dpacmeta
    }
    return nil
}

generate_value_decl :: proc(dpac: ^DPackage, dpacmeta: ^DPacMeta, decl: ^ast.Value_Decl) -> (DPacObject, bool) {
    assert(len(decl.names) == 1, "DPac: Not support multi-values declaration.")

    attributes := decl.attributes

    value : DPacObject
    name := decl.names[0]
    name_str := name.derived_expr.(^ast.Ident).name
    name_key := dpac_key(name_str)

    if name_key in dpacmeta.symbols {
        log.errorf("DPac: Repeated symbol: {}.", name_str)
        return {} , false
    }

    type := decl.type
    if decl.type != nil {
        value.name = strings.clone(name_str)
        value.type = strings.clone(decl.type.derived_expr.(^ast.Ident).name)
        value.value = nil
    } else {
        value_decl := decl.values[0]
        value = generate_value(dpacmeta, value_decl)
        value.name = strings.clone(name_str)
    }
    for atb in attributes {
        atb_kind, atb_value : string
        for elem in atb.elems {
            #partial switch vtype in elem.derived_expr {
            case ^ast.Ident:
                ident := elem.derived_expr.(^ast.Ident)
                atb_kind = ident.name
            case ^ast.Field_Value:
                field_value_pair := elem.derived_expr.(^ast.Field_Value)
                field_node := field_value_pair.field.derived_expr.(^ast.Ident)
                value_node := field_value_pair.value.derived.(^ast.Basic_Lit)
                atb_kind = field_node.name
                atb_text := value_node.tok.text
                atb_value = atb_text[1:len(atb_text) - 1]
            }
            // attributes
            switch atb_kind {
            case "private":
                value.is_private = true
            case "load":
                if atb_value != "" {
                    value.load_path = strings.clone(atb_value)
                }
            case:
                panic("Unknown attribute in DPacMeta.")
            }
        }
    }
    
    return value, true
}

generate_value :: proc(dpacmeta: ^DPacMeta, expr : ^ast.Expr) -> DPacObject {
    value : DPacObject
    #partial switch vtype in expr.derived_expr {
    case ^ast.Comp_Lit:
        value = generate_initializer(dpacmeta, expr.derived_expr.(^ast.Comp_Lit))
    case ^ast.Selector_Expr:
        value = generate_reference(dpacmeta, expr.derived_expr.(^ast.Selector_Expr))
    case ^ast.Ident:
        value = generate_reference(dpacmeta, expr.derived_expr.(^ast.Ident))
    case ^ast.Basic_Lit:
        tok := expr.derived_expr.(^ast.Basic_Lit).tok
        value.type = reflect.enum_string(tok.kind)
        value.value = generate_literal(&tok)
    case :
        log.errorf("DPacParser: Unhandled value decl type: {}", expr.derived_expr)
    }
    return value
}

generate_initializer :: proc(dpacmeta: ^DPacMeta, complit: ^ast.Comp_Lit) -> DPacObject {
    ini : DPacInitializer
    type := complit.type.derived_expr.(^ast.Ident)
    count := len(complit.elems)
    ini.fields = make([]DPacFields, count)

    typename := complit.type.derived_expr.(^ast.Ident).name
    ini.type = strings.clone(typename)
    // log.debugf("DPac: typename: {}", typename)
    
    anonymous := true
    named := false
    for elem, ind in complit.elems {
        // log.warnf("DPac: generating ini: {}, elem type: {}", ini, elem.derived_expr)
        #partial switch vtype in elem.derived_expr {
        case ^ast.Field_Value:
            field_value_pair := elem.derived_expr.(^ast.Field_Value)
            field := field_value_pair.field.derived_expr.(^ast.Ident).name
            value := generate_value(dpacmeta, field_value_pair.value)
            value.name = strings.clone(field)
            ini.fields[ind] = DPacFields{field, value} 
            named = true
            anonymous = false
        case ^ast.Comp_Lit:
            subini := generate_initializer(dpacmeta, elem.derived_expr.(^ast.Comp_Lit))
            ini.fields[ind] = DPacFields{"", subini}// anonymous value
            subini_ini := subini.value.(DPacInitializer)
        case ^ast.Basic_Lit:
            tok := elem.derived_expr.(^ast.Basic_Lit).tok
            value : DPacObject
            value.type = reflect.enum_string(tok.kind)
            value.value = generate_literal(&tok)
            value.name = ""
            ini.fields[ind] = DPacFields{"", value}
        case ^ast.Ident:
            ident := elem.derived_expr.(^ast.Ident)
            ref := generate_reference(dpacmeta, ident)
            ini.fields[ind] = DPacFields{"", ref}
        case ^ast.Selector_Expr:
            selector := elem.derived_expr.(^ast.Selector_Expr)
            ref := generate_reference(dpacmeta, selector)
            ini.fields[ind] = DPacFields{"", ref}
        }
    }

    if anonymous {
        if named {
            log.warnf("DPac: Incorrect syntax, object initializer cannot mix between `anonymous` and `named`. It'll be taken as a named initializer.")
        } else {
            ini.anonymous = true
        }
    }

    return DPacObject {
        type  = ini.type,
        value = ini,
    }
}

generate_reference :: proc(dpacmeta: ^DPacMeta, ident: union{^ast.Selector_Expr, ^ast.Ident}) -> DPacObject {
    switch node_type in ident {
    case ^ast.Selector_Expr:
        select_expr := ident.(^ast.Selector_Expr)
        select := select_expr.derived_expr.(^ast.Selector_Expr)
        pac  := select.expr.derived_expr.(^ast.Ident).name
        name := select.field.derived_expr.(^ast.Ident).name
        return DPacObject{
            type = strings.clone("Reference"),// @Temporary: later the type will be a typeid
            value = DPacRef {
                pac =strings.clone(pac),
                name=strings.clone(name),
            },
        }
    case ^ast.Ident:
        ident_expr := ident.(^ast.Ident)
        return DPacObject{
            type  = strings.clone("Reference"),
            value = DPacRef{
                pac ="",
                name=strings.clone(ident_expr.derived_expr.(^ast.Ident).name),
            },
        }
    }
    return DPacObject{}
}

generate_literal :: proc(tok : ^tokenizer.Token) -> DPacLiteral {
    lit : DPacLiteral
    #partial switch tok.kind {
    case .Ident: fallthrough
    case .String:
        lit = DPacLiteral(strings.clone(tok.text))
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
parse_src :: proc(p: ^parser.Parser, src: string, allocator := context.allocator) -> ^ast.File {
    context.allocator = allocator
    NO_POS :: tokenizer.Pos{}
    file := ast.new(ast.File, NO_POS, NO_POS)
    file.pkg = nil
    file.src = string(src)
    file.fullpath = "---"
    if parse_file(p, file) {
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
