package main

import "core:fmt"
import "core:log"
import "core:strings"
import "core:math/linalg"

import "dude"
import "dude/ecs"

SceneMushroom := dude.Scene { mushroom_scene_loader, nil, mushroom_scene_unloader }

@(private="file")
mushroom_scene_loader :: proc(world: ^ecs.World) {
    using dude
    using ecs
    mushroom, err := res_load_model("model/mushroom.fbx", 
        dude.game.basic_shader.id,
        dude.res_get_texture("texture/white").id, 
        0.01)
    mushroom = res_get_model("model/mushroom.fbx")
    
    if err != nil {
        log.errorf("MushroomScene: Error loading mushroom.fbx: {}", err)
        return
    }

    prefab_camera(world, "MainCamera", true)
    prefab_light(world, "MainLight")

    add_mesh_renderers(world, mushroom)// mesh renderers
}

@(private="file")
mushroom_scene_unloader :: proc(world: ^ecs.World) {
    dude.res_unload_model("model/mushroom.fbx")
}

@(private="file")
add_mesh_renderers :: proc(world: ^ecs.World, asset : ^dude.ModelAsset) {
    for name, mesh in &asset.meshes {
        ent := ecs.add_entity(world)
        
        mesh_renderer := ecs.add_component(world, ent, dude.MeshRenderer)
        mesh_renderer.mesh = &mesh
        mesh_renderer.transform_matrix = linalg.MATRIX4F32_IDENTITY
        ecs.add_component(world, ent, dude.DebugInfo{
            fmt.aprintf("DBGNAME: {}", strings.to_string(mesh_renderer.mesh.name)),
        })
    }
}