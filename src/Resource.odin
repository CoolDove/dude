package main


import "core:os"
import "core:c/libc"
import "core:path/filepath"
import "core:strings"
import "core:slice"

import gl "vendor:OpenGL"
import "vendor:stb/image"

import "dgl"

// A global resource manager. 
// Manage shaders, textures, models, fonts.

// All resources should be placed in the ./res/ folder.

ResourceError :: enum {
    Failed_To_Load_Texture,
    Embbed_Key_Has_Exists,
    Key_Has_Exists,
}

ResourceManager :: struct {
    resources : map[string]rawptr,
    embbed_data : map[string][]byte,
}

@(private="file")
resource_manager : ResourceManager

Texture :: struct {
    size : Vec2i,
    texture_id : u32, // OpenGL texture id
}

// path relative to the ./res/
res_load_texture :: proc(path: string, allocator:= context.allocator) -> (^Texture, ResourceError) {
    context.allocator = allocator

    using resource_manager
    key := make_path_key(path)
    fpath := make_path(path)
    defer delete(fpath)

    if key in resources {
        delete(key)
        return nil, .Key_Has_Exists
    }

    dgltex : dgl.Texture
    if key in embbed_data {
        dgltex = dgl.texture_load(embbed_data[key])
    } else {
        dgltex = dgl.texture_load(fpath)
    }
    if dgltex.texture_id == 0 { return nil, .Failed_To_Load_Texture } 
    texture := new(Texture)
    texture.size = dgltex.size
    texture.texture_id = dgltex.texture_id
    resources[key] = texture
    return texture, nil
}

res_unload_texture :: proc(path: string) -> ResourceError {
    using resource_manager
    key := make_path_key(path)
    defer delete(key)
    if key in resources {
        texture :^Texture= cast(^Texture)resources[key]
        gl.DeleteTextures(1, &texture.texture_id)
    }
    return nil
}

res_get_texture :: proc(path: string) -> ^Texture {
    key := make_path_key(path, context.temp_allocator)
    if tex, ok := resource_manager.resources[key]; ok {
        return cast(^Texture)tex
    } else {
        return nil
    }
}

res_load_model :: proc(path: string) {
}

res_add_embbed :: proc(path: string, data: []byte) -> ResourceError {
    using resource_manager
    key := make_path_key(path)
    if !(key in embbed_data) {
        embbed_data[key] = data
        return nil
    } else {
        return .Embbed_Key_Has_Exists
    }
}

res_unload :: proc(path: string) {
}

@(private="file")
RESOURCE_FOLDER :: "res"

@(private="file")
make_path :: proc(path: string, allocator:= context.allocator) -> string {
    context.allocator = allocator
    current := os.get_current_directory()
    defer delete(current)
    the_path := filepath.join({current, RESOURCE_FOLDER, path})
    to_slash_path, new_alloc := filepath.to_slash(the_path)
    if new_alloc do delete(the_path)
    return to_slash_path
}

@(private="file")
make_path_key :: proc(path: string, allocator:= context.allocator) -> string {
    context.allocator = allocator
    return filepath.clean(path)
}