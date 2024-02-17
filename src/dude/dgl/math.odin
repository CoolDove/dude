package dgl

import "core:strings"
import "core:time"
import "core:math"
import "core:log"
import "core:math/rand"
import "core:math/linalg"
import glm "core:math/linalg/glsl"
import gl "vendor:OpenGL"

matrix_srt :: proc(scale : Vec3, rotation: linalg.Quaternionf32, position: Vec3) -> linalg.Matrix4x4f32 {
    mat_scale := linalg.matrix4_scale(scale)
    mat_rotation := linalg.matrix4_from_quaternion(rotation)
    mat_position := linalg.matrix4_translate(position)

    return linalg.matrix_mul(mat_position, linalg.matrix_mul(mat_rotation, mat_scale))
}

matrix_camera_vp_persp :: proc(position : Vec3, orientation: linalg.Quaternionf32, fov, near, far, aspect: f32) -> linalg.Matrix4x4f32 {
    using linalg
    forward := quaternion_mul_vector3(orientation, Vec3{0, 0, 1})
    view := matrix4_look_at(position, position + forward, Vec3{0, 1, 0})
    project := matrix4_perspective_f32(math.to_radians(fov), aspect, near, far)
    return matrix_mul(project, view)
}

matrix_camera_vp_ortho :: proc(position : Vec3, orientation: linalg.Quaternionf32, width, height, near, far: f32) -> linalg.Matrix4x4f32 {
    using linalg
    hwidth, hheight := width * 0.5, height * 0.5
    forward := quaternion_mul_vector3(orientation, Vec3{0, 0, 1})
    view := matrix4_look_at(position, position + forward, Vec3{0, 1, 0})
    project := glm.mat4Ortho3d(-hwidth, hwidth, -hheight, hheight, near, far)
    return matrix_mul(project, view)
}