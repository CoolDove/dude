package dude

import "core:math/linalg"
import "ecs"

DebugInfo :: struct {
    debug_name : string,
}

// ## Camera
Camera :: struct {
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

// ## Mesh Renderer
MeshRenderer :: struct {
    using component : ecs.Component,
    mesh : ^TriangleMesh,
    transform_matrix: linalg.Matrix4x4f32,
}

// ## Text Renderer
TextRenderer :: struct {
    // ...
}

// ## Light
Light :: struct {
    using component : ecs.Component,
    direction : Vec3,
    color     : Vec4,
}