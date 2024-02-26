package main

import "core:time"
import "core:fmt"
import "core:log"
import "core:math/linalg"
import "core:math"

import "dude"
import "dude/dgl"
import "dude/vendor/imgui"
import hla "dude/collections/hollow_array"

pass_main : dude.RenderPass

DemoGame :: struct {
    mat_red, mat_green : dude.Material,
    mat_grid, mat_grid2 : dude.Material,
    test_texture : dgl.Texture,
    player : dude.RObjHandle,

    test_mesh_triangle, test_mesh_grid, test_mesh_grid2 : dgl.Mesh,
}

@(private="file")
demo_game : DemoGame

main :: proc() {
	dude.init("dude game demo", {_package_game, _test})
    dude.dude_main(update, init, release, on_gui)
}

@(private="file")
update :: proc(game: ^dude.Game, delta: f32) {
    using dude, demo_game
    @static time : f32 = 0
    time += delta

    viewport := app.window.size

    pass_main.viewport = Vec4i{0,0, viewport.x, viewport.y}
    pass_main.camera.viewport = vec_i2f(viewport)

    pass_main.camera.angle = 0.06 * math.sin(time*0.8)
    pass_main.camera.size = 64 + 6 * math.sin(time*1.2)

    camera := &pass_main.camera
    t := hla.hla_get_pointer(player)
    t.angle += delta * 0.6
    move_speed :f32= 3.0
    if get_key(.A) do t.position.x -= move_speed * delta
    else if get_key(.D) do t.position.x += move_speed * delta
    if get_key(.W) do t.position.y += move_speed * delta
    else if get_key(.S) do t.position.y -= move_speed * delta

    dude.immediate_screen_quad(&pass_main, get_mouse_position()-{32,32}, {64,64}, color={255,64,64, 128})
}

@(private="file")
init :: proc(game: ^dude.Game) {
    using demo_game
    append(&game.render_pass, &pass_main)

    {// ** Build meshes.
        using dgl
        mb := &dude.rsys.temp_mesh_builder

        mesh_builder_reset(mb, VERTEX_FORMAT_P2U2)
        mesh_builder_add_vertices(mb,
            {v4={-1.0, -1.0, 0,0}},
            {v4={1.0,  -1.0, 1,0}},
            {v4={-1.0, 1.0,  0,1}},
        )
        mesh_builder_add_indices(mb, 0,1,2)
        test_mesh_triangle = mesh_builder_create(mb^)

        mesh_builder_reset(mb, VERTEX_FORMAT_P2U2)
        dude.mesher_line_grid(mb, 20, 1.0)
        // TODO: Test not create indices buffer here.
        test_mesh_grid = mesh_builder_create(mb^)

        mesh_builder_reset(mb, VERTEX_FORMAT_P2U2)
        dude.mesher_line_grid(mb, 4, 5.0)
        test_mesh_grid2 = mesh_builder_create(mb^)

        test_texture = texture_load_from_mem(#load("../res/texture/dude.png"))
    }

    using dude
    utable_general := rsys.shader_default_mesh.utable_general
	material_init(&mat_red, &rsys.shader_default_mesh)
	material_set(&mat_red, utable_general.color, Vec4{1,0.6,0.8, 1})
	material_set(&mat_red, utable_general.texture, test_texture.id)

	material_init(&mat_green, &rsys.shader_default_mesh)
	material_set(&mat_green, utable_general.color, Vec4{0.8,1,0.6, 1})
	material_set(&mat_green, utable_general.texture, test_texture.id)

	material_init(&mat_grid, &rsys.shader_default_mesh)
	material_set(&mat_grid, utable_general.color, Vec4{0.18,0.14,0.13, 1})
	material_set(&mat_grid, utable_general.texture, rsys.texture_default_white)

	material_init(&mat_grid2, &rsys.shader_default_mesh)
	material_set(&mat_grid2, utable_general.color, Vec4{0.1,0.04,0.09, 1})
	material_set(&mat_grid2, utable_general.texture, rsys.texture_default_white)

    // Pass initialization
    render_pass_init(&pass_main, {0,0, app.window.size.x, app.window.size.y})
    pass_main.clear.color = {.2,.2,.2, 1}
    pass_main.clear.mask = {.Color,.Depth,.Stencil}
    blend := &pass_main.blend.(dgl.GlStateBlendSimp)
    blend.enable = true

    // render_pass_add_object(&pass_main, RObjMesh{mesh=rsys.mesh_unit_quad}, &mat_red, position={0.2,0.8})
    // render_pass_add_object(&pass_main, RObjMesh{mesh=rsys.mesh_unit_quad}, position={1.2,1.1})
    // render_pass_add_object(&pass_main, RObjMesh{mesh=test_mesh_triangle, mode=.LineStrip}, position={.2,.2})
    // render_pass_add_object(&pass_main, RObjSprite{{1,1,1,1}, test_texture.id, {0.5,0.5}, {1,1}}, order=101)

    player = render_pass_add_object(&pass_main, 
        RObjSprite{color={1,1,1,1}, texture=test_texture.id, size={4,4}, anchor={0.5,0.5}}, order=100)

    render_pass_add_object(&pass_main, RObjMesh{mesh=test_mesh_grid2, mode=.Lines}, &mat_grid2, order=-9998)
    render_pass_add_object(&pass_main, RObjMesh{mesh=test_mesh_grid, mode=.Lines}, &mat_grid, order=-9999)

    // render_pass_add_object(&pass_main, RObjSpriteScreen{{1,0,0,0.2}, test_texture.id, {.5,.5}, {320,320}}, position={1,0}, order=999)
}
@(private="file")
release :: proc(game: ^dude.Game) {
    using dude, demo_game
    dgl.texture_delete(&test_texture.id)
    
	material_release(&mat_red)
	material_release(&mat_green)

	dgl.mesh_delete(&test_mesh_triangle)
	dgl.mesh_delete(&test_mesh_grid)
	dgl.mesh_delete(&test_mesh_grid2)

    render_pass_release(&pass_main)
}

@(private="file")
on_gui :: proc() {
    using demo_game, imgui
    set_next_window_pos({10,10})
    begin("DemoGame", nil)
    text("Frame time: %f", time.duration_seconds(dude.app.duration_frame))
    p : ^dude.RenderObject = hla.hla_get_pointer(player)
    slider_float2("position", &p.position, -10, 10)
    end()
}

@(private="file")
_package_game :: proc(args: []string) {
	fmt.printf("command: package game\n")
}
@(private="file")
_test :: proc(args: []string) {
	fmt.printf("command: test\n")
}