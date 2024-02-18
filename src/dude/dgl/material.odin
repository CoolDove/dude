package dgl


Material :: struct {
	shader: ShaderId,
	values: [dynamic]MaterialValue,
}
MaterialValue :: union {
	f32, Vec2, Vec4, MaterialValueTexture,
}
MaterialValueTexture :: distinct Vec2i

material_init :: proc(mat: ^Material, shader: ShaderId) {
	mat.values = make([dynamic]MaterialValue)
	mat.shader = shader
}
material_release :: proc(using mat: ^Material) {
	delete(values)
}

material_upload :: proc(mat: Material) {
	shader_bind(mat.shader)
	for value, idx in mat.values {
		loc :i32= auto_cast idx
		if value != nil {
			switch v in value {
			case f32:
				uniform_set_f32(loc, v)
			case Vec2:
				uniform_set_vec2(loc, v)
			case Vec4:
				uniform_set_vec4(loc, v)
			case MaterialValueTexture:
				uniform_set_texture(loc, cast(u32)v.x, cast(u32)v.y)
			}
		}
	}
}


// This is meant to be used together with uniform.
material_set :: proc {
	material_set_vec2,
	material_set_vec4,
	material_set_texture,
}
material_set_vec2 :: proc(mat: ^Material, loc: UniformLocVec2, value: Vec2) {
	_material_capacity_ensure(mat, loc)
	mat.values[loc] = value
}
material_set_vec4 :: proc(mat: ^Material, loc: UniformLocVec4, value: Vec4) {
	_material_capacity_ensure(mat, loc)
	mat.values[loc] = value
}
material_set_texture :: proc(mat: ^Material, loc: UniformLocTexture, texture, slot: u32) {
	_material_capacity_ensure(mat, loc)
	mat.values[loc] = MaterialValueTexture{auto_cast texture, auto_cast slot}
}

@(private="file")
_material_capacity_ensure :: #force_inline proc(mat: ^Material, to: i32) {
	if len(mat.values) <= cast(int)to {
		for i in len(mat.values)..<cast(int)(to+1) {
			append(&mat.values, nil)
		}
	}
}
