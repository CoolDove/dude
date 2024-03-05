package main


import "dude"
import "dude/dpac"
import "dude/dgl"

GameAssets :: struct {
    player : dgl.TextureId `dpac:"./res/texture/box.png"`,
    logo : []dgl.TextureId `dpac:"./res/texture/dude$(index).png"`,
    qq : dgl.TextureId `dpac:"./res/texture/qq.png"`,
    bg9slice : dgl.TextureId `dpac:"./res/texture/default_ui_background_9slice.png"`,
}

assets : GameAssets