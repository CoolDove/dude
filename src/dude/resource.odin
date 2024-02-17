package dude

import "core:log"
import "core:io"
import "core:os"
import "core:c/libc"
import "core:path/filepath"
import "core:strings"
import "core:hash"
import "core:slice"

import gl "vendor:OpenGL"
import "vendor:stb/image"

import "dgl"

// A global resource manager. 
// Manage shaders, textures, models, fonts.

// All resources should be placed in the ./res/ folder.

@(private="file")
MODEL_ASSETS :: true

ResourceError :: enum {
    Invalid_Path,
    Dont_Support_Embbed_Load,
    Only_Embbed_Load,
    Embbed_Key_Has_Exists,
    Key_Has_Exists,
    Shader_Error,
}

ResourceManager :: struct {
    resources : map[ResKey]rawptr,
    embbed_data : map[ResKey][]byte,
}

resource_manager : ResourceManager
 
// ## Resource
Texture :: struct {
    size : Vec2i,
    id : u32, // OpenGL texture id
}

// path relative to the ./res/
res_load_texture :: proc(keystr: string) -> (^Texture, ResourceError) {
    using resource_manager
    fpath := make_path(keystr)
    defer delete(fpath)

    key := res_key(keystr)

    if key in resources { return nil, .Key_Has_Exists }

    dgltex : dgl.Texture
    if key in embbed_data {
        dgltex = dgl.texture_load(embbed_data[key])
    } else {
        dgltex = dgl.texture_load(fpath)
    }
    if dgltex.id == 0 { return nil, .Invalid_Path } 
    texture := new(Texture)
    texture.size = dgltex.size
    texture.id = dgltex.id
    resources[key] = texture
    return texture, nil
}

res_add_texture :: proc(keystr: string, texture: ^Texture) -> ResourceError {
    using resource_manager
    key := res_key(keystr)
    if key in resources { return .Key_Has_Exists }
    resources[key] = texture
    return nil
}

res_unload_texture :: proc(keystr: string) {
    using resource_manager
    key := res_key(keystr)
    if key in resources {
        texture :^Texture= cast(^Texture)resources[key]
        gl.DeleteTextures(1, &texture.id)
        free(texture)
    }
    delete_key(&resources, key)

}

res_get_texture :: proc(keystr: string) -> ^Texture {
    return cast(^Texture)resource_manager.resources[res_key(keystr)]
}

// ## Font

res_load_font :: proc(keystr: string, px: f32) -> (^DynamicFont, ResourceError) {
    using resource_manager
    key := res_key(keystr)
    if key in resources { return nil, .Key_Has_Exists }

    assert(key in resource_manager.embbed_data, "Font should be embbed for now.")

    font := font_load_from_mem(raw_data(embbed_data[key]), px)

    if font == nil {
        return nil, .Invalid_Path
    }
    resource_manager.resources[key] = font

    return font, nil
}
res_unload_font :: proc(keystr: string) {
    key := res_key(keystr)
    font := cast(^DynamicFont)resource_manager.resources[key]
    font_destroy(font)
    delete_key(&resource_manager.resources, key)
}

res_get_font :: proc(keystr: string) -> ^DynamicFont {
    key := res_key(keystr)
    font := cast(^DynamicFont)resource_manager.resources[key]
    return font
}

// ## Shader
DShader :: struct {
    id : u32,
}
res_load_shader :: proc(keystr : string) -> (^DShader, ResourceError) { 
    fpath := make_path(keystr)
    defer delete(fpath)

    key := res_key(keystr)
    if key in resource_manager.resources {
        return nil, .Key_Has_Exists
    }

    id : u32

    if source, ok := resource_manager.embbed_data[key]; ok {
        id = dshader_load_from_source(cast(string)source)
    } else if source, ok := os.read_entire_file_from_filename(fpath); ok {
        if !ok { return nil, .Invalid_Path }
        id = dshader_load_from_source(cast(string)source)
        delete(source)
    }

    if id == 0 { return nil, .Shader_Error }

    shader := new(DShader)
    shader.id = id
    resource_manager.resources[key] = shader

    return shader, nil
}

res_unload_shader :: proc(keystr: string) {
    shader := res_get_shader(keystr)
    if shader != nil {
        gl.DeleteProgram(shader.id)
        free(shader)
    }
}

res_get_shader :: proc(keystr: string) -> ^DShader {
    shader := cast(^DShader)resource_manager.resources[res_key(keystr)]
    return shader
}

res_add_embbed :: proc(keystr: string, data: []byte) -> ResourceError {
    using resource_manager
    key := res_key(keystr)
    if !(key in embbed_data) {
        embbed_data[key] = data
        return nil
    } else {
        return .Embbed_Key_Has_Exists
    }
}

@(private="file")
RESOURCE_FOLDER :: "res"

res_list_embbed :: proc() {
    log.debugf("List Embbed Resource: ")
    for key, res in resource_manager.embbed_data {
        log.debugf("> {}", key)
    }
}

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

ResKey :: distinct u64

res_key :: proc(name:string) -> ResKey {
	return cast(ResKey)hash.crc64_xz(raw_data(name)[:len(name)])
}
