package dgl

import gl "vendor:OpenGL"


@(private="file")
_blit_fbo : FramebufferId
@(private="file")
_blit_shader : ShaderId
// @(private="file")
// _SHADER_LOC_MAIN_TEXTURE : i32
@(private="file")
_blit_quad : DrawPrimitive

DefaultBlitterUniforms :: struct {
    src_rect : UniformLocVec4,
    main_texture : UniformLocTexture,
}
@(private="file")
_default_blitter_uniform : DefaultBlitterUniforms

// If you want to set some custom uniforms, you should manually bind the shader
//  you're going to use before this process. And remember texture slot 0 has 
//  been used.
// dst_rect and src_rect are in pixel coordinate. dst_rect is implemented by `gl.Viewport`, so the
//  vertex shader can only consider transforming the blit quad into NDC.
blit_pro :: proc(shader : ShaderId, main_texture_loc : i32, src, dst: TextureId, src_size : Vec2, src_rect, dst_rect : Vec4) {
    if !_blit_is_initialized() do _blit_init()
    rem_fbo := framebuffer_current(); defer framebuffer_bind(rem_fbo)
    rem_shader := shader_current(); defer shader_bind(rem_shader)
    rem_viewport := state_get_viewport(); defer state_set_viewport(rem_viewport)

    framebuffer_bind(_blit_fbo)
    framebuffer_attach_color(0, dst)
    gl.Viewport(auto_cast dst_rect.x, auto_cast dst_rect.y, auto_cast dst_rect.z, auto_cast dst_rect.w)
    
    shader_bind(shader)
    gl.ActiveTexture(gl.TEXTURE0)
    gl.BindTexture(gl.TEXTURE_2D, src)
    gl.Uniform1i(main_texture_loc, 0)

    src_rect := src_rect
    src_rect.x /= src_size.x
    src_rect.y /= src_size.y
    src_rect.z /= src_size.x
    src_rect.w /= src_size.y

    uniform_set_vec4(_default_blitter_uniform.src_rect, src_rect)

    blit_draw_unit_quad(shader)
}
blit_ex :: proc(src, dst: TextureId, src_size : Vec2, src_rect, dst_rect : Vec4) {
    blit_pro(_blit_shader, _default_blitter_uniform.main_texture, src,dst, src_size, src_rect,dst_rect)
}
blit :: proc(src, dst: TextureId, w,h: i32) {// With default blit shader.
    w,h :f32= cast(f32)w, cast(f32)h
    blit_pro(_blit_shader, _default_blitter_uniform.main_texture, src,dst, {w,h}, {0,0,w,h},{0,0,w,h})
}
blit_make_blit_shader :: proc(fragment_source : string) -> ShaderId {
    return shader_load_from_sources(_BLITTER_VERT, fragment_source)
}

blit_draw_unit_quad :: #force_inline proc(shader: ShaderId) {
    if !_blit_is_initialized() do _blit_init()
    primitive_draw(&_blit_quad, shader)
}

blit_clear :: proc(texture: u32, color: Vec4, width, height: i32) {
    if !_blit_is_initialized() do _blit_init()
    rem_fbo := framebuffer_current(); defer framebuffer_bind(rem_fbo)
    rem_viewport := state_get_viewport(); defer state_set_viewport(rem_viewport)
    gl.Viewport(0,0,width,height)
    framebuffer_bind(_blit_fbo)
    framebuffer_attach_color(0, texture)
    gl.ClearColor(color.r, color.g, color.b, color.a)
    gl.Clear(gl.COLOR_BUFFER_BIT)
}

@(private="file")
_blit_is_initialized :: #force_inline proc() -> bool {
    return _blit_shader != 0
}
@(private="file")
_blit_init :: proc() {
    _blit_shader = blit_make_blit_shader(_BLITTER_FRAG)
    uniform_load(&_default_blitter_uniform, _blit_shader)
    // _SHADER_LOC_MAIN_TEXTURE = gl.GetUniformLocation(_blit_shader, "main_texture")
    _blit_quad = primitive_make_quad_a({1,1,1,1})
    _blit_fbo = framebuffer_create()
    append(&release_handler, proc() {
        gl.DeleteProgram(_blit_shader)
        primitive_delete(&_blit_quad)
        framebuffer_destroy(_blit_fbo)
    })
}

// Copy texture
texture_copy :: proc(from,to: TextureId, from_pos, to_pos: Vec2i, width,height: i32) {
    gl.CopyImageSubData(from, gl.TEXTURE_2D, 0, from_pos.x, from_pos.y, 0,
                        to,   gl.TEXTURE_2D, 0, to_pos.x, to_pos.y, 0,
                        width, height, 1)
}


@(private="file")
_BLITTER_VERT :string: `
#version 440 core

layout (location = 0) in vec3 position;
layout (location = 1) in vec4 color;
layout (location = 2) in vec2 uv;

layout(location = 0) out vec2 _uv;
layout(location = 1) out vec4 _color;

uniform vec4 src_rect;

void main()
{
    vec2 p = vec2(position.x, position.y);

    p = (p - vec2(src_rect.x, src_rect.y)) / vec2(src_rect.z, src_rect.w);
    
    p = p * 2 - 1;

    gl_Position = vec4(p.x, p.y, 0, 1.0);
	_uv = uv;
    _uv.y = 1 - _uv.y;
    _color = color;
}
`

@(private="file")
_BLITTER_FRAG :string: `
#version 440 core
out vec4 FragColor;

layout(location = 0) in vec2 _uv;
layout(location = 1) in vec4 _color;

uniform sampler2D main_texture;

void main() {
    vec4 c = texture(main_texture, _uv);
    FragColor = c;
}
`