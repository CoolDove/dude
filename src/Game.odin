package main

import dgl "dgl"
import sdl "vendor:sdl2"

import gl "vendor:OpenGL"

import imgui "pac:imgui"

Game :: struct {
    window : ^Window,

    test_image : dgl.Image,
    // test_texture : u32
}

game : Game

draw_game :: proc() {
	using dgl

    wnd := game.window

	wnd_size := Vec2{cast(f32)wnd.size.x, cast(f32)wnd.size.y}
	immediate_quad(Vec2{wnd_size.x * 0.05, 0}, Vec2{wnd_size.x * 0.9, 20}, Vec4{ 1, 0, 0, 0.2 })
	immediate_quad(Vec2{40, 10}, Vec2{120, 20}, Vec4{ 0, 1, .4, 0.2 })
	immediate_quad(Vec2{10, 120}, Vec2{90, 20}, Vec4{ 1, 1, 1, 0.9 })

    @static show_cat := false
    imgui.checkbox("show_icon", &show_cat)
    img := &game.test_image
    if show_cat do immediate_texture(
        Vec2{120, 120}, Vec2{auto_cast img.size.x, auto_cast img.size.y}, 
        Vec4{1, 1, 1, 1},
        img.texture_id
    )
}

update_game :: proc() {

}

init_game :: proc() {
    game.test_image = dgl.texture_load("./res/texture/walk_icon.png")
    dgl.image_free(&game.test_image)
}

// TODO(Dove): This is not called now
quit_game :: proc() {
    gl.DeleteTextures(1, &game.test_image.texture_id)
}