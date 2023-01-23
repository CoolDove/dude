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
        transform := ecs.get_component(world, controller.entity, Transform)

        forward := linalg.quaternion_mul_vector3(transform.orientation, FORWARD3)
        up      := linalg.quaternion_mul_vector3(transform.orientation, UP3)
        right   := linalg.cross(forward, up)

        if get_key(.W) { transform.position += forward * controller.move_speed }
        if get_key(.S) { transform.position -= forward * controller.move_speed }
        if get_key(.E) { transform.position += up * controller.move_speed }
        if get_key(.Q) { transform.position -= up * controller.move_speed }
        if get_key(.A) { transform.position += right * controller.move_speed }
        if get_key(.D) { transform.position -= right * controller.move_speed }
    }
}