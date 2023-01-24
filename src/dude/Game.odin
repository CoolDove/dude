package dude

import "core:time"
import "core:log"
import "core:fmt"
import "core:reflect"
import "core:strings"
import "core:math"
import "core:math/linalg"

import sdl "vendor:sdl2"
import gl "vendor:OpenGL"

when ODIN_DEBUG do import "pac:imgui"

import "dgl"
import "ecs"

@private
registered_scenes : map[string]Scene
@private
default_scene : ^Scene

Game :: struct {
    using settings : ^GameSettings,
    window : ^Window,

    current_scene : ^Scene,
    main_world : ^ecs.World,

    basic_shader : dgl.Shader,
}

GameSettings :: struct {
    status_window_alpha : f32,
    render_wireframe : bool,
    immediate_draw_wireframe : bool,
}

game : Game

GameObject :: struct {
    mesh      : TriangleMesh,
    transform : Transform,
}

when ODIN_DEBUG {
draw_game_imgui :: proc() {
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
            log.debugf("Load scene: {}", key)
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
}

@(private="file")
draw_status :: proc() {
    frame_ms := time.duration_milliseconds(app.duration_frame)
    framerate := cast(i32)(1000.0/frame_ms)
    color := Vec4{.1, 1, .1, 1}
    color.a *= game.settings.status_window_alpha

    font := res_get_font("font/unifont.ttf")
    immediate_text(font, fmt.tprintf("FPS: {}", framerate), {10, 32+10}, color)
    immediate_text(font, fmt.tprintf("Fullscreen: {}", game.window.fullscreen), 
        {10, 32+10+32+10}, color)
}

update_game :: proc() {
    // ## FRAME PREPARE
	gl.Clear(gl.COLOR_BUFFER_BIT|gl.DEPTH_BUFFER_BIT|gl.STENCIL_BUFFER_BIT)
    wnd := game.window
	immediate_begin(dgl.Vec4i{0, 0, wnd.size.x, wnd.size.y})

    // ## GAME LOGIC
    {// Engine input handling
        if get_key_down(.F1) {
            game.immediate_draw_wireframe = !game.immediate_draw_wireframe
        }
    }

    // Game world
    if game.main_world != nil {
        if game.current_scene.update != nil {
            game.current_scene.update(&game, game.main_world)
        }
        ecs.world_update(game.main_world)
        render_world(game.main_world)
    } else {// Draw "No Scene Loaded"
        draw_no_scene_logo(game.window)
    }

    tween_update()

    // Game builtin draw.
    if game.settings.status_window_alpha > 0 do draw_status()

    // ## RENDERING
    immediate_end(game.immediate_draw_wireframe)

    // ## DEBUG IMGUI
	when ODIN_DEBUG {
        imgui_frame_begin()
		draw_game_imgui()
        imgui_frame_end()
	}
}

@(private="file")
draw_no_scene_logo :: proc(wnd: ^Window) {
    wnd_size := wnd.size
    unifont := res_get_font("font/unifont.tff")
    text := "No Scene Loaded"
    text_width := immediate_measure_text_width(unifont, text)
    screen_center := Vec2{cast(f32)wnd_size.x, cast(f32)wnd_size.y} * 0.5
    {
        logo_size := Vec2{64, 64}
        immediate_texture(
            screen_center - logo_size * 0.5 - {0, 64}, logo_size, 
            COLORS.WHITE,
            res_get_texture("texture/dude.png").id,
        )
    }
    immediate_text(unifont, text,
        {cast(f32)wnd_size.x * 0.5 - text_width * 0.5, cast(f32)wnd_size.y * 0.5},
        COLORS.GRAY)
}

init_game :: proc() {
    using dgl

    game.settings = new(GameSettings)
    game.basic_shader = load_shader(
        #load("resources/basic_3d_vertex.glsl"),
        #load("resources/basic_3d_fragment.glsl"))

    tween_init()

    // Load some built in assets.
    load_builtin_assets() 

    if default_scene != nil do load_scene(default_scene)
}

struct_offset_detail :: proc($T:typeid) -> uintptr {
    names   := reflect.struct_field_names(T)
    offsets := reflect.struct_field_offsets(T)

    sb : strings.Builder
    strings.builder_init(&sb)
    defer strings.builder_destroy(&sb)
    strings.write_string(&sb, fmt.tprintf("{}: <", typeid_of(T)))

    for i in 0..<len(names) {
        name := names[i]
        offset := offsets[i]
        strings.write_string(&sb, fmt.tprintf("{}: {}", name, offset))
        if i != len(names) - 1 do strings.write_string(&sb, ", ")
    }
    strings.write_string(&sb, fmt.tprintf("> total size: {}", size_of(T)))
    log.debugf(strings.to_string(sb))

    return offsets[0] if len(offsets) > 0 else 0
}

@(private="file")
load_shader :: proc(vertex_source, frag_source : string)  -> dgl.Shader {
	shader_comp_vertex := dgl.shader_create_component(.VERTEX_SHADER, vertex_source)
	shader_comp_fragment := dgl.shader_create_component(.FRAGMENT_SHADER, frag_source)
	shader := dgl.shader_create(&shader_comp_vertex, &shader_comp_fragment)
	dgl.shader_destroy_components(&shader_comp_vertex, &shader_comp_fragment)
	return shader
}

quit_game :: proc() {
    unload_scene()
    
    tween_destroy()

    unload_builtin_assets()

    log.debug("QUIT GAME")

    free(game.settings)
}

load_builtin_assets :: proc() {
    res_add_embbed("texture/dude.png", #load("resources/dude.png"))
    res_add_embbed("font/unifont.tff", #load("resources/unifont.ttf"))

    res_load_texture("texture/dude.png")
    {
        white := new(Texture)
        white.id = dgl.texture_create(4, 4, [4]u8{0xff, 0xff, 0xff, 0xff})
        white.size = {4, 4}
        res_add_texture("texture/white", white)
    }
    {
        black := new(Texture)
        black.id = dgl.texture_create(4, 4, [4]u8{0x00, 0x00, 0x00, 0xff})
        black.size = {4, 4}
        res_add_texture("texture/black", black)
    }
    res_load_font("font/unifont.tff", 32.0)
}
unload_builtin_assets :: proc() {
    res_unload_texture("texture/dude.png")
    res_unload_texture("texture/white")
    res_unload_texture("texture/black")
    res_unload_font("font/unifont.ttf")
}