package dude


import "core:c"
import "core:fmt"
import "core:log"
import "core:strings"
import sdl "vendor:sdl2"

Input :: struct {
    keys : [sdl.NUM_SCANCODES]KeyState,
    mouse_buttons : [NUM_MOUSE_BUTTONS]MouseButtonState,
    mouse_position, mouse_position_prev, mouse_motion : Vec2,
    mouse_wheel : Vec2,
    strbuffer : strings.Builder,
}

KeyState :: struct {
    pressed, pressed_prev, repeat : bool,
}

KeyCode :: distinct sdl.Scancode // c.int

MouseButtonState :: struct {
    pressed, pressed_prev : bool,
    clicks : u8,
}
MouseButton :: enum u8 {
    Left = 1, 
    Right = 3,
    Middle = 2,
    Ext1 = 4,
    Ext2 = 5,
}

@(private="file")
NUM_MOUSE_BUTTONS :: 6

@(private="file")
input : Input

get_key :: proc(key: KeyCode) -> bool {
    state := get_key_state(key)
    return state.pressed
}
get_key_down :: proc(key: KeyCode) -> bool {
    state := get_key_state(key)
    return state.pressed && !state.pressed_prev
}
get_key_repeat :: proc(key: KeyCode) -> bool {
    state := get_key_state(key)
    return state.repeat || (state.pressed && !state.pressed_prev)
}
get_key_up :: proc(key: KeyCode) -> bool {
    state := get_key_state(key)
    return !state.pressed && state.pressed_prev
}

get_mouse_button :: proc(button: MouseButton) -> bool {
    state := get_mouse_button_state(button)
    return state.pressed
}
get_mouse_button_down :: proc(button: MouseButton) -> bool {
    state := get_mouse_button_state(button)
    return state.pressed && !state.pressed_prev
}
get_mouse_button_up :: proc(button: MouseButton) -> bool {
    state := get_mouse_button_state(button)
    return !state.pressed && state.pressed_prev
}

get_mouse_position :: proc() -> Vec2 {
    return input.mouse_position
}

get_mouse_motion :: proc() -> Vec2 {
    return input.mouse_motion
}

get_mouse_wheel :: proc() -> Vec2 {
    return input.mouse_wheel
}

get_key_state :: proc(key : KeyCode) -> KeyState {
    return get_key_state_ptr(key)^
}
get_mouse_button_state :: proc(button : MouseButton) -> MouseButtonState {
    return get_mouse_button_state_ptr(button)^
}

@(private="file")
get_key_state_ptr :: proc(key : KeyCode) -> ^KeyState {
    scancode :c.int= cast(c.int)key
    when ODIN_DEBUG do assert(scancode < sdl.NUM_SCANCODES, fmt.tprintf( "Error in Input: Invalid keycode: {}", scancode))
    return &input.keys[scancode]
}

@(private="file")
get_mouse_button_state_ptr :: proc(button : MouseButton) -> ^MouseButtonState {
    code :c.int= cast(c.int)button
    when ODIN_DEBUG do assert(code < NUM_MOUSE_BUTTONS, fmt.tprintf( "Error in Input: Invalid mouse button code: {}", code))
    return &input.mouse_buttons[code]
}

@private
input_init :: proc() {
    strings.builder_init(&input.strbuffer)
}
@private
input_release :: proc() {
    strings.builder_destroy(&input.strbuffer)
}

input_after_update_sdl2 :: proc() {
    for state in &input.keys {
        if state.pressed_prev != state.pressed do state.pressed_prev = state.pressed
        state.repeat = false
    }
    for state in &input.mouse_buttons {
        if state.pressed_prev != state.pressed do state.pressed_prev = state.pressed
    }
    input.mouse_wheel = {}
    input.mouse_motion = input.mouse_position - input.mouse_position_prev
    input.mouse_position_prev = input.mouse_position
}

input_handle_sdl2 :: proc(event: sdl.Event) {
    #partial switch event.type {
    case sdl.EventType.KEYDOWN:
        key := event.key
        key_state := get_key_state_ptr(cast(KeyCode)key.keysym.scancode)
        key_state.pressed = true
        key_state.repeat = key.repeat > 0
    case sdl.EventType.KEYUP:
        key := event.key
        key_state := get_key_state_ptr(cast(KeyCode)key.keysym.scancode)
        key_state.pressed = false

    case sdl.EventType.MOUSEBUTTONDOWN:
        button := event.button
        state := get_mouse_button_state_ptr(cast(MouseButton)button.button)
        state.pressed = true
        state.clicks = button.clicks
    case sdl.EventType.MOUSEBUTTONUP:
        button := event.button
        state := get_mouse_button_state_ptr(cast(MouseButton)button.button)
        state.pressed = false
        state.clicks = 0
    case sdl.EventType.MOUSEMOTION:
        @static init := true
        input.mouse_position = {cast(f32)event.motion.x, cast(f32)event.motion.y}
        if init {
            input.mouse_position_prev = input.mouse_position
            init = false
        }
    case sdl.EventType.MOUSEWHEEL:
        input.mouse_wheel = vec_i2f(Vec2i{event.wheel.x, event.wheel.y})
    }
}