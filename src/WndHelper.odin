package main

import "core:fmt"
import "core:os"
import "core:log"
import "core:strings"

import sdl  "vendor:sdl2"
import gl   "vendor:OpenGL"

create_helper_window :: proc (allocator:=context.allocator, loc := #caller_location) -> Window {
	wnd := window_get_basic_template("helper", IVec2{256, 100});

	wnd.window_flags |= {.RESIZABLE};
	wnd.handler = handler;
	wnd.update = update;

    return wnd;
}


@(private="file")
handler :: proc(using wnd:^Window, event:sdl.Event) {
	window_event := event.window;

	if event.type == .KEYDOWN {
		log.debugf("Key: {} down. Target window: {}.\n", event.key.keysym.sym, name);
	}

	if event.window.type == .WINDOWEVENT {
		// #partial switch eid:=window_event.event; eid {
		// case .RESIZED : {
		// 	size = IVec2{event.window.data1, event.window.data2};
		// }
		// case .CLOSE :{
		// 	window_destroy(wnd);
		// }
		// }
	}
}

@(private="file")
update :: proc(using wnd: ^Window) {
	render(wnd)
}

@(private="file")
render :: proc(using wnd:^Window) {
	gl.Viewport(0,0, size.x, size.y);
	gl.ClearColor(.8, .2, .1, 1);
	gl.Clear(gl.COLOR_BUFFER_BIT|gl.DEPTH_BUFFER_BIT|gl.STENCIL_BUFFER_BIT);

	sdl.GL_SwapWindow(wnd.window);
}