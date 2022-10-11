package main

import "core:fmt"
import "core:os"
import "core:strings"

import sdl  "vendor:sdl2"
import gl   "vendor:OpenGL"

create_helper_window :: proc (allocator:=context.allocator, loc := #caller_location) -> ^Window {
	wnd := new(Window);

	wnd.name = fmt.aprintf("helper:%i", len(windows));
	wnd.handler = handler;
	wnd.render = render_proc;
	wnd.window_flags = {};
	wnd.renderer_flags = {.ACCELERATED, .PRESENTVSYNC, .TARGETTEXTURE};
	wnd.position = IVec2{20, 20};
	wnd.size = IVec2{256, 100};

    return wnd;
}


@(private="file")
handler :: proc(using wnd:^Window, event:sdl.Event) {
	window_event := event.window;

	#partial switch eid:=window_event.event; eid {
	case .CLOSE :{
		destroy_window(wnd);
	}
	}
}

@(private="file")
render_proc :: proc(using wnd:^Window) {
	sdl.SetRenderDrawColor(renderer, 128, 128, 255, 255);
	sdl.RenderClear(renderer);
	render_slashes(renderer, get_window_id(wnd), 5);

	sdl.RenderPresent(renderer);
}

@(private="file")
render_slashes :: proc(renderer:^sdl.Renderer, count, interval:u32) {
	sdl.SetRenderDrawColor(renderer, 0, 0, 0, 255);

	xa, xb :i32= 10, 20;
	for i in 0..<count {
		y :i32= cast(i32)( (i + 1) * interval );
	    sdl.RenderDrawLine(renderer, xa, y, xb, y);
	}
}
