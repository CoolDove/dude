package dude

import "core:math/linalg"
import "dgl"


Vec2 :: dgl.Vec2
Vec3 :: dgl.Vec3
Vec4 :: dgl.Vec4

Vec2i :: dgl.Vec2i
Vec3i :: dgl.Vec3i
Vec4i :: dgl.Vec4i

Rect :: struct {
	x, y: i32,
	w, h: i32,
}

// Rect :: struct #raw_union {
//     using _rect4i : Rect4i,
//     using _rectps : RectPs,
// }

// Rect4i :: struct {
// 	x, y: i32,
// 	w, h: i32,
// }
RectPs :: struct {
    position : Vec2i,
    size : Vec2i,
}

Color :: Vec4
Color32 :: [4]u8

Quaternion :: linalg.Quaternionf32

FORWARD3 :: Vec3{0, 0, 1}
UP3 :: Vec3{0, 1, 0}
RIGHT3 :: Vec3{1, 0, 0}

UP2 :: Vec2{0, 1}
RIGHT2 :: Vec2{1, 1}