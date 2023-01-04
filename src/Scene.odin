package main

import "core:log"
import "core:encoding/json"
import "core:math/linalg"

import "pac:assimp"

Scene :: struct {
    meshes : map[^assimp.Mesh]TriangleMesh,
    assimp_scene : ^assimp.Scene,
}

prepare_scene :: proc(scene: ^Scene, aiscene: ^assimp.Scene, shader, texture: u32) {
    scene.assimp_scene = aiscene
    for i in 0..<aiscene.mNumMeshes {
        aimesh := aiscene.mMeshes[i]
        scene.meshes[aimesh] = TriangleMesh{}
        aimesh_to_triangle_mesh(aimesh, &scene.meshes[aimesh], shader, texture)
    }
}

aimesh_to_triangle_mesh :: proc(aimesh: ^assimp.Mesh, triangle_mesh: ^TriangleMesh, shader, texture: u32, scale:f32= 1) {
    log.debugf("Processing aimesh: {}...", assimp.string_clone_from_ai_string(&aimesh.mName, context.temp_allocator))

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
    log.debugf("Triangle mesh created.")

}

DoveScene :: struct {
    name : string,
    root : DoveSceneNode,
}
DoveSceneNode :: struct {
    mesh : string,
    position, euler, scal : linalg.Vector3f32,
    children : [dynamic]DoveSceneNode,
}

dove_scene_file_test :: proc() {
}
