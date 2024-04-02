package dude

import "core:fmt"
import "core:os"
import "core:strings"
import sdl  "vendor:sdl2"
import gl   "vendor:OpenGL"


OPENGL_VERSION_MAJOR :: 4
OPENGL_VERSION_MINOR :: 4

Window :: struct {
	// NOTE(Dove): 
	// The GLContext is not correct during `handler`, 
	// so do not use any OpenGL things in `handler`.
    handler  : proc(wnd:^Window, event:sdl.Event),

	position, size : Vec2i,

	name     : string,

    window   : ^sdl.Window,
    gl_context : sdl.GLContext,
}

WindowInitializer :: struct {
    name : string,
    position : Vec2i,
    size : Vec2i,
    flags : sdl.WindowFlags,
    handler : proc(using wnd:^Window, event:sdl.Event),
}

window_instantiate :: proc(i : WindowInitializer, using wnd:^Window) -> bool {
    wnd.position = i.position
    wnd.size = i.size

	window = sdl.CreateWindow(
	    strings.clone_to_cstring(i.name, context.temp_allocator),
	    i.position.x, i.position.y, i.size.x, i.size.y,
	    i.flags | { .OPENGL })

	if window == nil {
        fmt.println("failed to instantiate window: ", name)
		return false
	}

	// if .FULLSCREEN in wnd.window_flags {
	// 	if sdl.WindowFlag._INTERNAL_FULLSCREEN_DESKTOP in window_flags do fullscreen = .FullscreenDesktop
	// 	else do fullscreen = .Fullscreen
	// } else do fullscreen = .Windowed

    gl_context = sdl.GL_CreateContext(window)
    assert(gl_context != nil, fmt.tprintf("Failed to create GLContext for window: {}, because: {}.\n", name, sdl.GetError()))

    sdl.GL_MakeCurrent(window, gl_context)
    gl.load_up_to(OPENGL_VERSION_MAJOR, OPENGL_VERSION_MINOR, sdl.gl_set_proc_address)
    sdl.GL_SetSwapInterval(1)

    gl.Enable(gl.MULTISAMPLE)

    wnd.handler = i.handler
    return true
}

window_destroy :: proc(using wnd:^Window) {
	if window == nil do return
	sdl.DestroyWindow(window)
	window = nil
}
