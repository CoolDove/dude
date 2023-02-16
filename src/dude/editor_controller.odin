package dude

import "core:log"
import "core:time"
import "core:math/linalg"

import "ecs"

// Transform & Camera required
EditorCameraController :: struct {
    using component : ecs.Component,
    move_speed, rotate_speed : f32,
}

@private
editor_control :: proc(world: ^ecs.World) {
    controllers := ecs.get_components(world, EditorCameraController)
    count := len(controllers)
    if controllers == nil || count == 0 do return
    if count > 1 {
        log.errorf("Dude: There are multiple EditorCameraController component in the scene. Which is invalid.")
        return
    }
    
    for controller in controllers {
        transform := ecs.get_component(controller.world, controller.entity, Transform)
        camera    := ecs.get_component(controller.world, controller.entity, Camera)

        forward := linalg.quaternion_mul_vector3(transform.orientation, FORWARD3)
        up      := UP3
        right   := linalg.cross(up, forward)

        dtime := cast(f32)time.duration_seconds(app.duration_frame)
        move_value := controller.move_speed * dtime

        if get_key(.W) { transform.position += forward * move_value }
        if get_key(.S) { transform.position -= forward * move_value }
        if get_key(.E) { transform.position += up * move_value }
        if get_key(.Q) { transform.position -= up * move_value }
        if get_key(.A) { transform.position += right * move_value }
        if get_key(.D) { transform.position -= right * move_value }

        { 
            using camera
            if get_key(.J) && fov < 89 do fov += 1
            if get_key(.K) && fov > 1  do fov -= 1
            if get_mouse_button(.Right) {
                motion := get_mouse_motion()
                motion.y *= controller.rotate_speed
                motion.x *= - controller.rotate_speed
                motion *= dtime
                r := linalg.quaternion_from_euler_angles(motion.y, motion.x, 0, .XYZ)
                transform.orientation = linalg.quaternion_mul_quaternion(transform.orientation, r)
            }
        }
    }
}