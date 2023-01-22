package main

import "core:log"
import "core:encoding/json"
import "core:math/linalg"
import "core:strings"

import "pac:assimp"

Scene :: struct {
    // Old things, remove after the real scene is done.
    meshes : map[^assimp.Mesh]TriangleMesh,
    assimp_scene : ^assimp.Scene,
}

prepare_scene :: proc(scene: ^Scene, aiscene: ^assimp.Scene, shader, texture: u32) {
    // scene.assimp_scene = aiscene
    // for i in 0..<aiscene.mNumMeshes {
    //     aimesh := aiscene.mMeshes[i]
    //     scene.meshes[aimesh] = TriangleMesh{}
    //     mesh := &scene.meshes[aimesh]
    //     sb_name := &mesh.name
    //     strings.builder_init(sb_name, 0, cast(int) aimesh.mName.length)
    //     aimesh_to_triangle_mesh(aimesh, mesh, shader, texture)
    //     mesh_upload(mesh, {.PCNU, .PCU})
    // }
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