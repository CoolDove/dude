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

app_run :: proc() {
	using app
    app_init()
    game_init()

    evt : sdl.Event
    window_closed : bool
	for !window_closed {
		app_time_step()
		
		// ## Handle events
		for sdl.PollEvent(&evt) && window.handler != nil {
			if evt.window.event == .RESIZED {
				window.size.x = evt.window.data1
				window.size.y = evt.window.data2
			} else if evt.window.event == .CLOSE {
                window_closed = true
			} else {
				window.handler(&window, evt)
			}
		} 

		// update and render
		if !window_closed {
            game_update()

            sdl.GL_SwapWindow(app.window.window)
            input_after_update_sdl2()
		}
	}

    game_release()
    app_release()
}


@(private="file")
app_init :: proc() {
	using app
	when ODIN_OS == .Windows do win32.SetConsoleOutputCP(65001)

	time.stopwatch_start(&app.stopwatch)

	if sdl.Init({.VIDEO, .EVENTS}) != 0 {
	    fmt.println("failed to init: ", sdl.GetErrorString())
		return
	}

	sdl.GL_SetAttribute(.CONTEXT_MAJOR_VERSION, OPENGL_VERSION_MAJOR)
	sdl.GL_SetAttribute(.CONTEXT_MINOR_VERSION, OPENGL_VERSION_MINOR)
	sdl.GL_SetAttribute(.CONTEXT_PROFILE_MASK, cast(i32)sdl.GLprofile.CORE)

    sdl.GL_SetAttribute(.MULTISAMPLEBUFFERS, 1)
    sdl.GL_SetAttribute(.MULTISAMPLESAMPLES, 4)
	
	major, minor, profile : c.int
	sdl.GL_GetAttribute(.CONTEXT_MAJOR_VERSION, &major)
	sdl.GL_GetAttribute(.CONTEXT_MAJOR_VERSION, &minor)
	sdl.GL_GetAttribute(.CONTEXT_PROFILE_MASK, &profile)
	log.infof("OpenGL version: {}.{}, profile: {}", major, minor, cast(sdl.GLprofile)profile)

	window = create_main_window()
	window_instantiate(&window)

	game.window = &window

    input_init()
    
}
@(private="file")
app_release :: proc() {
    input_release()
	window_destroy(&app.window)
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
