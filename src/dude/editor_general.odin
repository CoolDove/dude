//+private
package dude


import "core:time"
import "core:log"
import "core:fmt"
import "core:reflect"
import "core:strings"
import "core:slice"
import "core:math"
import "core:math/linalg"

import "ecs"

import "vendor/imgui"

@(private="file")
dude_debug_guis := map[string]proc() {
    "Scene"        = gui_scenes,
    "Tween"        = gui_tween,
    "Settings"     = gui_settings,
    "ResourceView" = gui_resource_viewer,
    "ECS"          = gui_ecs,
}

dude_imgui_basic_settings :: proc() {
    @static guikey := "Scene"
    using imgui

    imgui.begin("GeneralEditor")

    begin_tab_bar("DebugView", Tab_Bar_Flags.Reorderable | Tab_Bar_Flags.TabListPopupButton)
    for key in dude_debug_guis {
        if begin_tab_item(key, nil, .UnsavedDocument if guikey == key else .None) {
            imgui.text(key)
            guikey = key
            imgui.separator()
            dude_debug_guis[guikey]()
            end_tab_item()
        }
    }
    imgui.end_tab_bar()

    imgui.end()
}

gui_tween :: proc() {
    when ODIN_DEBUG {
        // for t, ind in &tweens {
            // text := fmt.tprintf("{}: {}", ind, "working" if !t.done else "done.")
            // imgui.selectable(text, !t.done)
        // }
    } else {
        imgui.text("Tween debug is invalid in release build.")
    }
}

gui_settings :: proc() {
    imgui.checkbox("immediate draw wireframe", &game.immediate_draw_wireframe)
}
gui_scenes :: proc() {
    imgui.text("Scene is not available now.")
    // for key, scene in registered_scenes {
        // if imgui.button(key) {
            // switch_scene(key)
        // }
    // }
    // if imgui.button("Unload") {
        // unload_scene()
        // log.debugf("scene unload")
    // }
}
gui_resource_viewer :: proc() {
    count := len(resource_manager.resources) 
    keys := make([dynamic]string, count, count)
    defer delete(keys)
    c := 0
    // for key, res in resource_manager.resources {
        // keys[c] = res_name_lookup[key]
        // c += 1
    // }
    slice.sort(keys[:])
    for k in keys { imgui.text(k) }
}

gui_ecs :: proc() {
    imgui.text("ECS is gone.")
    // if game.main_world == nil {
        // imgui.text("No world.")
        // return
    // }
    // entities := game.main_world.entities.dense
    // for ent in entities {
        // using imgui
        // entity := cast(ecs.Entity)ent.id
        // entity_info := cast(ecs.EntityInfo)ent.data
        // components := ecs.get_components(game.main_world, entity, allocators.frame)
        // defer delete(components)
        // wnd_flags := Window_Flags.AlwaysAutoResize
        // header_name : string = ---
        // {context.allocator = allocators.frame
            // header_name = fmt.aprintf("{}({})", entity_info.name, entity)
        // }
        // if collapsing_header(header_name) {
            // begin_child(entity_info.name)
            // text_unformatted(fmt.tprintf("Componnets: {}", len(components)))
            // for c in components {
                // bullet_text(fmt.tprintf("-{}: {}", c.type, c.id))
                // if c.type == typeid_of(Transform) {
                    // transform := ecs.get_component(game.main_world, entity, Transform)
                    // imgui_transform(transform)
                // }
				// // else if c.type == typeid_of(SpriteRenderer) {
                    // // sprite := ecs.get_component(game.main_world, entity, SpriteRenderer)
                    // // text_unformatted(fmt.tprintf("Space: {}", sprite.space))
                // // }
            // }
            // end_child()
        // }
        // separator()
    // }
}

// ## imgui extensions

imgui_transform :: proc(using transform : ^Transform) {
    imgui.drag_float3("position", &position)
    euler : Vec3
    euler.x, euler.y, euler.z = linalg.euler_angles_from_quaternion(orientation, .XYZ)
    euler *= linalg.DEG_PER_RAD
    if imgui.drag_float3("rotation", &euler) {
        euler *= linalg.RAD_PER_DEG
        orientation = linalg.quaternion_from_euler_angles(euler.x, euler.y, euler.z, .XYZ)
    }
    // orientation
    imgui.drag_float3("scale", &scale)
}


gizmos_xz_grid :: proc(half_size : int, unit : f32, color: Color) {
    gizmos_set_color(color)

    size := 2 * half_size

    min := -cast(f32)half_size * unit;
    max := cast(f32)half_size * unit;

    for i in 0..=size {
        x := min + cast(f32)i * unit
        gizmos_line({x, 0, min}, {x, 0, max})
    }
    for i in 0..=size {
        y := min + cast(f32)i * unit
        gizmos_line({min, 0, y}, {max, 0, y})
    }

}


draw_no_scene_logo :: proc(wnd: ^Window) {
    wnd_size := wnd.size
    unifont := builtin_res.default_font
    text := "No Scene Loaded"
    // text_width := immediate_measure_text_width(unifont, text)
    // screen_center := Vec2{cast(f32)wnd_size.x, cast(f32)wnd_size.y} * 0.5
    // immediate_text(unifont, text,
        // {screen_center.x - text_width * 0.5, screen_center.y},
        // COLORS.GRAY)
}

draw_status :: proc() {
    frame_ms := time.duration_milliseconds(app.duration_frame)
    framerate := cast(i32)(1000.0/frame_ms)
    color := COLORS.GREEN
    color.a *= game.status_window_alpha

    font := builtin_res.default_font
    if font != nil {
        text := fmt.aprintf("FPS: {}, ftime: {} ms", framerate, frame_ms)
        defer delete(text)
        // immediate_text(font, text, {10, 32+10}, color)
    }
}
