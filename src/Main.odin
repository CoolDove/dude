package main

import "core:fmt"
import "core:os"
import "core:strings"

import sdl  "vendor:sdl2"
import gl   "vendor:OpenGL"

import scrshit "foreign:screenshit"

windows : map[u32]^Window

main :: proc() {
    sdl_process("Dove");
}

clib_test :: proc() {
	fmt.println("1+2=", scrshit.export_add(1, 2));

	data := scrshit.alloc_mem(23);
	fmt.println("ptr: ", data);
	for ind in 0..<23 {
		fmt.println(ind, ": ", data[ind]);
	}
	scrshit.release_mem(data);

	fmt.println("ptr: ", data);
	for ind in 0..<23 {
		fmt.println(ind, ": ", data[ind]);
	}
}

register_window :: proc(wnd:^Window) {
	instantiate_window(wnd);

	id := get_window_id(wnd);
	has := id in windows;
	if !has do windows[id] = wnd;
	else do fmt.println("window has been registered");

	wnd.before_destroy = proc(wnd:^Window) {
		remove_id := get_window_id(wnd);
		remove_window(remove_id);
		fmt.println("destroy window: ", wnd.name, ", now ", len(windows), " windows left");
	};
}

remove_window :: proc(id:u32) {
	if id in windows do delete_key(&windows, id);
}

sdl_process :: proc(app_name:string) {
	if sdl.Init({.VIDEO, .EVENTS}) != 0 {
	    fmt.println("failed to init: ", sdl.GetErrorString());
		return
	}

	main_window := create_main_window();
	helper_window := create_helper_window();
	defer {
        free(main_window);
        free(helper_window);
	}

	register_window(main_window);
	register_window(helper_window);

	
    evt := sdl.Event{};
	for len(windows) > 0 {
		if sdl.PollEvent(&evt) {
			if evt.window.type == .WINDOWEVENT {
				wid := evt.window.windowID;
				if wnd, has := windows[wid]; has && wnd.handler != nil {
					wnd.handler(wnd, evt);
				}
			}
		} else {
			// rendering
			for id, wnd in &windows {
				if wnd.render != nil do wnd.render(wnd);
			}
		}
	}
	sdl.Quit();
}


list_dir :: proc(dir_name:string) {
	handle, handle_ok := os.open(dir_name);
	defer os.close(handle)
	files, ok := os.read_dir(handle, 0, context.temp_allocator);

	fmt.println("====", dir_name, "-", len(files));

	for f in files {
		fmt.println(f.fullpath);
	}
}
