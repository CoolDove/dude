package dude


import "core:math/linalg"
import glm "core:math/linalg/glsl"

import "dgl"
import "ecs"

calc_camera_vp :: proc(camera: ^Camera) -> linalg.Matrix4x4f32 {
    using ecs
    transform := get_component(camera.component, Transform)
    wnd_width, wnd_height := cast(f32)game.window.size.x, cast(f32)game.window.size.y
    mtx : linalg.Matrix4x4f32 = ---
    switch camera.type {
    case .Persp:
        mtx = dgl.matrix_camera_vp_persp(
            transform.position, 
            transform.orientation,
            camera.fov, camera.near, camera.far,
            wnd_width/wnd_height,
        )
    case .Ortho:
        mtx = dgl.matrix_camera_vp_ortho(
            transform.position, 
            transform.orientation,
            wnd_width * camera.size, wnd_height * camera.size, 
            camera.near, camera.far,
        )
    }
    return mtx
}