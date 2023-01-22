package main

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

ModelAsset :: struct {
    meshes : map[string]TriangleMesh,// Here stores the actual mesh data
    assimp_scene : ^assimp.Scene,
}
ModelAssetSceneTree :: struct {
    name : strings.Builder,
    mesh : ^TriangleMesh,
    parent, next, lchild : ^ModelAssetSceneTree,
}

res_load_model :: proc(path: string, shader: u32, texture: u32, scale: f32) -> (^ModelAsset, ResourceError) {
    fpath := make_path(path)
    defer delete(fpath)

    raw_asset := assimp.import_file(fpath, cast(u32) assimp.PostProcessPreset_MaxQuality)

    if raw_asset == nil { return nil, .Invalid_Path }

    key := make_path_key(path)

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

res_unload_model :: proc(path: string) {
    key := make_path_key(path)
    defer delete(key)

    if !(key in resource_manager.resources) do return

    asset := cast(^ModelAsset)resource_manager.resources[key]

    for name, mesh in &asset.meshes {
        mesh_destroy(&mesh)
    }
    clear(&asset.meshes)

    assimp.release_import(asset.assimp_scene)
}

res_get_model :: proc(path: string) -> ^ModelAsset {
    key := make_path_key(path, context.temp_allocator)
    if model, ok := resource_manager.resources[key]; ok {
        return cast(^ModelAsset)model
    } else {
        return nil
    }
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