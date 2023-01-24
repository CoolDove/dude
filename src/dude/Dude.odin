package dude

import "core:log"

dude_main :: proc() {
	when ODIN_DEBUG {
		logger := log.create_console_logger(.Debug, {.Level, .Short_File_Path, .Line, .Terminal_Color})
		context.logger = logger
	}

	if !game_installed {
		log.errorf("Dude: Game is not installed, `dude.install_game` please.")
		return
	}

	app_init();
	app_run();
	app_release();
}

@(private)
GameConfig :: struct {
	name : string,
}

@(private)
game_config := GameConfig {
	name = "DudeEngine",
}
@(private)
game_installed :bool= false

install_game :: proc(name: string) {
	game_config.name = name
	game_installed = true
}

install_scene :: proc(key: string, scene: Scene) {
	registered_scenes[key] = scene
}

set_default_scene :: proc(key: string) {
	default_scene = key
}