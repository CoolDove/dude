package dude

import "core:math/linalg"
import "ecs"

DebugInfo :: struct {
    debug_name : string,
}


// ## Camera
Camera :: struct #packed {
    using component : ecs.Component,
    type : CameraProjectType,
    size : f32, // for ortho camera
    fov : f32,  // for persp camera
    near, far : f32,
    tag : string,
}

CameraProjectType :: enum {
    Persp, Ortho,
}


// ## Sprite Renderer
// World space allow, and the z is used to mark the depth.
SpriteRenderer :: struct #packed {
    using component : ecs.Component,
    enable : bool,
    texture_id : u32,
    size, pivot : Vec2,
    space : SpriteSpace,
    color : Color,
    // impl
    vbo, ebo : u32,
}

SpriteSpace :: enum {
    World, Screen,
}

// ## Mesh Renderer
MeshRenderer :: struct #packed {
    using component : ecs.Component,
    mesh : ^TriangleMesh,
    transform_matrix: linalg.Matrix4x4f32,
}

// ## Text Renderer
TextRenderer :: struct #packed {
    // ...
}

// ## Light
Light :: struct #packed {
    using component : ecs.Component,
    direction : Vec3,
    color     : Vec4,
}