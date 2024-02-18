package dude

import "core:math"
import "core:math/linalg"
import "ecs"
import "dgl"

// ## Sprite Renderer
// World space allow, and the z is used to mark the depth.
// pivot: (0.5, 0.5) means the pivot is at the center of the sprite, (1, 1) the right-down corner.
// SpriteRenderer :: struct {
    // using component : ecs.Component,
    // enable : bool,
    // texture_id : u32,
    // size, pivot : Vec2,
    // space : SpriteSpace,
    // color : Color,
// }
// 
// SpriteSpace :: enum {
    // World, Screen,
// }
// 
// // - For world space: replace the `model matrix`.
// // - For screen space: replace the `model matrix` and `vp matrix`.
// calc_sprite_matrix :: proc(sprite: ^SpriteRenderer) -> linalg.Matrix4x4f32 {
    // transform := ecs.get_component(sprite.component, Transform)
    // using linalg
    // switch sprite.space {
    // case .World:
        // offset := sprite.pivot
        // offset -= 0.5
        // offset *= -2
        // mtx_local := matrix_mul(
            // matrix4_scale(Vector3f32{sprite.size.x, sprite.size.y, 1}),
            // matrix4_translate(Vector3f32{offset.x, offset.y, 0}))
        // mtx_world := dgl.matrix_srt(transform.scale, transform.orientation, transform.position)
        // return matrix_mul(mtx_world, mtx_local)
    // case .Screen: // TODO
// 
    // }
    // return linalg.MATRIX4F32_IDENTITY
// }
// 
// get_sprite_quad :: #force_inline proc() -> ^RenderMesh(VertexPCNU) {
    // if sprite_quad == nil do sprite_quad = init_sprite_quad()
    // return sprite_quad
// }
// 
// @(private="file")
// sprite_quad : ^RenderMesh(VertexPCNU)
// /*
  // a------b
  // |      |
  // |      |
  // c------d
  // a: (-1, -1) (0, 1)
  // b: (1, 1) (1, 1)
  // c: (-1, 1) (0, 0)
  // d: (1, -1) (1, 0)
// */
// @(private="file")
// init_sprite_quad :: proc() -> ^RenderMesh(VertexPCNU) {
    // rmesh := new(RenderMesh(VertexPCNU))
    // a := VertexPCNU{ position = {-1, -1, 0}, uv = {0, 0}, }
    // b := VertexPCNU{ position = {1, -1, 0}, uv = {1, 0}, }
    // c := VertexPCNU{ position = {-1, 1, 0}, uv = {0, 1}, }
    // d := VertexPCNU{ position = {1, 1, 0}, uv = {1, 1}, }
    // append(&rmesh.vertices, a, b, c, d)
    // indices := [6]u32{0, 1, 2, 1, 3, 2}
    // render_mesh_upload(rmesh, indices[:])
    // return rmesh
// }
