package dgl

import "core:fmt"
import "core:reflect"
import gl "vendor:OpenGL"
import "core:strings"

UniformLoc :: i32
UniformLocF32 :: UniformLoc
UniformLocVec2 :: UniformLoc
UniformLocVec4 :: UniformLoc
UniformLocTexture :: UniformLoc

uniform_load :: proc(data : ^$T, shader: ShaderId) {
    names := reflect.struct_field_names(T)
    types := reflect.struct_field_types(T)
    offsets := reflect.struct_field_offsets(T)

    for i in 0..<len(names) {
        if types[i].id == typeid_of(UniformLoc) {
            name := names[i]
            loc := gl.GetUniformLocation(shader, strings.clone_to_cstring(name, context.temp_allocator))
            ptr := cast(^UniformLoc)(cast(uintptr)data + offsets[i])
            ptr^ = auto_cast loc
        }
    }
}

uniform_set :: proc {
	uniform_set_f32,
    uniform_set_vec2,
    uniform_set_vec4,
    uniform_set_texture,
}

uniform_set_f32 :: proc(uniform : UniformLocF32, value: f32) {
	gl.Uniform1f(uniform, value);
}
uniform_set_vec2 :: proc(uniform : UniformLocVec2, vec: Vec2) {
    gl.Uniform2f(uniform, vec.x, vec.y)
}
uniform_set_vec4 :: proc(uniform : UniformLocVec4, vec: Vec4) {
    gl.Uniform4f(uniform, vec.x, vec.y, vec.z, vec.w)
}
uniform_set_texture :: proc(uniform : UniformLocTexture, texture, slot: u32) {
    gl.ActiveTexture(gl.TEXTURE0+slot)
    gl.BindTexture(gl.TEXTURE_2D, texture)
    gl.Uniform1i(uniform, cast(i32)slot)
}
