package main

import "core:fmt"
import "core:log"
import "core:math"
import "core:mem"
import "core:strings"
import "core:time"
import "core:slice"
import "core:runtime"
import "core:reflect"
import "core:math/linalg"

import "../dude"
import "../dude/ecs"

when dude.DUDE_3D_GAME {

scene_mushroom := dude.Scene { mushroom_scene_loader, mushroom_update, mushroom_scene_unloader }

@(private="file")
mushroom_allocator : mem.Allocator
@(private="file")
mushroom_buffer : []byte

LevelArena :: struct {
    buffer : []byte,
    arena : mem.Arena,
    allocator : mem.Allocator,
}

// mush_arena : LevelArena


@(private="file")
mushroom_scene_loader :: proc(world: ^ecs.World) {
    using dude
    using ecs

    {// init allocator
        // mush_arena.buffer = make([]byte, 128 * 1024 * 1024)
        // mem.arena_init(&mush_arena.arena, mush_arena.buffer)
        // mush_arena.allocator = mem.arena_allocator(&mush_arena.arena)
    }

    mush : ^ModelAsset
    texture : ^Texture
    {
        // context.allocator = mush_arena.allocator
        mushroom, err := res_load_model("model/mushroom.fbx", 
            dude.res_get_shader("shader/builtin_mesh_opaque.shader").id,
            dude.res_get_texture("texture/white.tex").id, 
            0.01)
        if err != nil {
            log.errorf("MushroomScene: Error loading mushroom.fbx: {}", err)
            return
        }
        mush = mushroom

        texture, _ = res_load_texture("texture/box.png")
    }

    create_world_space_sprite(world, texture, "WorldA", {1, 0, 0})
    create_world_space_sprite(world, texture, "WorldB", {1.2, 0, 0})
    create_world_space_sprite(world, texture, "WorldC", {0, .1, 0})
    create_world_space_sprite(world, texture, "WorldD", {0, 1, 1})
    create_world_space_sprite(world, texture, "WorldE", {.5, 0, .5})
    create_world_space_sprite(world, texture, "WorldF", {0, .1, 0})
    
    add_mesh_renderers(world, mush)// mesh renderers

    prefab_editor_camera(world, "MainCamera", true)
    prefab_light(world, "MainLight")

    log.debugf("Scnene build up")
}

@(private="file")
mushroom_update :: proc(world: ^ecs.World, ) {
    using dude
    camera := get_main_camera(world)
    if get_key_down(.Z) {
        if camera != nil {
            if camera.type == .Ortho { 
                camera.type = .Persp 
            } else { 
                camera.type = .Ortho 
                camera.size = 1
            }
            log.debugf("Camera type toggled to: {}", camera.type)
        }
    }

    if get_key_down(.B) { remove_sprite(world) }
    if get_key_down(.V) { remove_sprite_entity(world) }
    if get_key_down(.C) { 
        create_world_space_sprite(world, res_get_texture("texture/box.png"), "DynamicSprite", {0, 0, 0})
    }

    time_delta := time.duration_seconds(app.duration_frame)
    if camera.type == .Ortho {
        if get_key(.J) do camera.size = math.max(camera.size - cast(f32)time_delta * 2, 0)
        else if get_key(.K) do camera.size = math.min(camera.size + cast(f32)time_delta * 2, 99)
    }
}

@(private="file")
mushroom_scene_unloader :: proc(world: ^ecs.World) {
    // context.allocator = mush_arena.allocator
    dude.res_unload_model("model/mushroom.fbx")
    dude.res_unload_texture("texture/box.png")
    free_all()
    {
        free(raw_data(mushroom_buffer))
    }
}

@(private="file")
add_mesh_renderers :: proc(world: ^ecs.World, asset : ^dude.ModelAsset) {
    default_transform := dude.Transform {
        position = {0, 0, 0},
        orientation = linalg.QUATERNIONF32_IDENTITY,
        scale = {1, 1, 1},
    }
    for name, mesh in &asset.meshes {
        mesh_name := strings.to_string(mesh.name)
        ent := ecs.add_entity(world, ecs.EntityInfo{name=mesh_name})
        log.debugf("Mesh entity: {}.{}", ent, mesh_name)

        ecs.add_component(world, ent, default_transform)
        mesh_renderer := ecs.add_component(world, ent, dude.MeshRenderer)
        mesh_renderer.mesh = &mesh
        mesh_renderer.transform_matrix = linalg.MATRIX4F32_IDENTITY
        ecs.add_component(world, ent, dude.DebugInfo{
            fmt.aprintf("DBGNAME: {}", mesh_name),
        })
    }
}


@(private="file")
remove_sprite :: proc(world: ^ecs.World) {
    using dude
    sprites := ecs.get_components(world, dude.SpriteRenderer)
    sprite : ^SpriteRenderer
    for sp, i in &sprites {
        if sp.space == .World {
            sprite = &sp
            break
        }
    }
    if sprite != nil {
        entity := sprite.entity
        ecs.remove_component(world, entity, dude.SpriteRenderer)
        log.debugf("Remove sprite of entity: {}", ecs.entity_info(world, entity).name)
    } else {
        log.warnf("No sprite to remove")
    }
}
@(private="file")
remove_sprite_entity :: proc(world: ^ecs.World) {
    using dude
    sprites := ecs.get_components(world, dude.SpriteRenderer)
    sprite : ^SpriteRenderer
    for sp, i in &sprites {
        if sp.space == .World {
            sprite = &sp
            break
        }
    }
    if sprite != nil {
        ent_name := ecs.entity_info(world, sprite.entity).name
        if ecs.remove_entity(world, sprite.entity) {
            log.debugf("Remove entity: {}", ent_name)
        }
    } else {
        log.warnf("No sprite entity to remove")
    }
}
create_world_space_sprite :: proc(world: ^ecs.World, texture: ^dude.Texture, name: string, pos: dude.Vec3) {
    using dude
    sp := ecs.add_entity(world, {name=name})
    scale :f32= 0.02
    sprite := SpriteRenderer {
        texture_id = texture.id,
        enable = true,
        size = {cast(f32)texture.size.x * scale, cast(f32)texture.size.y * scale},
        pivot = {0.0, 0.0},
        space = .World,
        color = COLORS.WHITE,
    }
    transform := Transform {
        position = pos,
        orientation = linalg.QUATERNIONF32_IDENTITY,
        scale = {1, 1, 1},
    }
    ecs.add_components(world, sp,
        transform, sprite)
}


}
