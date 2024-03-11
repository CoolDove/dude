package dude

import "dgl"

AssetTexture :: struct {
    size : Vec2i,
    id : u32,
}
AssetShader :: struct {
    id : u32,
}
AssetAudio :: struct {
    id : u32,
}
AssetFontFile :: struct {
    data: []u8,
}