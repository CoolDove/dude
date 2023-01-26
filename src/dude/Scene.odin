package dude

import "core:log"
import "core:encoding/json"
import "core:math/linalg"
import "core:strings"

import "pac:assimp"

import "ecs"

Scene :: struct {
    loader : proc(world: ^ecs.World),
    update : proc(world: ^ecs.World),
    unloader : proc(world: ^ecs.World),
}

load_scene :: proc {
    load_scene_by_key,
}

@private
load_scene_ :: proc(scene: ^Scene) -> (ok: bool) {
    using game
    using ecs

    world := world_create()
    add_system(world, built_in_3dcamera_controller_update)

    loader := scene.loader
    if loader != nil {
        loader(world)
    }
    main_world = world
    current_scene = scene
    return true
}

@private
load_scene_by_key :: proc(key: string) -> (ok: bool) {
    using game
    using ecs
    scene := &registered_scenes[key]
    if scene == nil do return false
    if load_scene_(scene) {
        log.debugf("Load scene: {}", key)
        return true
    } else {
        return false
    }
}

unload_scene :: proc() -> (ok:bool) {
    if game.main_world == nil do return false
    using ecs

    unloader := game.current_scene.unloader
    if unloader != nil {
        unloader(game.main_world)
    }
    world_destroy(game.main_world)

    game.main_world = nil
    game.current_scene = nil
    return true
}