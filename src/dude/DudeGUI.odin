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

when DUDE_IMGUI {

import "pac:imgui"


dude_imgui_basic_settings :: proc() {
    guis := map[string]proc() {
        "Scene"        = gui_scenes,
        "Tween"        = gui_tween,
        "Settings"     = gui_settings,
        "ResourceView" = gui_resource_viewer,
        "ECS"          = gui_ecs,
    }
    defer delete(guis)

    @static guikey := "Scene"

    for key in guis {
        if imgui.selectable(key, guikey == key, auto_cast 0, {50, 0}) do guikey = key
        imgui.same_line()
    }
    imgui.text("...")
    imgui.separator()
    if guikey in guis {
        guis[guikey]()
    }

}

gui_tween :: proc() {
    when ODIN_DEBUG {
        for t, ind in &tweens {
            text := fmt.tprintf("{}: {}", ind, "working" if !t.done else "done.")
            imgui.selectable(text, !t.done)
        }
    } else {
        imgui.text("Tween debug is invalid in release build.")
    }
}

gui_settings :: proc() {
    imgui.checkbox("immediate draw wireframe", &game.immediate_draw_wireframe)
}
gui_scenes :: proc() {
    imgui.text("Scenes")
    for key, scene in registered_scenes {
        if imgui.button(key) {
            unload_scene()
            load_scene(key)
        }
    }
    if imgui.button("Unload") {
        unload_scene()
    }
}
gui_resource_viewer :: proc() {
    imgui.text("Resource:")
    count := len(resource_manager.resources) 
    keys := make([dynamic]string, count, count)
    defer delete(keys)
    c := 0
    for key, res in resource_manager.resources {
        keys[c] = key
        c += 1
    }
    slice.sort(keys[:])
    for k in keys { imgui.text(k) }
}

gui_ecs :: proc() {
    imgui.text("ECS")
    if game.main_world == nil {
        imgui.text("No world.")
        return
    }
    entities := game.main_world.entities.dense
    for ent in entities {
        using imgui
        entity := cast(ecs.Entity)ent.id
        entity_info := cast(ecs.EntityInfo)ent.data
        imgui.bullet_text(fmt.tprintf("> {}", entity_info.name))
        components := ecs.get_components(game.main_world, entity)
        defer delete(components)
        wnd_flags := Window_Flags.AlwaysAutoResize
        if imgui.begin_child(str_id = entity_info.name, size={0, 60}, flags = wnd_flags) {
            for c in components {
                if c.type == typeid_of(Transform) {
                    transform := ecs.get_component(game.main_world, entity, Transform)
                    imgui_transform(transform)
                } else {
                    imgui.text(fmt.tprintf("    -{}: {}", c.type, c.id))
                }
            }
        }
        imgui.end_child()
    }
}

// ## imgui extensions

imgui_transform :: proc(transform : ^Transform) {
    imgui.input_float3("position", &transform.position)
    // orientation
    imgui.input_float3("scale", &transform.scale)
}

}


when DUDE_GIZMOS {

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

}


draw_no_scene_logo :: proc(wnd: ^Window) {
    wnd_size := wnd.size
    unifont := res_get_font("font/unifont.tff")
    text := "No Scene Loaded"
    text_width := immediate_measure_text_width(unifont, text)
    screen_center := Vec2{cast(f32)wnd_size.x, cast(f32)wnd_size.y} * 0.5
    {
        // logo_size := Vec2{64, 64}
        // immediate_texture(
        //     screen_center - logo_size * 0.5 - {0, 64}, logo_size, 
        //     COLORS.WHITE,
        //     res_get_texture("texture/dude.png").id,
        // )
    }
    immediate_text(unifont, text,
        {screen_center.x - text_width * 0.5, screen_center.y},
        COLORS.GRAY)
}

draw_status :: proc() {
    frame_ms := time.duration_milliseconds(app.duration_frame)
    framerate := cast(i32)(1000.0/frame_ms)
    color := COLORS.GREEN
    color.a *= game.status_window_alpha

    font := res_get_font("font/unifont.tff")
    text := fmt.aprintf("FPS: {}", framerate)
    defer delete(text)
    immediate_text(font, text, {10, 32+10}, color)
}