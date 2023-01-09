package main

import "core:fmt"
import "core:os"
import "core:strings"
import "core:log"

import sdl "vendor:sdl2"
import gl  "vendor:OpenGL"

main :: proc() {
	when ODIN_DEBUG {
		logger := log.create_console_logger(.Debug, {.Level, .Short_File_Path, .Line, .Terminal_Color})
		context.logger = logger
	}

	app_init();
	defer app_release();
	app_run();
}
