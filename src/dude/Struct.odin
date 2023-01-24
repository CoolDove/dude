package dude

import "core:math/linalg"
import "dgl"

Vec2 :: dgl.Vec2
Vec3 :: dgl.Vec3
Vec4 :: dgl.Vec4
Color :: distinct Vec4

Vec2i :: dgl.Vec2i
Vec3i :: dgl.Vec3i
Vec4i :: dgl.Vec4i

Quaternion :: linalg.Quaternionf32

VertexPCU  :: dgl.VertexPCU
VertexPCNU :: dgl.VertexPCNU

Transform :: struct {
    position    : Vec3,
    orientation : linalg.Quaternionf32,
    scale       : Vec3,
}

FORWARD3 :: Vec3{0, 0, 1}
UP3 :: Vec3{0, 1, 0}
RIGHT3 :: Vec3{1, 0, 0}

UP2 :: Vec2{0, 1}
RIGHT2 :: Vec2{1, 1}
