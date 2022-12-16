package main

import "core:fmt"
import "core:os"
import "core:strings"
import sdl  "vendor:sdl2"
import gl   "vendor:OpenGL"


OPENGL_VERSION_MAJOR :: 4
OPENGL_VERSION_MINOR :: 5

Window :: struct {
	// NOTE(Dove): 
	// The GLContext is not correct during `handler`, 
	// so do not use any OpenGL things in `handler`.
	using window_handler : WindowHandler,
	using window_events : WindowEvents,

	position, size : IVec2,

	name     : string,

	window_flags   : sdl.WindowFlags,
	renderer_flags : sdl.RendererFlags,

    window   : ^sdl.Window,
	renderer : ^sdl.Renderer,

	is_opengl_window : bool,
	gl_context : sdl.GLContext,

	_data_type : typeid,
	_data : rawptr, // This is invalid before instantiated.
}

WindowHandler :: struct {
	handler  : proc(wnd:^Window, event:sdl.Event), 
	render   : proc(wnd:^Window),
	update 	 : proc(wnd:^Window),
}
WindowEvents :: struct {
	before_destroy : proc(wnd:^Window),
	after_instantiate : proc(wnd:^Window),
}

IVec2 :: [2]i32

Event :: struct {
	event : ^sdl.Event,
}

window_get_basic_template :: proc(name: string, size : IVec2 = IVec2{800, 600}, is_opengl_window : bool = true) -> Window {
	wnd : Window
	wnd.name = name
	wnd.handler = nil
	wnd.render = nil
	wnd.is_opengl_window = is_opengl_window
	if is_opengl_window {
		wnd.window_flags |= {.OPENGL}
	} 
	wnd.position = sdl.WINDOWPOS_CENTERED
	wnd.size = size
    return wnd
}

// window_instantiate_with_data :: proc($DataType: typeid, using wnd: ^Window) -> bool {
// 	instantiate_result := window_instantiate(wnd)
// 	wnd._data = new(typeid)
// 	wnd._data_type = DataType
// 	return instantiate_result
// }

window_instantiate :: proc {
	window_instantiate_with_data,
	window_instantiate_without_data,
}

window_instantiate_with_data :: proc(using wnd:^Window, $DataType: typeid) -> bool {
	create_result := create_window_and_init_opengl(wnd)
	_data = new(DataType)
	_data_type = DataType

	if after_instantiate != nil do after_instantiate(wnd)
	return create_result
}
window_instantiate_without_data :: proc(using wnd:^Window) -> bool {
	create_result := create_window_and_init_opengl(wnd)
	if after_instantiate != nil do after_instantiate(wnd)
	return create_result
}

@(private="file")
create_window_and_init_opengl :: proc(using wnd: ^Window)  -> bool {
	window = sdl.CreateWindow(
	    strings.clone_to_cstring(name, context.temp_allocator),
	    position.x, position.y, size.x, size.y,
	    window_flags)

	if !window_is_good(wnd) {
        fmt.println("failed to instantiate window: ", name)
		return false
	}

	if is_opengl_window {
		gl_context = sdl.GL_CreateContext(window)
		assert(gl_context != nil, fmt.tprintf("Failed to create GLContext for window: {}, because: {}.\n", name, sdl.GetError()))

		sdl.GL_MakeCurrent(window, gl_context)
		gl.load_up_to(OPENGL_VERSION_MAJOR, OPENGL_VERSION_MINOR, sdl.gl_set_proc_address)
	} else {
		renderer = sdl.CreateRenderer(window, -1, renderer_flags)
		assert(renderer != nil, fmt.tprintf("Failed to create renderer for window: {}, because: {}.\n", name, sdl.GetError()))
	}
	return true
}

window_data :: proc($Type:typeid, using wnd: ^Window) -> ^Type {
	assert(_data != nil, fmt.tprintf("Failed to get window: {}'s data, cuz it has no data.\n", name))
	return cast(^Type)_data
}

window_destroy :: proc(using wnd:^Window) {
	if window == nil do return

	if before_destroy!=nil do before_destroy(wnd)

	if _data != nil do free(_data)
	sdl.DestroyWindow(window)
	if renderer != nil do sdl.DestroyRenderer(renderer)
	window = nil
    renderer = nil
}

window_is_good :: proc(using wnd:^Window) -> bool {
	return window != nil
}

window_get_id :: proc(using wnd:^Window) -> u32 {
	return sdl.GetWindowID(window)
}