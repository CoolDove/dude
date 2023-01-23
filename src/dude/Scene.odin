package dude

import "core:log"
import "core:encoding/json"
import "core:math/linalg"
import "core:strings"

import "pac:assimp"

import "ecs"

Scene :: struct {
    loader : proc(world: ^ecs.World),
    update : proc(game: ^Game, world: ^ecs.World),
    unloader : proc(world: ^ecs.World),
}