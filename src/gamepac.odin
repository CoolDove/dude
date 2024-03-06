package main


import "dude"
import "dude/dpac"
import "dude/dgl"

GameAssets :: struct {
    box : dude.AssetTexture `dpac:"./res/texture/box.png"`,
    dude_logo : dude.AssetTexture `dpac:"./res/texture/dude.png"`,
    dude_logos : []dude.AssetTexture `dpac:"./res/texture/dude$(index).png"`,
    qq : dude.AssetTexture `dpac:"./res/texture/qq.png"`,
    bg9slice : dude.AssetTexture `dpac:"./res/texture/default_ui_background_9slice.png"`,
    font_inkfree : dude.AssetFontFile `dpac:"./res/font/inkfree.ttf"`,
    nothing : PlayerAssets,
}

PlayerAssets :: struct {
    player1 : dude.AssetTexture `dpac:"./res/texture/box.png"`,
    player2 : dude.AssetTexture `dpac:"./res/texture/box.png"`,
}

assets : GameAssets