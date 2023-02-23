package dude


import "core:path/filepath"
import gl "vendor:OpenGL"

import "dgl"
import "dpac"

AssetTexture :: struct {
    load : string,
    id : u32,
}

dpac_init :: proc() {
    dpac.dpac_install(&allocators.default)
    dpac.dpac_register_asset("Color", Color, nil)
    dpac.dpac_register_asset("Texture", AssetTexture, texture_loader)
}

texture_loader :: proc(data: rawptr, value: ^dpac.DPacObject) -> rawptr {
    tex := cast(^AssetTexture)data
    tex.id = dgl.texture_load(tex.load).id
    return tex
}