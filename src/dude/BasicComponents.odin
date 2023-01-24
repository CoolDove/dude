package dude

import "core:math/linalg"
import "ecs"

DebugInfo :: struct {
    debug_name : string,
}

Camera :: struct #packed {
    using component : ecs.Component,
    fov : f32,
    near, far : f32,
    tag : string,
}

// World space allow, and the z is used to mark the depth.
SpriteRenderer :: struct #packed {
    using component : ecs.Component,
    texture_id : u32,
    size, pivot : Vec2,
    space : SpriteSpace,
    color : Color,
}

SpriteSpace :: enum {
    World, Screen,
}

MeshRenderer :: struct #packed {
    using component : ecs.Component,
    mesh : ^TriangleMesh,
    transform_matrix: linalg.Matrix4x4f32,
}

Light :: struct #packed {
    using component : ecs.Component,
    direction : Vec3,
    color     : Vec4,
}

TextRenderer :: struct #packed {
    // ...
}