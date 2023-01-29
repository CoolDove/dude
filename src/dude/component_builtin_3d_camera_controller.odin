package dude

import "core:log"
import "core:math/linalg"

import "ecs"

// Transform needed
BuiltIn3DCameraController :: struct {
    using component : ecs.Component,
    move_speed, rotate_speed : f32,
}

built_in_3dcamera_controller_update :: proc(world: ^ecs.World) {
    controllers := ecs.get_components(world, BuiltIn3DCameraController)
    if controllers == nil || len(controllers) == 0 do return
    for controller in controllers {
        transform := ecs.get_component(controller.world, controller.entity, Transform)
        camera    := ecs.get_component(controller.world, controller.entity, Camera)

        forward := linalg.quaternion_mul_vector3(transform.orientation, FORWARD3)
        up      := UP3
        right   := linalg.cross(up, forward)

        if get_key(.W) { transform.position += forward * controller.move_speed }
        if get_key(.S) { transform.position -= forward * controller.move_speed }
        if get_key(.E) { transform.position += up * controller.move_speed }
        if get_key(.Q) { transform.position -= up * controller.move_speed }
        if get_key(.A) { transform.position += right * controller.move_speed }
        if get_key(.D) { transform.position -= right * controller.move_speed }

        { 
            using camera
            if get_key(.J) && fov < 89 do fov += 1
            if get_key(.K) && fov > 1  do fov -= 1
            if get_mouse_button(.Right) {
                motion := get_mouse_motion()
                motion.y *= controller.rotate_speed
                motion.x *= - controller.rotate_speed
                r := linalg.quaternion_from_euler_angles(motion.y, motion.x, 0, .XYZ)
                transform.orientation = linalg.quaternion_mul_quaternion(transform.orientation, r)
            }
        }
    }
}