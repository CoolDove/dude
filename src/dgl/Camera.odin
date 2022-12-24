package dgl


import "core:math/linalg"

Camera :: struct {
    using transform : Transform,
    fov, aspect : f32,
    near, far   : f32
}

camera_get_matrix_vp :: proc(cam: ^Camera) -> linalg.Matrix4x4f32 {
    forward := Vec3{0, 0, 1}
    forward = linalg.quaternion_mul_vector3(cam.orientation, forward)
    
    view := linalg.matrix4_look_at(
        cam.position, cam.position + forward, Vec3{0, 1, 0},
    )

    project := linalg.matrix4_perspective_f32(45, 1, 0, 300)

    return linalg.matrix_mul(view, project)

}

