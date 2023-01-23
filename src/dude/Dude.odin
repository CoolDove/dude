package dude

import "core:log"

dude_main :: proc() {
	when ODIN_DEBUG {
		logger := log.create_console_logger(.Debug, {.Level, .Short_File_Path, .Line, .Terminal_Color})
		context.logger = logger
	}

	app_init();
	defer app_release();
	app_run();
}
