package main

import "core:fmt"
import "core:os"
import "core:strings"
import "core:log"

import sdl "vendor:sdl2"
import gl  "vendor:OpenGL"

// import scrshit "foreign:screenshit"

main :: proc() {
	logger := log.create_console_logger(.Debug, {.Level, .Short_File_Path, .Line, .Terminal_Color})
	context.logger = logger

	app_init();
	defer app_release();
	app_run();
}


/*===============================================*/
// clib_test :: proc() {
// 	fmt.println("1+2=", scrshit.export_add(1, 2));

// 	data := scrshit.alloc_mem(23);
// 	fmt.println("ptr: ", data);
// 	for ind in 0..<23 {
// 		fmt.println(ind, ": ", data[ind]);
// 	}
// 	scrshit.release_mem(data);

// 	fmt.println("ptr: ", data);
// 	for ind in 0..<23 {
// 		fmt.println(ind, ": ", data[ind]);
// 	}
// }

// list_dir :: proc(dir_name:string) {
// 	handle, handle_ok := os.open(dir_name);
// 	defer os.close(handle)
// 	files, ok := os.read_dir(handle, 0, context.temp_allocator);

// 	fmt.println("====", dir_name, "-", len(files));

// 	for f in files {
// 		fmt.println(f.fullpath);
// 	}
// }
