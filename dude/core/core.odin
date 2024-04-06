package core

import dd "../"


app := &dd.app
game := &dd.game


Game :: dd.Game
Application :: dd.Application
Window:: dd.Window

DudeConfig :: dd.DudeConfig
DudeConfigCallbacks :: dd.DudeConfigCallbacks
DudeConfigWindow :: dd.DudeConfigWindow

// ** Core
dude_main :: dd.dude_main
dispatch_update :: dd.dispatch_update

get_global_tweener :: proc() -> ^dd.Tweener {
    return &dd.game.global_tweener
}

Vec2 :: dd.Vec2
Vec3 :: dd.Vec3
Vec4 :: dd.Vec4

Vec2i :: dd.Vec2i
Vec3i :: dd.Vec3i
Vec4i :: dd.Vec4i

Rect :: dd.Rect

Color :: dd.Color
Color32 :: dd.Color32

Quaternion :: dd.Quaternion

FORWARD3 :: dd.FORWARD3
UP3 :: dd.UP3
RIGHT3 :: dd.RIGHT3

UP2 :: dd.UP2
RIGHT2 :: dd.RIGHT2

// ** utils
vec_i2f :: dd.vec_i2f
vec_f2i :: dd.vec_f2i

col_u2f :: dd.col_u2f
col_f2u :: dd.col_f2u
col_i2u :: dd.col_i2u
col_i2f :: dd.col_i2f

enum_step :: dd.enum_step