package main

import "core:math/linalg"


DebugInfo :: struct {
    debug_name : string,
}

SpriteRenderer :: struct {
    texture_id : u32,
    size, pos, pivot : Vec2,
}

MeshRenderer :: struct {
    // mesh : ^TriangleMesh,
    name : string,
    transform_matrix: linalg.Matrix4x4f32,
}

Light :: struct {
    using lightdata : LightData,
}

TextRenderer :: struct {
    // ...
}