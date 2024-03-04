package dude

import "core:fmt"
import "core:os"
import "core:strings"
import "core:time"
import "core:math"
import "core:log"
import "core:math/rand"

import sdl  "vendor:sdl2"
import gl   "vendor:OpenGL"

import dgl "dgl"

create_main_window :: proc (allocator:=context.allocator, loc := #caller_location) -> Window {
	wnd := window_get_basic_template(game_config.name, {800,600})
	wnd.vtable = &main_wnd_vtable
	wnd.window_flags += { .RESIZABLE }
    return wnd
}

@(private="file")
main_wnd_vtable := Window_VTable {
	handler=handler,
}

@(private="file")
handler :: proc(using wnd:^Window, event:sdl.Event) {
	input_handle_sdl2(event)

	window_event := event.window
}