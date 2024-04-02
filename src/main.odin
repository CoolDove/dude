package main

import "core:time"
import "core:os"
import "core:fmt"
import "core:unicode/utf8"
import "core:log"
import "core:reflect"
import "core:strings"
import "core:math/linalg"
import "core:math"
import "core:mem"

import sdl "vendor:sdl2"

import "dude"
import "dude/dpac"
import "dude/dgl"
import mui "dude/microui"
import hla "dude/collections/hollow_array"

REPAC_ASSETS :: false

pass_main : dude.RenderPass

DemoGame :: struct {
    asset_pacbuffer : []u8,
}

@(private="file")
demo_game : DemoGame

main :: proc() {
    tracking_allocator : mem.Tracking_Allocator
    mem.tracking_allocator_init(&tracking_allocator, context.allocator)
    context.allocator = mem.tracking_allocator(&tracking_allocator)
    
    reset_tracking_allocator :: proc(a: ^mem.Tracking_Allocator) -> bool {
        fmt.printf("Memory leak report:\n")
        leaks := false
        for key, value in a.allocation_map {
            fmt.printf("%v: Leaked %v bytes\n", value.location, value.size)
            leaks = true
        }
        mem.tracking_allocator_clear(a)
        return leaks
    }
    defer reset_tracking_allocator(&tracking_allocator)

    // ** Load dpacs
    if REPAC_ASSETS {
        bundle_err : dpac.BundleErr
        demo_game.asset_pacbuffer, bundle_err = dpac.bundle(GameAssets)
        if bundle_err != .None {
            fmt.eprintf("bundle err: {}\n", bundle_err)
        } else {
            os.write_entire_file("./GameAssets.dpac", demo_game.asset_pacbuffer)
        }
    } else {
        demo_game.asset_pacbuffer, _ = os.read_entire_file("./GameAssets.dpac")
    }
    defer delete(demo_game.asset_pacbuffer)
    
	dude.init(dude.WindowInitializer{"dude game demo", {sdl.WINDOWPOS_CENTERED, sdl.WINDOWPOS_CENTERED}, {800,600}, {.RESIZABLE}, nil})
    dude.dude_main(update, init, release, on_mui)
}

@(private="file")
update :: proc(game: ^dude.Game, delta: f32) {
    using dude, demo_game
    @static time : f32 = 0
    time += delta

    viewport := app.window.size
    pass_main.viewport = Vec4i{0,0, viewport.x, viewport.y}
    pass_main.camera.viewport = vec_i2f(viewport)

    // if get_key_down(.H) do dude.audio_play(&assets.sfx.hit.clip)
    imdraw.text(&pass_main, assets.font_inkfree.font, "Hello, dude.", {100, 100}, 32)

}

@(private="file")
init :: proc(game: ^dude.Game) {
    dpac.register_load_handler(dove_assets_handler)
    err := dpac.load(demo_game.asset_pacbuffer, &assets, type_info_of(GameAssets))
    assert(err == .None, fmt.tprintf("Failed to load assets: {}", err))
    
    using demo_game
    append(&game.render_pass, &pass_main)
    using dude
    // Pass initialization
    wndx, wndy := app.window.size.x, app.window.size.y
    render_pass_init(&pass_main, {0,0, wndx, wndy})
    pass_main.clear.color = {.2,.2,.2, 1}
    pass_main.clear.mask = {.Color,.Depth,.Stencil}
    blend := &pass_main.blend.(dgl.GlStateBlendSimp)
    blend.enable = true

}

@(private="file")
release :: proc(game: ^dude.Game) {
    dpac.release(&assets, type_info_of(GameAssets))
    dude.render_pass_release(&pass_main)
}

@(private="file")
on_mui :: proc(ctx: ^mui.Context) {
}
