package dude


import "core:time"
import "core:log"
import "core:fmt"
import "core:reflect"
import "core:strings"
import "core:math"
import "core:math/linalg"

when ODIN_DEBUG {

import "pac:imgui"

dude_imgui_basic_settings :: proc() {
    guis := map[string]proc() {
        "Scene"        = gui_scenes,
        "Tween"        = gui_tween,
        "Settings"     = gui_settings,
        "ResourceView" = gui_resource_viewer,
    }

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
    for t, ind in &tweens {
        text := fmt.tprintf("{}: {}", ind, "working" if !t.done else "done.")
        imgui.selectable(text, !t.done)
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
    for key, res in resource_manager.resources {
        imgui.text(key)
    }
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

}