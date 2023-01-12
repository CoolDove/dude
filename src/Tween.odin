package main

import "core:time"
import "core:log"
import "core:math"
import "core:math/linalg"
import "core:runtime"


// NOTE:
// Do not keep the ^Tween, it's not stable.

// tween setup
tween_init :: proc() {
    using runtime
    tweens = make([dynamic]Tween, 0, 512)

    union_type := type_info_of(TweenableValue).variant.(Type_Info_Named).base
    tweenable_types = union_type.variant.(Type_Info_Union).variants
}
tween_update :: proc() {
    for tween in &tweens {
        if tween.done do continue
        interp :f32= cast(f32)time.duration_seconds(app.duration_total - tween.start_time) / tween.duration
        eased_value := tween.easing_proc(0, 1, interp)
        value := tween_value(tween.begin_value, tween.end_value, eased_value)
        tween.data^ = value
        if interp > 1.0 {
            tween.data^ = tween.end_value
            tween.done = true
            if tween.on_complete != nil do tween.on_complete(tween.user_data)
        }
    }
}

tween_destroy :: proc() {
    delete(tweens)
}

// ## types
Tween :: struct {
    using vtable : ^Tween_VTable,
    value_type : typeid,

    data : ^TweenableValue,
    begin_value, end_value : TweenableValue,
    duration : f32,// in sec
    start_time : time.Duration,

    done : bool,

    easing_proc : proc(begin, end, interp : f32) -> f32,

    on_complete : proc(user_data: rawptr),
    user_data : rawptr,
}

Tween_VTable :: struct {
    set_on_complete : type_of(_set_on_complete),
}

when ODIN_DEBUG {
    @(private="file")
    tweens : [dynamic]Tween
} else {
    tweens : [dynamic]Tween
}

// ## tween api
tween_cancel :: proc(tween: ^Tween, call_on_complete:= false) {
    if tween.done do return;
    tween.done = true
    if call_on_complete && tween.on_complete != nil {
        tween.on_complete(tween.user_data)
    }
}

tween :: proc(value: ^$T, target : TweenableValue, duration : f32) -> ^Tween {
    value_ptr := type_info_of(^T).variant.(runtime.Type_Info_Pointer)
    if !tween_type_is_valid(value_ptr.elem.id) do return nil

    tween : Tween
    _init_tween(&tween)

    tween.data = transmute(^TweenableValue)value
    tween.begin_value = value^
    tween.end_value = target
    tween.duration = duration

    append(&tweens, tween)
    return &tweens[len(tweens) - 1]
}

// ## vtable setup
@(private="file")
tween_vtable := Tween_VTable {
    _set_on_complete,
}
_set_on_complete :: proc(tween: ^Tween, callback: proc(use_data: rawptr), user_data: rawptr) -> ^Tween {
    tween.on_complete = callback
    tween.user_data = user_data
    return tween
}

// ## easing proc
easing_proc_linear :: proc(begin, end, interp : f32) -> f32 {
    return (end - begin) * interp + begin
}

// ## tween implements
TweenableValue :: union #no_nil {
    f32, Vec2, Vec3, Vec4, linalg.Quaternionf32,
}

tweenable_types : []^runtime.Type_Info


tween_value :: proc(begin, end: TweenableValue, interp: f32) -> TweenableValue {
    using linalg
    switch in begin {
    case f32:
        return _tween_impl_f32(begin.(f32), end.(f32), interp)
    case Vec2:
        return _tween_impl_vec2(begin.(Vec2), end.(Vec2), interp)
    case Vec3:
        return _tween_impl_vec3(begin.(Vec3), end.(Vec3), interp)
    case Vec4:
        return _tween_impl_vec4(begin.(Vec4), end.(Vec4), interp)
    case Quaternionf32:
        return _tween_impl_quaternionf32(begin.(linalg.Quaternionf32), end.(linalg.Quaternionf32), interp)
    }
    return 0.0
}

tween_type_is_valid :: proc(T: typeid) -> bool {
    for t in tweenable_types {
        if T == t.id do return true
    }
    return false
}

@(private="file")
_tween_impl_f32 :: proc(begin, end: f32, interp: f32) -> f32 {
    return (end - begin) * interp + begin
}
@(private="file")
_tween_impl_vec2 :: proc(begin, end: Vec2, interp: f32) -> Vec2 {
    return (end - begin) * interp + begin
}
@(private="file")
_tween_impl_vec3 :: proc(begin, end: Vec3, interp: f32) -> Vec3 {
    return (end - begin) * interp + begin
}
@(private="file")
_tween_impl_vec4 :: proc(begin, end: Vec4, interp: f32) -> Vec4 {
    return (end - begin) * interp + begin
}
@(private="file")
_tween_impl_quaternionf32 :: proc(begin, end: linalg.Quaternionf32, interp: f32) -> linalg.Quaternionf32 {
    return linalg.quaternion_slerp_f32(begin, end, interp)
}
@(private="file")
_init_tween :: proc(tween: ^Tween) {
    tween.vtable = &tween_vtable
    tween.start_time = app.duration_total
    tween.easing_proc = easing_proc_linear
}


// ## internal proc
@(private="file")
tweens_clean_completed :: proc() {
    // ...
}