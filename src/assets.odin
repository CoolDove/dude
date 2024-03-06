package main


import "core:fmt"
import "core:reflect"
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

dove_assets_handler :: proc(e: dpac.PacEvent, p: rawptr, t: ^reflect.Type_Info, data: []u8) {
    if e == .Load {
        // fmt.printf("Load asset: {}({} bytes)\n", t.id, len(data))
        if t.id == dude.AssetTexture {
            atex := cast(^dude.AssetTexture)p
            tex := dgl.texture_load(data)
            atex.id = tex.id
            atex.size = tex.size
            fmt.printf("Load texture. {}-{}\n", atex.id, atex.size)
        } else if t.id == dude.AssetFontFile {
            afont := cast(^dude.AssetFontFile)p
            afont.data = data
            fmt.printf("Load font file.\n")
        } else {
            fmt.printf("Load unknown type asset.\n")
        }
    } else if e == .Release {
        if t.id == dude.AssetTexture {
            atex := cast(^dude.AssetTexture)p
            dgl.texture_delete(&atex.id)
            fmt.printf("Release texture {} ({}).\n", atex.id, atex.size)
        } else if t.id == dude.AssetFontFile {
            fmt.printf("Release Font file.\n")
        } else {
            fmt.printf("Release unknown type.\n")
        }
    }
}