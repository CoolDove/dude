package main

import "core:strings"
import "pac:assimp"

import_model :: proc(path: string) -> ^assimp.Scene {
    path_cstr := strings.clone_to_cstring(path, context.temp_allocator)
    return assimp.import_file_from_file(path_cstr, .Triangulate)
}