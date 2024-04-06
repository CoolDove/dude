package dgl

import "core:fmt"
import "core:reflect"
import "core:slice"
import gl "vendor:OpenGL"
import "core:strings"

UniformLoc :: i32
UniformLocF32 :: UniformLoc
UniformLocVec2 :: UniformLoc
UniformLocVec4 :: UniformLoc
UniformLocTexture :: UniformLoc

// So-called `UniformBlock` is just a struct with UniformLoc in its fields. You can use `uniform_load`
//  to load uniform locations from a shader. The uniform name is the field's name, or you can tag it
//  by `uniform` to override the uniform name.
// The `UniformBlock` can contain `UniformLoc`(i32) only.

uniform_table_is_loaded :: proc(utable: ^$T) -> bool {
    count := size_of(T)/size_of(UniformLoc)
    assert(count > 1, fmt.tprintf("UniformTable: {} is not a valid UniformBlock.\n", typeid_of(T)))
    locs :[]UniformLoc= slice.from_ptr(cast(^UniformLoc)utable, count)
    zero_count, loc_count := 0, 0
    for i in 0..<count {
        if locs[i] == 0 do zero_count += 1
        if zero_count > 1 do return false // With two zero means not loaded.
        loc_count += 1
    }
    return loc_count > 1
}

// This process will find uniform locations for the struct you passed in from param `data`.
//  Only fields who's type is UniformLoc are loaded. By default it will use the field name to look
//  for uniforms in the shader. You can also use tag `uniform` to manually specify the uniform name.
uniform_load :: proc(utable : ^$T, shader: ShaderId) {
    names := reflect.struct_field_names(T)
    types := reflect.struct_field_types(T)
    offsets := reflect.struct_field_offsets(T)
    tags := reflect.struct_field_tags(T)

    for i in 0..<len(names) {
        if types[i].id == typeid_of(UniformLoc) {
            name := names[i]
            if tag, ok := reflect.struct_tag_lookup(tags[i], "uniform"); ok {
                name = cast(string)tag
            }
            loc := gl.GetUniformLocation(shader, strings.clone_to_cstring(name, context.temp_allocator))
            ptr := cast(^UniformLoc)(cast(uintptr)utable + offsets[i])
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
    if uniform == -1 do return
	gl.Uniform1f(uniform, value);
}
uniform_set_vec2 :: proc(uniform : UniformLocVec2, vec: Vec2) {
    if uniform == -1 do return
    gl.Uniform2f(uniform, vec.x, vec.y)
}
uniform_set_vec4 :: proc(uniform : UniformLocVec4, vec: Vec4) {
    if uniform == -1 do return
    gl.Uniform4f(uniform, vec.x, vec.y, vec.z, vec.w)
}
uniform_set_texture :: proc(uniform : UniformLocTexture, texture, slot: u32) {
    if uniform == -1 do return
    gl.ActiveTexture(gl.TEXTURE0+slot)
    gl.BindTexture(gl.TEXTURE_2D, texture)
    gl.Uniform1i(uniform, cast(i32)slot)
}