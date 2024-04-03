package dude

import "core:unicode/utf8"
import "core:fmt"
import "core:log"
import "core:slice"
import mui "microui"
import "./dgl"


muictx : MuiContext

MuiContext :: struct {
    mu : mui.Context,
    atlas_texture : u32,
}

@private
mui_init :: proc() {
    mui.init(&muictx.mu)
    w, h := mui.DEFAULT_ATLAS_WIDTH, mui.DEFAULT_ATLAS_HEIGHT
    atlas_pixels := make_slice([]u8, w*h)
    defer delete(atlas_pixels)
    for i in 0..<w*h {
        atlas_pixels[i] = mui.default_atlas_alpha[i]
    }
    muictx.atlas_texture = dgl.texture_create_with_buffer(mui.DEFAULT_ATLAS_WIDTH, mui.DEFAULT_ATLAS_HEIGHT, atlas_pixels, .Red)
	
	muictx.mu.text_width = mui.default_atlas_text_width
	muictx.mu.text_height = mui.default_atlas_text_height

    style := muictx.mu._style
    style.colors[.WINDOW_BG] = {56, 58, 59, 200}
    style.colors[.TITLE_BG] = {34, 37, 35, 255}
    style.colors[.BORDER] = {}
    
    muictx.mu._style = style
}

@private
mui_update :: proc() {
    ctx := &muictx.mu
    mouse_pos := vec_f2i(get_mouse_position())
    mui.input_mouse_move(ctx, mouse_pos.x, mouse_pos.y)
    mui.input_scroll(ctx, cast(i32)get_mouse_wheel().x, cast(i32)get_mouse_wheel().y)

    // FIXME: Write a better text input for mui. This one is too bad.
    for k in KeyCode.A..<KeyCode.Z {
        if get_key_repeat(k) {
            A, a :i32: cast(i32)'A', cast(i32)'a'
            cap :i32= A-a if get_key(.LSHIFT) || get_key(.RSHIFT) else 0
            mui.input_text_byte(ctx, cast(u8)(cast(i32)(k-KeyCode.A) + cast(i32)a + cap))
        }
    }

    // mouse buttons
    @static buttons_to_key := [?]struct{ dude_btn: MouseButton, mu_btn: mui.Mouse} {
        {.Left, .LEFT},
        {.Right, .RIGHT},
        {.Middle, .MIDDLE},
    }

    for button in buttons_to_key {
        if get_mouse_button_down(button.dude_btn) { 
            mui.input_mouse_down(ctx, mouse_pos.x, mouse_pos.y, button.mu_btn)
        } else if get_mouse_button_up(button.dude_btn) { 
            mui.input_mouse_up(ctx, mouse_pos.x, mouse_pos.y, button.mu_btn)
        }
    }
		
		// keyboard
    @static keys_to_check := [?]struct{
        dude_key: KeyCode,
        mu_key: mui.Key,
    }{
        {.LSHIFT,    .SHIFT},
        {.RSHIFT,    .SHIFT},
        {.LCTRL,     .CTRL},
        {.RCTRL,     .CTRL},
        {.LALT,      .ALT},
        {.RALT,      .ALT},
        {.RETURN,    .RETURN},
        {.KP_ENTER,  .RETURN},
        {.BACKSPACE, .BACKSPACE},
    }
    for key in keys_to_check {
        if get_key_repeat(key.dude_key) {
            mui.input_key_down(ctx, key.mu_key)
        } else if get_key_up(key.dude_key) {
            mui.input_key_up(ctx, key.mu_key)
        }
    }
}

@private
mui_render :: proc(pass: ^RenderPass) {
    ctx := &muictx.mu
    draw_atlas_rect :: proc(pass: ^RenderPass, rect: mui.Rect, pos: Vec2, color: Color32) {
        rectf := Vec4{auto_cast rect.x, auto_cast rect.y, auto_cast rect.w, auto_cast rect.h}
        atlas_size := Vec2{mui.DEFAULT_ATLAS_WIDTH, mui.DEFAULT_ATLAS_HEIGHT}
        uv_from := Vec2{rectf.x,rectf.y}/atlas_size
        uv_to := uv_from+Vec2{rectf.z, rectf.w}/atlas_size
        immediate_screen_textquad(pass, pos, {rectf.z, rectf.w}, color=color,
            texture=muictx.atlas_texture,
            uv_min = uv_from, uv_max= uv_to)
    }
	
	command_backing: ^mui.Command
	for variant in mui.next_command_iterator(ctx, &command_backing) {
		switch cmd in variant {
		case ^mui.Command_Text:
			pos := vec_i2f(Vec2i{cmd.pos.x, cmd.pos.y})
			for ch in cmd.str do if ch&0xc0 != 0x80 {
				r := min(int(ch), 127)
				rect := mui.default_atlas[mui.DEFAULT_ATLAS_FONT + r]
                draw_atlas_rect(pass, rect, pos, transmute(Color32)cmd.color)
				pos.x += cast(f32)rect.w
			}
		case ^mui.Command_Rect:
            pos := vec_i2f(Vec2i{cmd.rect.x, cmd.rect.y})
            size := vec_i2f(Vec2i{cmd.rect.w, cmd.rect.h})
            texture := cmd.texture
            immediate_screen_quad(pass, pos, size, transmute(Color32)cmd.color, texture)
		case ^mui.Command_Icon:
			rect := mui.default_atlas[cmd.id]
			x := cmd.rect.x + (cmd.rect.w - rect.w)/2
			y := cmd.rect.y + (cmd.rect.h - rect.h)/2
			draw_atlas_rect(pass, rect, vec_i2f(Vec2i{x, y}), transmute(Color32)cmd.color)
		case ^mui.Command_Clip:
            immediate_set_scissor(pass, transmute(Vec4i)cmd.rect, true)
		case ^mui.Command_Jump: 
			unreachable()
		}
	}
}

@private
mui_release :: proc() {
    dgl.texture_delete(&muictx.atlas_texture)
}

muix :struct {
    image : proc(ctx: ^mui.Context, texture: u32, color: Color32),
}: {
    image = _muic_image,
}

// ** Custom controls
@(private="file")
_muic_image :: proc(ctx: ^mui.Context, texture: u32, color: Color32) {
    rect := mui.layout_next(ctx);
    mui.draw_rect(ctx, rect, transmute(mui.Color)color, texture)
}