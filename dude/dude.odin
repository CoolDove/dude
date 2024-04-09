package dude

import "core:fmt"
import "core:os"
import "core:log"
import sdl "vendor:sdl2"
import mui "microui"

@(private)
_callback_update : proc(game: ^Game, delta:f32)
@(private)
_callback_init : proc(game: ^Game)
@(private)
_callback_release : proc(game: ^Game)
@(private)
_callback_mui : proc(ctx: ^mui.Context)


// If you want a event-driven window, you should set `event_driven` to true, and use `custom_handler` to
//  write the logic, and call `dispatch_update` somewhere to invoke an `update` callback.
@private
_dude_startup_config : DudeConfig

dude_main :: proc(config: ^DudeConfig) {
    logger : log.Logger
	when ODIN_DEBUG {
		logger = log.create_console_logger(.Debug, {.Level, .Short_File_Path, .Line, .Terminal_Color})
		context.logger = logger
	}

    using config
    _dude_startup_config = config^
    _callback_update = update
    _callback_init = init
    _callback_release = release
    _callback_mui = mui
    
    app_init(config)

    if event_driven do app_run_event_driven(event_driven_tick_delay_time_ms)
	else do app_run()
	
	app_release()
	
	log.destroy_console_logger(logger)
}

// Just to initialize the game, anything in here can be changed by related API (changing this struct
//  directly during runtime doesn't make sense).
DudeConfig :: struct {
    default_font_data : []u8,
    using window : DudeConfigWindow,
    using callbacks : DudeConfigCallbacks,
}

DudeConfigCallbacks :: struct {
    update : proc(game: ^Game, delta:f32),
    init : proc(game: ^Game),
    release : proc(game: ^Game),
    mui : proc(ctx: ^mui.Context),
}
DudeConfigWindow :: struct {
    title : string,
    position : Vec2i,
    width, height: i32,
    event_driven : bool,
    event_driven_tick_delay_time_ms : f32,
    resizable : bool,
    custom_handler : proc(using wnd:^Window, event:sdl.Event),
}

@private
_dispatch_update := false
@private
_during_update := false
dispatch_update :: proc() {
    _dispatch_update = true
    // @TEMPORARY: Send a custom event to trigger next update.
    if _during_update {
        custom_event : sdl.Event
        custom_event.type = .USEREVENT
        custom_event.user.code = 0
        custom_event.user.data1 = nil
        custom_event.user.data2 = nil
        sdl.PushEvent(&custom_event)
    }
}