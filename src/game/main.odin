package main

import "core:fmt"
import "core:log"
import "core:math/linalg"
import "core:math"

import "../dude"
import "../dude/dgl"
import hla "../dude/collections/hollow_array"

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
	dude.init("dude", {_package_game, _test})
    dude.dude_main(update, init, release, nil)
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
}

@(private="file")
init :: proc(game: ^dude.Game) {
    using demo_game
    append(&game.render_pass, &pass_main)

    {// ** Build meshes.
        using dgl
        mb : MeshBuilder
        mesh_builder_init(&mb, VERTEX_FORMAT_P2U2); defer mesh_builder_release(&mb)

        mesh_builder_add_vertices(&mb,
            {v4={-0.5, -0.5, 0,0}},
            {v4={0.5,  -0.5, 1,0}},
            {v4={-0.5, 0.5,  0,1}},
            {v4={0.5,  0.5,  1,1}},
        )
        mesh_builder_add_indices(&mb, 0,1,2, 1,3,2)

        mesh_builder_clear(&mb)
        mesh_builder_add_vertices(&mb,
            {v4={-1.0, -1.0, 0,0}},
            {v4={1.0,  -1.0, 1,0}},
            {v4={-1.0, 1.0,  0,1}},
        )
        mesh_builder_add_indices(&mb, 0,1,2)
        test_mesh_triangle = mesh_builder_create(mb)

        make_grid :: proc(mb: ^dgl.MeshBuilder, half_size:int, unit: f32) -> dgl.Mesh {
            size := 2 * half_size
            min := -cast(f32)half_size * unit;
            max := cast(f32)half_size * unit;

            for i in 0..=size {
                x := min + cast(f32)i * unit
                dgl.mesh_builder_add_vertices(mb, {v2={x,min}})
                dgl.mesh_builder_add_vertices(mb, {v2={x,max}})
            }
            for i in 0..=size {
                y := min + cast(f32)i * unit
                dgl.mesh_builder_add_vertices(mb, {v2={min,y}})
                dgl.mesh_builder_add_vertices(mb, {v2={max,y}})
            }
            return dgl.mesh_builder_create(mb^)
        }

        dgl.mesh_builder_reset(&mb, dgl.VERTEX_FORMAT_P2U2)
        test_mesh_grid = make_grid(&mb, 20, 1.0)
        dgl.mesh_builder_reset(&mb, dgl.VERTEX_FORMAT_P2U2)
        test_mesh_grid2 = make_grid(&mb, 4, 5.0)

        test_texture = texture_load_from_mem(#load("../../res/texture/box.png"))
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
	material_set(&mat_grid, utable_general.color, Vec4{0.18,0.17,0.17, 1})
	material_set(&mat_grid, utable_general.texture, rsys.texture_default_white)

	material_init(&mat_grid2, &rsys.shader_default_mesh)
	material_set(&mat_grid2, utable_general.color, Vec4{0.1,0.12,0.09, 1})
	material_set(&mat_grid2, utable_general.texture, rsys.texture_default_white)

    // Pass initialization
    render_pass_init(&pass_main, {0,0, 320, 320})

    pass_main.viewport = {0,0,320,320}
    pass_main.camera.viewport = {320,320}
    pass_main.camera.size = 32
    pass_main.clear.color = {.2,.2,.2, 1}

    render_pass_add_object(&pass_main, RObjMesh{mesh=test_mesh_grid, mode=.Lines}, &mat_grid, order=-999)
    render_pass_add_object(&pass_main, RObjMesh{mesh=test_mesh_grid2, mode=.Lines}, &mat_grid2, order=-998)

    render_pass_add_object(&pass_main, RObjMesh{mesh=rsys.mesh_unit_quad}, &mat_red, position={0.2,0.8})
    render_pass_add_object(&pass_main, RObjMesh{mesh=rsys.mesh_unit_quad}, position={1.2,1.1})
    render_pass_add_object(&pass_main, RObjMesh{mesh=test_mesh_triangle, mode=.LineStrip}, position={.2,.2})

    player = render_pass_add_object(&pass_main, 
        RObjSprite{color={1,1,1,1}, texture=test_texture.id, size={8,8}, anchor={0.5,0.5}})

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

enter_test_scene :: proc() {
    pass := &dude.game.render_pass
    clear(pass)
}

@(private="file")
_package_game :: proc(args: []string) {
	fmt.printf("command: package game\n")
}
@(private="file")
_test :: proc(args: []string) {
	fmt.printf("command: test\n")
}