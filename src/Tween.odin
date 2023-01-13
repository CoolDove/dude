package main

import "core:time"
import "core:log"
import "core:math"


// NOTE:
// Do not keep the ^Tween, it's not stable.

// tween setup
tween_init :: proc() {
    tweens = make([dynamic]TweenF32, 0, 512)
}
tween_update :: proc() {
    for tween in &tweens {
        if tween.done do continue
        interp :f32= cast(f32)time.duration_seconds(app.duration_total - tween.start_time) / tween.duration
        value := tween.tweenproc(tween.begin_value, tween.end_value, interp)
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

// types

TweenProc :: proc(begin, end, interp : f32) -> f32

TweenF32 :: struct {
    using vtable : ^Tween_VTable,

    data : ^f32,
    begin_value, end_value : f32,
    duration : f32,// in sec
    start_time : time.Duration,

    done : bool,

    tweenproc : TweenProc,

    on_complete : proc(user_data: rawptr),
    user_data : rawptr,
}

Tween_VTable :: struct {
    set_on_complete : type_of(_set_on_complete),
}

tweens : [dynamic]TweenF32

// ## tween api
tween_cancel :: proc(tween: ^TweenF32, call_on_complete:= false) {
    if tween.done do return;
    tween.done = true
    if call_on_complete && tween.on_complete != nil {
        tween.on_complete(tween.user_data)
    }
}

tween_f32 :: proc(value: ^f32, target : f32, duration : f32) -> ^TweenF32 {
    tween : TweenF32
    tween.vtable = &tween_vtable

    tween.start_time = app.duration_total

    tween.data = value
    tween.begin_value = value^
    tween.end_value = target
    tween.duration = duration
    tween.tweenproc = tweenproc_linear

    append(&tweens, tween)
    return &tweens[len(tweens) - 1]
}

// ## vtable setup
@(private="file")
tween_vtable := Tween_VTable {
    _set_on_complete,
}
_set_on_complete :: proc(tween: ^TweenF32, callback: proc(use_data: rawptr), user_data: rawptr) -> ^TweenF32 {
    tween.on_complete = callback
    tween.user_data = user_data
    return tween
}

// ## easing proc
tweenproc_linear :: proc(begin, end, interp : f32) -> f32 {
    return (end - begin) * interp + begin
}

// ## internal proc
@(private="file")
tweens_clean_completed :: proc() {

}