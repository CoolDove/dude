package dgl

import "core:strings"
import "core:time"
import "core:math"
import "core:log"
import "core:math/rand"
import "core:math/linalg"
import gl "vendor:OpenGL"


matrix_srt :: proc(scale : Vec3, rotation: quaternion128, position: Vec3) -> linalg.Matrix4x4f32 {
    mat_scale := linalg.matrix4_scale(scale)
    mat_rotation := linalg.matrix4_from_quaternion(cast(linalg.Quaternionf32)rotation)
    mat_position := linalg.matrix4_translate(position)

    return linalg.matrix_mul(mat_position, linalg.matrix_mul(mat_rotation, mat_scale))
}