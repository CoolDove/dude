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

@private
app_run :: proc() {
    using app
    game_init()

    evt : sdl.Event
    window_closed : bool
    for !window_closed {
        app_time_step()
        
        // ## Handle events
        for sdl.PollEvent(&evt) {
            if evt.window.event == .RESIZED {
                old := window.size 
                window.size.x = evt.window.data1
                window.size.y = evt.window.data2
                game_on_resize(old, window.size)
            } else if evt.window.event == .CLOSE {
                window_closed = true
            } else {
                input_handle_sdl2(evt)
            }
            if window.handler != nil {
                window.handler(&window, evt)
            }
        }

        if !window_closed {
            input_before_update()

            game_update()

            sdl.GL_SwapWindow(app.window.window)
            input_after_update()
        }

    }

    game_release()
}

@private
app_run_event_driven :: proc() {
    using app
    game_init()

    evt : sdl.Event
    window_closed : bool
    for !window_closed {
        app_time_step()
        
        // ## Handle events
        for sdl.WaitEvent(&evt) && !window_closed {
            if evt.window.event == .RESIZED {
                old := window.size 
                window.size.x = evt.window.data1
                window.size.y = evt.window.data2
                game_on_resize(old, window.size)
            } else if evt.window.event == .CLOSE {
                window_closed = true
            } else {
                input_handle_sdl2(evt)
            }
            if window.handler != nil {
                window.handler(&window, evt)
            }
            if !window_closed && _dispatch_update {
                // Input is not available for event-driven game.
                // input_before_update()

                game_update()

                sdl.GL_SwapWindow(app.window.window)
                // input_after_update()
                _dispatch_update = false
            }
        }
    }

    game_release()
}


@private
app_init :: proc(config: ^DudeConfig) {
    using app
    when ODIN_OS == .Windows do win32.SetConsoleOutputCP(65001)

    time.stopwatch_start(&app.stopwatch)

    sdl.SetHint("SDL_IME_SHOW_UI", "1")
    sdl.SetHint(sdl.HINT_IME_INTERNAL_EDITING, "1")

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


    window_instantiate(&config.window, &window)

    input_init()
}
@private
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
