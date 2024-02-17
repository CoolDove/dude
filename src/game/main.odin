package main

import "core:fmt"
import "core:log"
import "core:math/linalg"

import "../dude"
import "../dude/ecs"

sc := dude.Scene{}


main :: proc() {
	dude.init("dude", {_package_game, _test})

    dude.install_scene("Demo", scene_demo)
    dude.set_default_scene("Demo")

    dude.dude_main()
}


@(private="file")
_package_game :: proc(args: []string) {
	fmt.printf("command: package game\n")
}
@(private="file")
_test :: proc(args: []string) {
	fmt.printf("command: test\n")
}
