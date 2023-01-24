package dude

import "core:math/linalg"
import "ecs"

DebugInfo :: struct {
    debug_name : string,
}

Camera :: struct {
    // Need a transform to work.
    using component : ecs.Component,
    fov : f32,
    near, far : f32,
    tag : string,
}

// World space allow, and the z is used to mark the depth.
SpriteRenderer :: struct {
    // Need a transform to work.
    using comp : ecs.Component,
    texture_id : u32,
    size, pos, pivot : Vec2,
    space : SpriteSpace,
    color : Color,
}

SpriteSpace :: enum {
    World, Screen,
}

MeshRenderer :: struct {
    using component : ecs.Component,
    mesh : ^TriangleMesh,
    transform_matrix: linalg.Matrix4x4f32,
}

Light :: struct {
    direction : Vec3,
    color     : Vec4,
}

TextRenderer :: struct {
    // ...
}