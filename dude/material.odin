package dude

import "dgl"


Shader :: struct {
    shader_id : dgl.ShaderId,

    utable_transform : UniformTableTransform,
    utable_general : UniformTableGeneral,
    utable_sprite : UniformTableSprite,
}

shader_register_lib :: proc(name, source: string) {
    dgl.shader_preprocess_add_lib(name, source)
}

shader_init :: proc(using shader: ^Shader, vert_src, frag_src : string, preprocess:=true) {
    using dgl
    shader_id = dgl.shader_load_from_sources(vert_src, frag_src, preprocess)
    uniform_load(&utable_transform, shader_id)
    uniform_load(&utable_general, shader_id)
    uniform_load(&utable_sprite, shader_id)
}
shader_release :: proc(shader: ^Shader) {
    dgl.shader_destroy(shader.shader_id)
    shader^ = {}
}

Material :: struct {
    shader : ^Shader,
    mat : dgl.Material,
}

material_init :: proc(mat: ^Material, shader: ^Shader) {
    mat.shader = shader
    dgl.material_init(&mat.mat, shader.shader_id)
}
material_release :: proc(mat: ^Material) {
    dgl.material_release(&mat.mat)
}

material_set :: proc {
	material_set_f32,
	material_set_vec2,
	material_set_vec4,
	material_set_texture,
}

material_set_f32 :: proc(mat: ^Material, loc: dgl.UniformLocVec2, value: f32) {
    dgl.material_set_f32(&mat.mat, loc, value)
}
material_set_vec2 :: proc(mat: ^Material, loc: dgl.UniformLocVec2, value: Vec2) {
    dgl.material_set(&mat.mat, loc, value)
}
material_set_vec4 :: proc(mat: ^Material, loc: dgl.UniformLocVec4, value: Vec4) {
    dgl.material_set(&mat.mat, loc, value)
}
material_set_texture :: proc(mat: ^Material, loc: dgl.UniformLocTexture, texture: u32) {
    dgl.material_set(&mat.mat, loc, texture)
}

// ** dgl uniform extensions powered by uniform table.
uniform_transform :: proc(utable: UniformTableTransform, position,scale: Vec2, angle: f32) {
    dgl.uniform_set_vec2(utable.position, position)
    dgl.uniform_set_vec2(utable.scale, scale)
    dgl.uniform_set_f32(utable.angle, angle)
}