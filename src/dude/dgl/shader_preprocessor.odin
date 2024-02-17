package dgl

import "core:fmt"
import "core:strings"

@(private="file")
_shader_libs : map[string]string
@(private="file")
_shader_lib_strings : strings.Builder

// Support:
// #include "libname"
shader_preprocess :: proc(source : string, allocator:= context.allocator) -> string {
    context.allocator = allocator
    using strings
    sb : Builder
    builder_init(&sb)//; defer builder_destroy(&sb)// Should be manually deleted

    ite_src := source
    name_buffer : Builder
    builder_init(&name_buffer); defer builder_destroy(&name_buffer)
    next_line : for l in split_lines_iterator(&ite_src) {
        if len(l) > 12 {// length of [#include "x"]
            if l[:9] == "#include " {
                i := 9
                for l[i] == ' ' do i+=1
                if l[i] == '\"' {
                    i += 1
                    builder_reset(&name_buffer)
                    for i < len(l) {
                        if l[i] == '\"' {
                            include_name := to_string(name_buffer)
                            if include_source, ok := shader_preprocess_get_lib_source(include_name); ok {
                                write_string(&sb, "\n// include ")
                                write_string(&sb, include_name)
                                write_byte(&sb, '\n')
                                write_string(&sb, include_source)
                                continue next_line
                            }
                        } else {
                            write_byte(&name_buffer, l[i])
                        }
                        i+=1
                    }
                }
            }
        }
        write_string(&sb, l)
        write_byte(&sb, '\n')
    }
    return to_string(sb)
}

shader_preprocess_add_lib :: proc(name, source: string) {
    if len(_shader_libs) == 0 {
        strings.builder_init(&_shader_lib_strings)
        _shader_libs = make(map[string]string)
        append(&release_handler, proc() {
            delete(_shader_libs)
            strings.builder_destroy(&_shader_lib_strings)
        })
    }
    start := strings.builder_len(_shader_lib_strings)
    strings.write_string(&_shader_lib_strings, source)
    end := strings.builder_len(_shader_lib_strings)
    src := strings.to_string(_shader_lib_strings)[start:end]
    map_insert(&_shader_libs, name, src)
}

shader_preprocess_get_lib_source :: proc(name: string) -> (string, bool) {
    return _shader_libs[name]
}