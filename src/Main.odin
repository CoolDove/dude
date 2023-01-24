package main

import "core:log"
import "core:math/linalg"


import "dude"
import "dude/ecs"


main :: proc() {
    dude.install_scene("Test", SceneTest)
    dude.install_scene("Mushroom", SceneMushroom)
    // dude.set_default_scene("Test")

    dude.dude_main()
}