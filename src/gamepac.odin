package main


import "dude"
import "dude/dpac"
import "dude/dgl"

GameAssets :: struct {
    box : dgl.TextureId `dpac:"./res/texture/box.png"`,
    player : PlayerAssets,
    logo : []dgl.TextureId `dpac:"./res/texture/dude$(index).png"`,
    qq : dgl.TextureId `dpac:"./res/texture/qq.png"`,
    bg9slice : dgl.TextureId `dpac:"./res/texture/default_ui_background_9slice.png"`,
}

PlayerAssets :: struct {
    player1 : dgl.TextureId `dpac:"./res/texture/box.png"`,
    player2 : dgl.TextureId `dpac:"./res/texture/box.png"`,
}


assets : GameAssets
