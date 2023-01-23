package dude

import "core:log"

dude_main :: proc() {
	when ODIN_DEBUG {
		logger := log.create_console_logger(.Debug, {.Level, .Short_File_Path, .Line, .Terminal_Color})
		context.logger = logger
	}

	app_init();
	app_run();
	app_release();
}

install_scene :: proc(key: string, scene: Scene) {
	registered_scenes[key] = scene
}

set_default_scene :: proc(key: string) -> bool {
	if key in registered_scenes {
		default_scene = &registered_scenes[key]
		return true
	} else {
		return false
	}
}