package dude

import "core:log"
import "core:math"

// FIXME:coord_world2screen
coord_world2screen :: proc(camera: ^RenderCamera, pos: Vec2) -> Vec2 {
    p := pos;
    p = p + Vec2{-1,1} * camera.position;
    sa := math.sin(-camera.angle);
    ca := math.cos(-camera.angle);
    p = Vec2{ p.x * ca + p.y * sa, p.y * ca - p.x * sa };
    scale := Vec2{ camera.size/camera.viewport.x, camera.size/camera.viewport.y };
    p = p*scale*0.5;
    p = p * camera.viewport;
    p = p + camera.viewport * 0.5;
    return p
}

rotate_vector :: proc(v: Vec2, rad: f32) -> Vec2 {
    sa := math.sin(rad)
    ca := math.cos(rad)
    v := Vec2{ v.x * ca + v.y * sa, v.y * ca - v.x * sa }
    return v
}