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
        for sdl.PollEvent(&evt) {
            _handle_event(&window, evt, &window_closed)
        }

        if !window_closed {
            app_time_step()
            input_before_update()

            game_update()

            sdl.GL_SwapWindow(app.window.window)
            input_after_update()
        }

    }

    game_release()
}

@private
app_run_event_driven :: proc(tick_delay : f32) {
    using app
    game_init()

    evt : sdl.Event
    window_closed : bool
    for sdl.WaitEvent(&evt) && !window_closed {
        _handle_event(&window, evt, &window_closed)

        for !window_closed && sdl.PollEvent(&evt) {
            _handle_event(&window, evt, &window_closed)
        }

        if !window_closed && _dispatch_update {
            _during_update = true; defer _during_update = false
            app_time_step()
            input_before_update()

            _dispatch_update = false
            game_update()

            sdl.GL_SwapWindow(app.window.window)
            input_after_update()
        }
        if tick_delay > 0 do sdl.Delay(auto_cast tick_delay)
    }

    game_release()
}

@(private="file")
_handle_event :: proc(window: ^Window, event: sdl.Event, window_close: ^bool) {
    if event.window.event == .RESIZED {
        old := window.size 
        window.size.x = event.window.data1
        window.size.y = event.window.data2
        game_on_resize(old, window.size)
    } else if event.window.event == .CLOSE {
        window_close^ = true
    } else {
        input_handle_sdl2(event)
    }
    if window.handler != nil {
        window.handler(window, event)
    }
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
