package main

import "core:fmt"
import "core:log"
import "core:math"
import "core:strings"
import "core:time"
import "core:math/linalg"

import "dude"
import "dude/ecs"

when dude.DUDE_3D_GAME {

scene_mushroom := dude.Scene { mushroom_scene_loader, mushroom_update, mushroom_scene_unloader }

@(private="file")
mushroom_scene_loader :: proc(world: ^ecs.World) {
    using dude
    using ecs
    mushroom, err := res_load_model("model/mushroom.fbx", 
        dude.res_get_shader("shader/builtin_mesh_opaque.shader").id,
        dude.res_get_texture("texture/white.tex").id, 
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
mushroom_update :: proc(world: ^ecs.World, ) {
    using dude
    camera := get_main_camera(world)
    if get_key_down(.C) {
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
    time_delta := time.duration_seconds(app.duration_frame)
    if camera.type == .Ortho {
        if get_key(.J) do camera.size = math.max(camera.size - cast(f32)time_delta * 2, 0)
        else if get_key(.K) do camera.size = math.min(camera.size + cast(f32)time_delta * 2, 99)
    }
}

@(private="file")
mushroom_scene_unloader :: proc(world: ^ecs.World) {
    dude.res_unload_model("model/mushroom.fbx")
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

        ecs.add_component(world, ent, default_transform)
        mesh_renderer := ecs.add_component(world, ent, dude.MeshRenderer)
        mesh_renderer.mesh = &mesh
        mesh_renderer.transform_matrix = linalg.MATRIX4F32_IDENTITY
        ecs.add_component(world, ent, dude.DebugInfo{
            fmt.aprintf("DBGNAME: {}", mesh_name),
        })
    }
}

}