package dude

import "dgl"

AssetTexture :: struct {
    size : Vec2i,
    id : u32,
}
AssetShader :: struct {
    id : u32,
}
AssetAudioClip :: struct {
    clip : AudioClip,
}
AssetFont :: struct {
    font : DynamicFont,
}