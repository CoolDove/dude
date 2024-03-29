﻿package dude

import "core:log"
import "core:encoding/json"
import "core:math/linalg"
import "core:strings"
import "core:runtime"

import "ecs"

Scene :: struct {
    loader : proc(world: ^ecs.World),
    update : proc(world: ^ecs.World),
    unloader : proc(world: ^ecs.World),
}


// Unload current scene and load a new scene.
@private
to_switch_scene : ^Scene

switch_scene :: proc(to_key : string) -> bool {
    assert(to_switch_scene == nil, "Dude: You cannot switch scene twice in one frame.")
    if to, ok := &registered_scenes[to_key]; ok {
        to_switch_scene = to
        return true
    }
    return false
}

load_scene :: proc {
    load_scene_by_key,
}

@private
load_scene_by_ptr :: proc(scene: ^Scene) -> (ok: bool) {
    using game
    using ecs

    context.allocator = runtime.default_allocator()
    world := world_create(runtime.default_allocator())
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
    if load_scene_by_ptr(scene) {
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