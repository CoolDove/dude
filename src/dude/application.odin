package dude

import "core:fmt"
import "core:os"
import "core:strings"
import "core:time"
import "core:c"
import "core:log"

import win32 "core:sys/windows"

import sdl  "vendor:sdl2"
import gl   "vendor:OpenGL"


// Forget about multi-window things.

Application :: struct {
	window : Window,

	duration_total : time.Duration,
	duration_frame : time.Duration,

	stopwatch : time.Stopwatch,
	frame_stopwatch : time.Stopwatch,
}

app : Application

app_init :: proc() {
	when ODIN_OS == .Windows do win32.SetConsoleOutputCP(65001)

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
	log.infof("OpenGL version: {}.{}, profile: {}", major, minor, cast(sdl.GLprofile)profile)
}

app_release :: proc() {
	sdl.Quit()
}

app_run :: proc() {
	using app

	window = create_main_window()
	window_instantiate(&window)

    evt := sdl.Event{}

	for !window.killed {
		app_time_step()
		
		// ## Handle events
		if sdl.PollEvent(&evt) && window.handler != nil {
			if evt.window.event == .RESIZED {
				window.size.x = evt.window.data1
				window.size.y = evt.window.data2
			} else if evt.window.event == .CLOSE {
				if window.before_destroy != nil do window.before_destroy(&window)
				window_destroy(&window)
				window.killed = true
			} else {
				window.handler(&window, evt)
			}
		} 

		// update and render
		if !window.killed && window.update != nil {
			window.update(&window)
		}
	}
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
