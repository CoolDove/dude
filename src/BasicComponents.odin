package main

import "core:math/linalg"
import "ecs"


DebugInfo :: struct {
    debug_name : string,
}

Camera :: struct {
    position : Vec3,
    orientation : Quaternion,
    fov : f32,
    near, far : f32,
    tag : string,
}

SpriteRenderer :: struct {
    texture_id : u32,
    size, pos, pivot : Vec2,
}

MeshRenderer :: struct {
    using component : ecs.Component,
    mesh : ^TriangleMesh,
    transform_matrix: linalg.Matrix4x4f32,
}

Light :: struct {
    using lightdata : LightData,
}

TextRenderer :: struct {
    // ...
}