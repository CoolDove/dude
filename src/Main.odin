package main

import "core:log"
import "core:math/linalg"

import "dude"
import "dude/ecs"

sc := dude.Scene{}

main :: proc() {
    dude.install_game("Dude")

    dude.install_scene("Demo", scene_demo)
    when dude.DUDE_3D_GAME do dude.install_scene("Mushroom", scene_mushroom)
    dude.set_default_scene("Demo")

    dude.dude_main()
}