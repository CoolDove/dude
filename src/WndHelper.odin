package main

import "core:fmt"
import "core:os"
import "core:strings"

import sdl  "vendor:sdl2"
import gl   "vendor:OpenGL"

create_helper_window :: proc (allocator:=context.allocator, loc := #caller_location) -> Window {
	wnd := window_get_basic_template("helper", IVec2{256, 100});

	wnd.handler = handler;
	// wnd.render = render_proc;
	wnd.renderer_flags = {.ACCELERATED, .PRESENTVSYNC, .TARGETTEXTURE};

    return wnd;
}


@(private="file")
handler :: proc(using wnd:^Window, event:sdl.Event) {
	window_event := event.window;

	#partial switch eid:=window_event.event; eid {
	case .CLOSE :{
		window_destroy(wnd);
	}
	}
}

@(private="file")
render_proc :: proc(using wnd:^Window) {
	if is_opengl_window {
		gl.ClearColor(.8, .2, .1, 1);
		gl.Clear(gl.COLOR_BUFFER_BIT|gl.DEPTH_BUFFER_BIT|gl.STENCIL_BUFFER_BIT);
		sdl.GL_SwapWindow(wnd.window);
	} else {
		sdl.SetRenderDrawColor(renderer, 128, 128, 255, 255);
		sdl.RenderClear(renderer);
		render_slashes(renderer, window_get_id(wnd), 5);

		sdl.RenderPresent(renderer);
	}
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
