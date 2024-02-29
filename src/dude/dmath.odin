package dude

import "core:log"
import "core:math"

coord_world2screen :: proc(camera: ^RenderCamera, pos: Vec2) -> Vec2 {
    p :Vec2= pos + camera.position * Vec2{-1,1}
    sa := math.sin(camera.angle)
    ca := math.cos(camera.angle)
    p = Vec2{ p.x * ca + p.y * sa, p.y * ca - p.x * sa }
    p = p * 0.5 * camera.size
    p = p + 0.5 * camera.viewport
    return p
}

rotate_vector :: proc(v: Vec2, rad: f32) -> Vec2 {
    sa := math.sin(rad)
    ca := math.cos(rad)
    v := Vec2{ v.x * ca + v.y * sa, v.y * ca - v.x * sa }
    return v
}