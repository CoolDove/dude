package input

import dd "../"

Input :: dd.Input

KeyState :: dd.KeyState

KeyCode :: dd.KeyCode

MouseButtonState :: dd.MouseButtonState

MouseButton :: dd.MouseButton

// Indicates which input events has been received.
InputHandleResult :: dd.InputHandleResult

// ** Keyboard and mouse
get_key :: dd.get_key
get_key_down :: dd.get_key_down
get_key_repeat :: dd.get_key_repeat
get_key_up :: dd.get_key_up

get_mouse_button :: dd.get_mouse_button
get_mouse_button_down :: dd.get_mouse_button_down
get_mouse_button_up :: dd.get_mouse_button_up

get_mouse_position :: dd.get_mouse_position

get_mouse_motion :: dd.get_mouse_motion

get_mouse_wheel :: dd.get_mouse_wheel

get_key_state :: dd.get_key_state
get_mouse_button_state :: dd.get_mouse_button_state

get_input_handle_result :: dd.get_input_handle_result

// ** Text input

// Unavailable in event-driven mode.
get_textinput_charactors_temp :: dd.get_textinput_charactors_temp
// Unavailable in event-driven mode.
get_textinput_editting_text :: dd.get_textinput_editting_text

// Available in event-driven mode.
textinput_begin :: dd.textinput_begin
// Available in event-driven mode.
textinput_set_cursor_pos :: dd.textinput_set_cursor_pos
// Available in event-driven mode.
textinput_end :: dd.textinput_end
// Available in event-driven mode.
is_textinput_activating :: dd.is_textinput_activating


// ** Misc
get_mui_hovering :: dd.get_mui_hovering