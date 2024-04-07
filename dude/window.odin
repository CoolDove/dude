package dude

import "core:fmt"
import "core:os"
import "core:strings"
import sdl  "vendor:sdl2"
import gl   "vendor:OpenGL"


OPENGL_VERSION_MAJOR :: 4
OPENGL_VERSION_MINOR :: 4

Window :: struct {
    handler  : proc(wnd:^Window, event:sdl.Event),

	position, size : Vec2i,

	name     : string,

    window   : ^sdl.Window,
    gl_context : sdl.GLContext,
}

window_instantiate :: proc(config: ^DudeConfigWindow, using wnd:^Window) -> bool {
    wnd.position = config.position
    wnd.size = {config.width, config.height}

    flags : sdl.WindowFlags = {.OPENGL, .ALLOW_HIGHDPI}
    if config.resizable do flags = flags | { .RESIZABLE }
	window = sdl.CreateWindow(
	    strings.clone_to_cstring(config.title, context.temp_allocator),
	    config.position.x, config.position.y, config.width, config.height,
	    flags)

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
    
    // v sync is disabled for event-driven window
    if !config.event_driven do sdl.GL_SetSwapInterval(1)

    gl.Enable(gl.MULTISAMPLE)

    wnd.handler = config.custom_handler
    return true
}

window_destroy :: proc(using wnd:^Window) {
	if window == nil do return
	sdl.DestroyWindow(window)
	window = nil
}
