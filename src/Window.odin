package main

import "core:fmt"
import "core:os"
import "core:strings"
import sdl  "vendor:sdl2"
import gl   "vendor:OpenGL"

Window :: struct {
	handler  : proc(wnd:^Window, event:sdl.Event),
	render   : proc(wnd:^Window),

	window_flags   : sdl.WindowFlags,
	renderer_flags : sdl.RendererFlags,
	position, size : IVec2,

	before_destroy : proc(wnd:^Window),

	name     : string,

    window   : ^sdl.Window,
	renderer : ^sdl.Renderer,
}

IVec2 :: [2]i32

Event :: struct {
	event : ^sdl.Event,
}

instantiate_window :: proc(using wnd:^Window) -> bool {
	window = sdl.CreateWindow(
	    strings.clone_to_cstring(name, context.temp_allocator),
	    position.x, position.y, size.x, size.y,
	    window_flags);
	if window != nil do renderer = sdl.CreateRenderer(window, -1, renderer_flags);

	if !is_window_good(wnd) {
        fmt.println("failed to instantiate window: ", name);
		return false;
	} 
	return true;
}

destroy_window :: proc(using wnd:^Window) {
	if !is_window_good(wnd) do return

	if before_destroy!=nil do before_destroy(wnd);

	sdl.DestroyWindow(window);
	sdl.DestroyRenderer(renderer);
	window = nil;
    renderer = nil;
}

is_window_good :: proc(using wnd:^Window) -> bool {
	return window != nil && renderer != nil;
}

get_window_id :: proc(using wnd:^Window) -> u32 {
	return sdl.GetWindowID(window);
}
