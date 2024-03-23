package main


import "core:fmt"
import "core:reflect"
import "dude"
import "dude/dpac"
import "dude/dgl"

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

dove_assets_handler :: proc(e: dpac.PacEvent, p: rawptr, t: ^reflect.Type_Info, data: []u8) {
    if e == .Load {
        if t.id == dude.AssetTexture {
            atex := cast(^dude.AssetTexture)p
            tex := dgl.texture_load(data)
            atex.id = tex.id
            atex.size = tex.size
            fmt.printf("Load texture. {}-{}\n", atex.id, atex.size)
        } else if t.id == dude.AssetFont {
            font := cast(^dude.AssetFont)p
            font.font = dude.font_load(data, "infree")
            dude.font_add_fallback(font.font, dude.render.system.font_unifont)
            fmt.printf("Load font.\n")
        } else if t.id == dude.AssetAudioClip {
            asset := cast(^dude.AssetAudioClip)p
            clip := &asset.clip
            dude.audio_clip_load_from_mem(data, clip, {.Decode,.Stream,.Async})
            fmt.printf("Load audio clip.\n")
        } else {
            fmt.printf("Load unknown type asset.\n")
        }
    } else if e == .Release {
        if t.id == dude.AssetTexture {
            atex := cast(^dude.AssetTexture)p
            dgl.texture_delete(&atex.id)
            fmt.printf("Release texture {} ({}).\n", atex.id, atex.size)
        } else if t.id == dude.AssetFont {
            dude.font_unload((cast(^dude.AssetFont)p).font)
            fmt.printf("Release Font file.\n")
        } else {
            fmt.printf("Release unknown type.\n")
        }
    }
}