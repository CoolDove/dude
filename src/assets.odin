package main


import "core:fmt"
import "core:reflect"
import "dude"
import "dude/dpac"
import "dude/dgl"
import "dude/render"

GameAssets :: struct {
    using sfx : SoundEffectAssets,
    box : dude.AssetTexture `dpac:"./res/texture/box.png"`,
    dude_logo : dude.AssetTexture `dpac:"./res/texture/dude.png"`,
    dude_logos : []dude.AssetTexture `dpac:"./res/texture/dude$(index).png"`,
    qq : dude.AssetTexture `dpac:"./res/texture/qq.png"`,
    bg9slice : dude.AssetTexture `dpac:"./res/texture/default_ui_background_9slice.png"`,
    font_inkfree : dude.AssetFont `dpac:"./res/font/inkfree.ttf"`,
    nothing : PlayerAssets,
}

PlayerAssets :: struct {
    player1 : dude.AssetTexture `dpac:"./res/texture/box.png"`,
    player2 : dude.AssetTexture `dpac:"./res/texture/box.png"`,
}
SoundEffectAssets :: struct {
    hit : dude.AssetAudioClip `dpac:"./res/sfx/hit.wav"`,
    bgm_eddie_theme : dude.AssetAudioClip `dpac:"./res/sfx/eddie_theme.mp3"`,
    bgm_hotel_california : dude.AssetAudioClip `dpac:"./res/sfx/hotel_california.mp3"`,
}

assets : GameAssets