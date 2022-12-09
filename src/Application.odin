package main

import "core:fmt"
import "core:os"
import "core:strings"
import "core:time"
import "core:c"

import sdl  "vendor:sdl2"
import gl   "vendor:OpenGL"

import "pac:imgui"

Application :: struct {
    windows : map[u32]^Window,

	duration_total : time.Duration,
	duration_frame : time.Duration,

	stopwatch : time.Stopwatch,
	frame_stopwatch : time.Stopwatch,
}

app : ^Application

app_init :: proc() {
	app = new(Application)

	time.stopwatch_start(&app.stopwatch)

	if sdl.Init({.VIDEO, .EVENTS}) != 0 {
	    fmt.println("failed to init: ", sdl.GetErrorString())
		return
	}

	sdl.GL_SetAttribute(.CONTEXT_MAJOR_VERSION, OPENGL_VERSION_MAJOR)
	sdl.GL_SetAttribute(.CONTEXT_MINOR_VERSION, OPENGL_VERSION_MINOR)
	sdl.GL_SetAttribute(sdl.GLattr.CONTEXT_PROFILE_MASK, cast(i32)sdl.GLprofile.CORE)
	
	major, minor, profile : c.int
	sdl.GL_GetAttribute(.CONTEXT_MAJOR_VERSION, &major)
	sdl.GL_GetAttribute(.CONTEXT_MAJOR_VERSION, &minor)
	sdl.GL_GetAttribute(.CONTEXT_PROFILE_MASK, &profile)
	fmt.printf("OpenGL version: {}.{}, profile: {}\n", major, minor, cast(sdl.GLprofile)profile)

}
app_release :: proc() {
    free(app)
}

app_run :: proc() {
	using app

	main_window := create_main_window()
	helper_window := create_helper_window()

	register_window(&main_window, WndMainData)
	register_window(&helper_window)

    evt := sdl.Event{}

	for len(windows) > 0 {
		app_time_step()
		
		if sdl.PollEvent(&evt) {
			wid := evt.window.windowID
			if wnd, has := windows[wid]; has && wnd.handler != nil {
				wnd.handler(wnd, evt)
			}
		} 

		// update and render
		for id, wnd in &windows {
			if wnd.render != nil {
				if wnd.is_opengl_window {
					assert(sdl.GL_MakeCurrent(wnd.window, wnd.gl_context) == 0, 
						fmt.tprintf("Failed to switch gl context, because: {}\n", sdl.GetError()))
				}
				if wnd.update != nil do wnd.update(wnd)
				if wnd.render != nil do wnd.render(wnd)
			}
		}
	}

	sdl.Quit()
}

@(private ="file")
app_time_step :: proc() {
	using app
	time.stopwatch_stop(&stopwatch)
	duration := time.stopwatch_duration(frame_stopwatch)

	duration_frame = duration - duration_total
	duration_total = duration

	time.stopwatch_start(&frame_stopwatch)
}

register_window :: proc {
	register_window_with_data,
	register_window_without_data,
}

register_window_with_data :: proc(wnd:^Window, $DataType: typeid) {
	using app
	window_instantiate(wnd, DataType)
	reg_window(wnd)
}
register_window_without_data :: proc(wnd:^Window) {
	using app
	window_instantiate(wnd)
	reg_window(wnd)
}

@(private="file")
reg_window :: proc(wnd:^Window) {
	using app
	id := window_get_id(wnd)
	has := id in windows
	if !has do windows[id] = wnd
	else do fmt.println("window has been registered")

	// TODO(Dove): Optimize window removing.
	wnd.before_destroy = proc(wnd:^Window) {
		remove_id := window_get_id(wnd)
		remove_window(remove_id)
	}
}

remove_window :: proc(id:u32) {
	using app
	if id in windows {
		wnd := windows[id]
		fmt.println("window: ", id, ": ", wnd.name, " removed, now ", len(windows), " windows left.")
        delete_key(&windows, id)
	}
}
