package dude

import "core:math/linalg"
import "dgl"


Quaternion :: linalg.Quaternionf32

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
