package main

import "core:fmt"
import "core:os"
import "core:strings"
import "core:time"
import "core:math"

import sdl  "vendor:sdl2"
import gl   "vendor:OpenGL"

create_main_window :: proc (allocator:=context.allocator, loc := #caller_location) -> Window {
	wnd := window_get_basic_template("Dove");

	wnd.handler = handler;
	wnd.render = render_proc;
	wnd.renderer_flags = {.ACCELERATED, .PRESENTVSYNC, .TARGETTEXTURE};

    return wnd;
}

@(private="file")
handler :: proc(using wnd:^Window, event:sdl.Event) {
	window_event := event.window;

	#partial switch eid := window_event.event; eid {
	case .CLOSE :{
		window_destroy(wnd);
	}
	}
}

@(private="file")
render_proc :: proc(using wnd:^Window) {
	col := [4]f32{.2, .8, .7, 1};
	total_ms := time.duration_milliseconds(app.duration_total);
	col *= [4]f32{0..<4 = math.sin(cast(f32)total_ms * .01) * .5 + 1};

	gl.ClearColor(col.r, col.g, col.b, col.a);
	gl.Clear(gl.COLOR_BUFFER_BIT|gl.DEPTH_BUFFER_BIT|gl.STENCIL_BUFFER_BIT);
	sdl.GL_SwapWindow(wnd.window);
	// sdl.SetRenderDrawColor(renderer, 128, 255, 128, 255);
	// sdl.RenderClear(renderer);
	// render_slashes(renderer, window_get_id(wnd), 5);

	// sdl.RenderPresent(renderer);
}

@(private="file")
update_proc :: proc(using wnd:^Window) {
	now := time.now();
	// time.duration_milliseconds()
	fmt.println();
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
