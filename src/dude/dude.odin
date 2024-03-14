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

GameInitializer :: struct {
    window : WindowInitializer,
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

	app_run()
}

init :: proc(wnd : WindowInitializer) {
    _game_initializer.window = wnd
}