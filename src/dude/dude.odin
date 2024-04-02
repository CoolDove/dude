package dude

import "core:fmt"
import "core:os"
import "core:log"

import mui "microui"

@(private)
_callback_update : proc(game: ^Game, delta:f32)
@(private)
_callback_init : proc(game: ^Game)
@(private)
_callback_release : proc(game: ^Game)
@(private)
_callback_mui : proc(ctx: ^mui.Context)


// If you want a event-driven window, you should set event_driven to true, and use window.handler to
//  write the logic, and call `manually_update` somewhere you desire.
GameInitializer :: struct {
    window : WindowInitializer,
    event_driven : bool,
}

@private
_game_initializer : GameInitializer


dude_main :: proc(update: proc(game: ^Game, delta:f32), init, release: proc(game: ^Game), mui: proc(ctx:^mui.Context)) {
	when ODIN_DEBUG {
		logger := log.create_console_logger(.Debug, {.Level, .Short_File_Path, .Line, .Terminal_Color})
		context.logger = logger
	}

    _callback_update = update
    _callback_init = init
    _callback_release = release
    _callback_mui = mui

    if _game_initializer.event_driven do app_run_event_driven()
	else do app_run()
}

init :: proc(wnd : WindowInitializer, event_driven:= false) {
    _game_initializer.window = wnd
    _game_initializer.event_driven = event_driven
}

@private
_manually_update := false
manually_update :: proc() {
    _manually_update = true
}