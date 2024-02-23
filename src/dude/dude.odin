package dude

import "core:fmt"
import "core:os"
import "core:log"

// Build settings.
DUDE_STARTUP_COMMAND :string: #config(DUDE_STARTUP_COMMAND, "GAME")
DUDE_GAME :: DUDE_STARTUP_COMMAND == "GAME"


@(private)
_callback_update : proc(game: ^Game, delta:f32)
@(private)
_callback_init : proc(game: ^Game)
@(private)
_callback_release : proc(game: ^Game)
@(private)
_callback_gui : proc()

dude_main :: proc(update: proc(game: ^Game, delta:f32), init, release: proc(game: ^Game), gui : proc()) {
	when ODIN_DEBUG {
		logger := log.create_console_logger(.Debug, {.Level, .Short_File_Path, .Line, .Terminal_Color})
		context.logger = logger
	}

	if !game_installed {
		log.errorf("Dude: Game is not installed, `dude.install_game` please. Now dude.init()")
		return
	}

	when DUDE_STARTUP_COMMAND == "PACKAGE_GAME" {
		game_config.commands.package_game(os.args[1:])
		return
	} else when DUDE_STARTUP_COMMAND == "TEST" {
		game_config.commands.test(os.args[1:])
		return
	} else when DUDE_STARTUP_COMMAND != "GAME" {
		fmt.printf("unrecognized command: {}", DUDE_STARTUP_COMMAND)
		return
	}

    _callback_update = update
    _callback_init = init
    _callback_release = release
    _callback_gui = gui

	when DUDE_STARTUP_COMMAND == "GAME" {
		app_run()
	}
}

@(private)
GameConfig :: struct {
	name : string,
	commands : DudeStartupCommands,
}

@(private)
game_config := GameConfig {
	name = "DudeEngine",
}
@(private)
game_installed :bool= false

init :: proc(name: string, commands: DudeStartupCommands) {
	game_config.name = name
	game_config.commands = commands
	game_installed = true
}

// install_scene :: proc(key: string, scene: Scene) {
	// registered_scenes[key] = scene
// }

// set_default_scene :: proc(key: string) {
	// default_scene = key
// }

DudeStartupCommands :: struct {
	package_game, test : proc(args: []string),
}
