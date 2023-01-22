package dgl

import "core:math"
import "core:math/linalg"

// Camera :: struct {
//     using transform : Transform,
//     fov : f32,
//     near, far : f32,
// }

// camera_get_matrix_vp :: proc(cam: ^Camera, aspect: f32) -> linalg.Matrix4x4f32 {
camera_get_matrix_vp :: proc(position : Vec3, orientation: linalg.Quaternionf32, fov, near, far, aspect: f32) -> linalg.Matrix4x4f32 {
    forward := linalg.quaternion_mul_vector3(orientation, Vec3{0, 0, 1})
    view := linalg.matrix4_look_at(position, position + forward, Vec3{0, 1, 0})
    project := linalg.matrix4_perspective_f32(math.to_radians(fov), aspect, near, far)
    return linalg.matrix_mul(project, view)
}