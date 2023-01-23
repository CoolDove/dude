package dude

import "core:log"
import "core:os"
import "core:c/libc"
import "core:path/filepath"
import "core:strings"
import "core:slice"

import gl "vendor:OpenGL"
import "vendor:stb/image"

import "pac:assimp"

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
res_load_texture :: proc(key: string, allocator:= context.allocator) -> (^Texture, ResourceError) {
    context.allocator = allocator

    using resource_manager
    fpath := make_path(key)
    defer delete(fpath)

    if key in resources { return nil, .Key_Has_Exists }

    dgltex : dgl.Texture
    if key in embbed_data {
        dgltex = dgl.texture_load(embbed_data[key])
    } else {
        dgltex = dgl.texture_load(fpath)
    }
    if dgltex.texture_id == 0 { return nil, .Invalid_Path } 
    texture := new(Texture)
    texture.size = dgltex.size
    texture.texture_id = dgltex.texture_id
    resources[key] = texture
    return texture, nil
}

res_unload_texture :: proc(key: string) -> ResourceError {
    using resource_manager
    if key in resources {
        texture :^Texture= cast(^Texture)resources[key]
        gl.DeleteTextures(1, &texture.texture_id)
    }
    delete_key(&resources, key)
    return nil
}

res_get_texture :: proc(key: string) -> ^Texture {
    return cast(^Texture)resource_manager.resources[key]
}

ModelAsset :: struct {
    meshes : map[string]TriangleMesh,// Here stores the actual mesh data
    assimp_scene : ^assimp.Scene,
}
ModelAssetSceneTree :: struct {
    name : strings.Builder,
    mesh : ^TriangleMesh,
    parent, next, lchild : ^ModelAssetSceneTree,
}

res_load_model :: proc(key: string, shader: u32, texture: u32, scale: f32) -> (^ModelAsset, ResourceError) {
    fpath := make_path(key)
    defer delete(fpath)

    if key in resource_manager.resources { return nil, .Key_Has_Exists }

    raw_asset := assimp.import_file(fpath, cast(u32) assimp.PostProcessPreset_MaxQuality)

    if raw_asset == nil { return nil, .Invalid_Path }

    asset := new(ModelAsset)
    asset.assimp_scene = raw_asset
    asset.meshes = make(map[string]TriangleMesh)

    for i in 0..<raw_asset.mNumMeshes {
        m := raw_asset.mMeshes[i]
        name := assimp.string_clone_from_ai_string(&m.mName)
        asset.meshes[name] = TriangleMesh{}
        triangle_mesh := &asset.meshes[name]
        strings.builder_init(&triangle_mesh.name)
        aimesh_to_triangle_mesh(m, triangle_mesh, shader, texture)
        mesh_upload(triangle_mesh, {.PCNU, .PCU})
    }

    resource_manager.resources[key] = asset

    // TODO: Build scene tree.
    // ...

    return asset, nil
}

res_unload_model :: proc(key: string) {
    if !(key in resource_manager.resources) do return

    asset := cast(^ModelAsset)resource_manager.resources[key]

    for name, mesh in &asset.meshes {
        mesh_destroy(&mesh)
    }
    clear(&asset.meshes)

    assimp.release_import(asset.assimp_scene)
    delete_key(&resource_manager.resources, key)
}

res_get_model :: proc(key: string) -> ^ModelAsset {
    if model, ok := resource_manager.resources[key]; ok {
        return cast(^ModelAsset)model
    } else {
        return nil
    }
}

res_load_font :: proc(key: string, px: f32) -> (^DynamicFont, ResourceError) {
    using resource_manager
    if key in resources { return nil, .Key_Has_Exists }

    assert(key in resource_manager.embbed_data, "Font should be embbed for now.")

    font := font_load_from_mem(raw_data(embbed_data[key]), px)

    if font == nil {
        return nil, .Invalid_Path
    }
    resource_manager.resources[key] = font

    return font, nil
}
res_unload_font :: proc(key: string) {
    font := cast(^DynamicFont)resource_manager.resources[key]
    font_destroy(font)
    delete_key(&resource_manager.resources, key)
}

res_get_font :: proc(key: string) -> ^DynamicFont {
    font := cast(^DynamicFont)resource_manager.resources[key]
    return font
}

res_add_embbed :: proc(key: string, data: []byte) -> ResourceError {
    using resource_manager
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

res_list_loaded :: proc() {
    sb : strings.Builder
    strings.builder_init(&sb)
    defer strings.builder_destroy(&sb)

    strings.write_string(&sb, "\nList Loaded Resource: \n")

    for key, res in resource_manager.resources {
        strings.write_string(&sb, "> ")
        strings.write_string(&sb, key)
        strings.write_rune(&sb, '\n')
    }
    log.debug(strings.to_string(sb))
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

@(private="file")
aimesh_to_triangle_mesh :: proc(aimesh: ^assimp.Mesh, triangle_mesh: ^TriangleMesh, shader, texture: u32, scale:f32= 1) {
    strings.builder_reset(&triangle_mesh.name)
    strings.write_bytes(&triangle_mesh.name, aimesh.mName.data[:aimesh.mName.length])

    reserve(&triangle_mesh.vertices,    cast(int) aimesh.mNumVertices)
    reserve(&triangle_mesh.uvs,         cast(int) aimesh.mNumVertices)
    reserve(&triangle_mesh.colors,      cast(int) aimesh.mNumVertices)
    reserve(&triangle_mesh.normals,     cast(int) aimesh.mNumVertices)
    reserve(&triangle_mesh.tangents,    cast(int) aimesh.mNumVertices)
    reserve(&triangle_mesh.bitangents,  cast(int) aimesh.mNumVertices)

    color_channel := aimesh.mColors[0]
    uv_channel := aimesh.mTextureCoords[0]

    for i in 0..<aimesh.mNumVertices {
        vertex      := aimesh.mVertices[i] * scale
        color       := color_channel[i] if color_channel != nil else assimp.Color4D{1, 1, 1, 1}
        uv          := uv_channel[i] if uv_channel != nil else Vec3{0, 0, 0}
        normal      := aimesh.mNormals[i] if aimesh.mNormals != nil else Vec3{0, 1, 0}
        tangent     := aimesh.mTangents[i] if aimesh.mTangents != nil else Vec3{0, 1, 0}
        bitangent   := aimesh.mBitangents[i] if aimesh.mBitangents != nil else Vec3{0, 1, 0}

        append(&triangle_mesh.vertices, vertex)
        append(&triangle_mesh.colors, color)
        append(&triangle_mesh.uvs, Vec2{uv.x, uv.y})

        append(&triangle_mesh.normals,      normal)
        append(&triangle_mesh.tangents,     tangent)
        append(&triangle_mesh.bitangents,   bitangent)

    }

    submesh : SubMesh

    reserve(&submesh.triangles, cast(int) aimesh.mNumFaces)

    for i in 0..<aimesh.mNumFaces {
        face := &aimesh.mFaces[i]
        assert(face.mNumIndices == 3)
        indices := face.mIndices[0:3]
        append(&submesh.triangles, TriangleIndices{indices[0], indices[1], indices[2]})
        submesh.shader  = shader
        submesh.texture = texture
    }

    append(&triangle_mesh.submeshes, submesh)
}