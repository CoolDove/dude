package imgui_impl_sdl;

import "core:runtime";
import "core:fmt";
import "core:log";

import sdl "vendor:sdl2";

import imgui "../..";

SDL_State :: struct {
    window : ^sdl.Window,
    time: u64,
    cursor_handles: [imgui.Mouse_Cursor.Count]^sdl.Cursor,
}


PlatformData :: struct {
    window : ^sdl.Window,
    renderer : ^sdl.Renderer,
}

init :: proc(state: ^SDL_State, window: ^sdl.Window)  {
    io := imgui.get_io()
    assert(io.backend_platform_user_data == nil, "Already initialized a platform backend for imgui!")

    io.backend_flags |= .HasGamepad 
    io.backend_flags |= .HasMouseCursors 
    io.backend_flags |= .HasSetMousePos

    io.backend_platform_name = "SDL2"
    io.backend_platform_user_data = state

    imgui_viewport := imgui.get_main_viewport()
    imgui_viewport.platform_handle = window
    sdl.GetWindowWMInfo(window, &raw_info)
    imgui_viewport.platform_handle_raw = &raw_info

    setup_state(state)
    state.window = window

    io.backend_platform_user_data = state
}

raw_info : sdl.SysWMinfo

new_frame :: proc() {
    io := imgui.get_io()
    state := cast(^SDL_State)io.backend_platform_user_data
    using state
    // update display size
    w, h, display_h, display_w: i32;
    sdl.GetWindowSize(window, &w, &h);
    if sdl.GetWindowFlags(window) & u32(sdl.WindowFlag.MINIMIZED) != 0 {
        w = 0;
        h = 0;
    }
    sdl.GL_GetDrawableSize(window, &display_w, &display_h);

    io.display_size = imgui.Vec2{f32(display_w), f32(display_h)};

    if w > 0 && h > 0 {
        io.display_framebuffer_scale = imgui.Vec2{f32(display_w / w), f32(display_h / h)};
    }
    //
    update_mouse(state, window)
    update_dt(state)
}

setup_state :: proc(using state: ^SDL_State) {
    io := imgui.get_io();
    io.backend_platform_name = "SDL";
    io.backend_flags |= .HasMouseCursors;

    io.key_map[imgui.Key.Tab]         = i32(sdl.Scancode.TAB);
    io.key_map[imgui.Key.LeftArrow]   = i32(sdl.Scancode.LEFT);
    io.key_map[imgui.Key.RightArrow]  = i32(sdl.Scancode.RIGHT);
    io.key_map[imgui.Key.UpArrow]     = i32(sdl.Scancode.UP);
    io.key_map[imgui.Key.DownArrow]   = i32(sdl.Scancode.DOWN);
    io.key_map[imgui.Key.PageUp]      = i32(sdl.Scancode.PAGEUP);
    io.key_map[imgui.Key.PageDown]    = i32(sdl.Scancode.PAGEDOWN);
    io.key_map[imgui.Key.Home]        = i32(sdl.Scancode.HOME);
    io.key_map[imgui.Key.End]         = i32(sdl.Scancode.END);
    io.key_map[imgui.Key.Insert]      = i32(sdl.Scancode.INSERT);
    io.key_map[imgui.Key.Delete]      = i32(sdl.Scancode.DELETE);
    io.key_map[imgui.Key.Backspace]   = i32(sdl.Scancode.BACKSPACE);
    io.key_map[imgui.Key.Space]       = i32(sdl.Scancode.SPACE);
    io.key_map[imgui.Key.Enter]       = i32(sdl.Scancode.RETURN);
    io.key_map[imgui.Key.Escape]      = i32(sdl.Scancode.ESCAPE);
    io.key_map[imgui.Key.KeyPadEnter] = i32(sdl.Scancode.KP_ENTER);
    io.key_map[imgui.Key.A]           = i32(sdl.Scancode.A);
    io.key_map[imgui.Key.C]           = i32(sdl.Scancode.C);
    io.key_map[imgui.Key.V]           = i32(sdl.Scancode.V);
    io.key_map[imgui.Key.X]           = i32(sdl.Scancode.X);
    io.key_map[imgui.Key.Y]           = i32(sdl.Scancode.Y);
    io.key_map[imgui.Key.Z]           = i32(sdl.Scancode.Z);

    io.get_clipboard_text_fn = get_clipboard_text;
    io.set_clipboard_text_fn = set_clipboard_text;
    
    cursor_handles[imgui.Mouse_Cursor.Arrow]      = sdl.CreateSystemCursor(sdl.SystemCursor.ARROW);
    cursor_handles[imgui.Mouse_Cursor.TextInput]  = sdl.CreateSystemCursor(sdl.SystemCursor.IBEAM);
    cursor_handles[imgui.Mouse_Cursor.ResizeAll]  = sdl.CreateSystemCursor(sdl.SystemCursor.SIZEALL);
    cursor_handles[imgui.Mouse_Cursor.ResizeNs]   = sdl.CreateSystemCursor(sdl.SystemCursor.SIZENS);
    cursor_handles[imgui.Mouse_Cursor.ResizeEw]   = sdl.CreateSystemCursor(sdl.SystemCursor.SIZEWE);
    cursor_handles[imgui.Mouse_Cursor.ResizeNesw] = sdl.CreateSystemCursor(sdl.SystemCursor.SIZENESW);
    cursor_handles[imgui.Mouse_Cursor.ResizeNwse] = sdl.CreateSystemCursor(sdl.SystemCursor.SIZENWSE);
    cursor_handles[imgui.Mouse_Cursor.Hand]       = sdl.CreateSystemCursor(sdl.SystemCursor.HAND);
    cursor_handles[imgui.Mouse_Cursor.NotAllowed] = sdl.CreateSystemCursor(sdl.SystemCursor.NO);
} 

process_event :: proc(e: sdl.Event, state: ^SDL_State) {
    io := imgui.get_io();
    #partial switch e.type {
        case .MOUSEWHEEL: {
            if e.wheel.x > 0 do io.mouse_wheel_h += 1;
            if e.wheel.x < 0 do io.mouse_wheel_h -= 1;
            if e.wheel.y > 0 do io.mouse_wheel   += 1;
            if e.wheel.y < 0 do io.mouse_wheel   -= 1;
        }

        case .TEXTINPUT: {
            text := e.text;
            imgui.ImGuiIO_AddInputCharactersUTF8(io, cstring(&text.text[0]));
        }
        case .KEYDOWN, .KEYUP: {
            sc := e.key.keysym.scancode;
            io.keys_down[sc] = e.type == .KEYDOWN;
            io.key_shift = sdl.GetModState() & (sdl.KMOD_LSHIFT|sdl.KMOD_RSHIFT) != nil;
            io.key_ctrl  = sdl.GetModState() & (sdl.KMOD_LCTRL|sdl.KMOD_RCTRL)   != nil;
            io.key_alt   = sdl.GetModState() & (sdl.KMOD_LALT|sdl.KMOD_RALT)     != nil;

            when ODIN_OS == .Windows {
                io.key_super = false;
            } else {
                io.key_super = sdl.GetModState()() & (sdl.KMOD_LGUI|sdl.KMOD_RGUI) != nil;
            }
        }
    }
}

update_dt :: proc(state: ^SDL_State) {
    io := imgui.get_io();
    freq := sdl.GetPerformanceFrequency();
    curr_time := sdl.GetPerformanceCounter();
    io.delta_time = state.time > 0 ? f32(f64(curr_time - state.time) / f64(freq)) : f32(1/60);
    state.time = curr_time;
}

update_mouse :: proc(state: ^SDL_State, window: ^sdl.Window) {
    io := imgui.get_io();
    mx, my: i32;
    buttons := sdl.GetMouseState(&mx, &my);
    io.mouse_down[0] = (buttons & u32(sdl.BUTTON_LMASK) != 0)
    io.mouse_down[1] = (buttons & u32(sdl.BUTTON_RMASK) != 0)
    io.mouse_down[2] = (buttons & u32(sdl.BUTTON_MMASK) != 0)
    io.mouse_down[3] = (buttons & u32(sdl.BUTTON_X1MASK) != 0)
    io.mouse_down[4] = (buttons & u32(sdl.BUTTON_X2MASK) != 0)

    // Set mouse pos if window is focused
    io.mouse_pos = imgui.Vec2{min(f32), min(f32)};
    if sdl.GetKeyboardFocus() == window {
        io.mouse_pos = imgui.Vec2{f32(mx), f32(my)};
    }

    if io.config_flags & .NoMouseCursorChange != .NoMouseCursorChange {
        desired_cursor := imgui.get_mouse_cursor();
        if(io.mouse_draw_cursor || desired_cursor == .None) {
            sdl.ShowCursor(sdl.DISABLE);
        } else {
            chosen_cursor := state.cursor_handles[imgui.Mouse_Cursor.Arrow];
            if state.cursor_handles[desired_cursor] != nil {
                chosen_cursor = state.cursor_handles[desired_cursor];
            }
            sdl.SetCursor(chosen_cursor);
            sdl.ShowCursor(sdl.ENABLE);
        }
    }
}

set_clipboard_text :: proc "c"(user_data : rawptr, text : cstring) {
    context = runtime.default_context();
    sdl.SetClipboardText(text);
}

get_clipboard_text :: proc "c"(user_data : rawptr) -> cstring {
    context = runtime.default_context();
    @static text_ptr: cstring;
    if text_ptr != nil {
        sdl.free(cast(^byte)text_ptr);
    }
    text_ptr = sdl.GetClipboardText();

    return text_ptr;
}