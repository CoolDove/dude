package main

import "core:time"
import "core:log"
import "core:math"
import "core:math/linalg"
import "core:runtime"

// NOTE:
// Do not keep the ^Tween, it's not stable.
// TODO:
// Cancel token.

// tween setup
tween_init :: proc() {
    using runtime
    tweens = make([dynamic]Tween, 0, 16)

    union_type := type_info_of(TweenableValue).variant.(Type_Info_Named).base
    tweenable_types = union_type.variant.(Type_Info_Union).variants
}
tween_update :: proc() {
    for tween, ind in &tweens {
        if tween.done do continue
        interp :f32= cast(f32)time.duration_seconds(app.duration_total - tween.start_time) / tween.duration
        eased_value := tween.easing_proc(interp)
        value := tween_value(tween.begin_value, tween.end_value, eased_value)
        tween.data^ = value
        if interp > 1.0 {
            tween.data^ = tween.end_value
            tween.done = true
            if tween.on_complete != nil do tween.on_complete(tween.user_data)
            if cast(i32)ind < tween_reuse_ptr || tween_reuse_ptr < 0 {
                tween_reuse_ptr = cast(i32)ind
            }
        }
    }
}
tween_destroy :: proc() {
    delete(tweens)
}

// ## types
Tween :: struct {
    using vtable : ^Tween_VTable,

    data : ^TweenableValue,
    begin_value, end_value : TweenableValue,
    duration : f32,// in sec
    start_time : time.Duration,

    done : bool,

    easing_proc : EasingProc,

    on_complete : proc(user_data: rawptr),
    user_data : rawptr,
}

Tween_VTable :: struct {
    set_on_complete : type_of(_set_on_complete),
    set_easing : type_of(_set_easing),
}

// ## global vars
when ODIN_DEBUG {
    tweens : [dynamic]Tween
    tween_reuse_ptr : i32 = -1
} else {
    @(private="file")
    tweens : [dynamic]Tween
    @(private="file")
    tween_reuse_ptr : i32 = -1
}

// ## tween api

// Dont use this, not reliable.
tween_cancel :: proc(tween: ^Tween, call_on_complete:= false) {
    if tween.done do return;
    tween.done = true
    if call_on_complete && tween.on_complete != nil {
        tween.on_complete(tween.user_data)
    }
}

tween :: proc(value: ^$T, target : T, duration : f32) -> ^Tween {
    ptr_type := type_info_of(^T).variant.(runtime.Type_Info_Pointer).elem.id
    assert(tween_type_is_valid(ptr_type), 
        "Invalid tween invoke.")

    reuse := false
    if tween_reuse_ptr >= 0 {
        for i in tween_reuse_ptr..<cast(i32)len(tweens) {
            if tweens[i].done {
                tween_reuse_ptr = i
                reuse = true
                break
            }
        }
        if !reuse do tween_reuse_ptr = -1
    }

    if reuse {// Reuse dead tween object.
        tween : ^Tween = &tweens[tween_reuse_ptr]
        _init_tween(tween)

        tween.data = transmute(^TweenableValue)value
        tween.begin_value = value^
        tween.end_value = cast(TweenableValue)target
        tween.duration = duration

        tween_reuse_ptr += 1
        
        return tween
    } else {// Create new tween object.
        tween : Tween
        _init_tween(&tween)

        tween.data = transmute(^TweenableValue)value
        tween.begin_value = value^
        tween.end_value = cast(TweenableValue)target
        tween.duration = duration

        append(&tweens, tween)
        return &tweens[len(tweens) - 1]
    }
}

// ## vtable setup
@(private="file")
tween_vtable := Tween_VTable {
    _set_on_complete,
    _set_easing,
}
_set_on_complete :: proc(tween: ^Tween, callback: proc(use_data: rawptr), user_data: rawptr) -> ^Tween {
    tween.on_complete = callback
    tween.user_data = user_data
    return tween
}
_set_easing :: proc(tween: ^Tween, easing_proc : EasingProc) {
    tween.easing_proc = easing_proc
}

// ## easing proc
// Easing function reference: [https://easings.net](https://easings.net)
EasingProc :: proc(x : f32) -> f32

ease_linear :: proc(x : f32) -> f32 {
    return x
}

ease_insine :: proc(x : f32) -> f32 {
    return 1 - math.cos((x * math.PI) / 2);
}
ease_incubic :: proc(x : f32) -> f32 {
    return x * x * x
}
ease_inquint :: proc(x : f32) -> f32 {
    return x * x * x * x * x
}
ease_incirc :: proc(x : f32) -> f32 {
    return 1 - math.sqrt(1 - x * x);
}
ease_inelastic :: proc(x : f32) -> f32 {
    c4 :: (2 * math.PI) / 3;
    return x == 0 ? 0 : x == 1 ? 1 : -math.pow(2, 10 * x - 10) * math.sin((x * 10 - 10.75) * c4);
}

ease_outsine :: proc(x : f32) -> f32 {
    return math.sin((x * math.PI) / 2);
}
ease_outcubic :: proc(x : f32) -> f32 {
    return 1 - math.pow(1 - x, 3);
}
ease_outquint :: proc(x : f32) -> f32 {
    return 1 - math.pow(1 - x, 5);
}
ease_outcirc :: proc(x : f32) -> f32 {
    return math.sqrt(1 - math.pow(x - 1, 2));
}
ease_outelastic :: proc(x : f32) -> f32 {
    c4 :: (2 * math.PI) / 3;
    return x == 0 ? 0 : x == 1 ? 1 : math.pow(2, -10 * x) * math.sin((x * 10 - 0.75) * c4) + 1;
}

ease_inoutsine :: proc(x : f32) -> f32 {
    return -(math.cos(math.PI * x) - 1) / 2;
}
ease_inoutcubic :: proc(x : f32) -> f32 {
    return x < 0.5 ? 4 * x * x * x : 1 - math.pow(-2 * x + 2, 3) / 2;
}
ease_inoutquint :: proc(x : f32) -> f32 {
    return x < 0.5 ? 16 * x * x * x * x * x : 1 - math.pow(-2 * x + 2, 5) / 2;
}
ease_inoutcirc :: proc(x : f32) -> f32 {
    return x < 0.5 ? (1 - math.sqrt(1 - math.pow(2 * x, 2))) / 2 : (math.sqrt(1 - math.pow(-2 * x + 2, 2)) + 1) / 2;
}
ease_inoutelastic :: proc(x : f32) -> f32 {
    c5 :: (2 * math.PI) / 4.5;
    return x == 0 ? 0 : x == 1 ? 1 : x < 0.5 ? -(math.pow(2, 20 * x - 10) * math.sin((20 * x - 11.125) * c5)) / 2 : (math.pow(2, -20 * x + 10) * math.sin((20 * x - 11.125) * c5)) / 2 + 1;
}

ease_inquad :: proc(x : f32) -> f32 {
    return x * x
}
ease_inquart :: proc(x : f32) -> f32 {
    return x * x * x * x
}
ease_inexpo :: proc(x : f32) -> f32 {
    return x == 0 ? 0 : math.pow(2, 10 * x - 10);
}
ease_inback :: proc(x : f32) -> f32 {
    c1 :: 1.70158
    c3 :: c1 + 1
    return c3 * x * x * x - c1 * x * x
}
ease_inbounce :: proc(x: f32) -> f32 {
    return 1 - ease_outbounce(1 - x);
}

ease_outquad :: proc(x : f32) -> f32 {
    return 1 - (1 - x) * (1 - x);
}
ease_outquart :: proc(x : f32) -> f32 {
    return 1 - math.pow(1 - x, 4);
}
ease_outexpo :: proc(x : f32) -> f32 {
    return x == 1 ? 1 : 1 - math.pow(2, -10 * x);
}
ease_outback :: proc(x : f32) -> f32 {
    c1 :: 1.70158;
    c3 :: c1 + 1;
    return 1 + c3 * math.pow(x - 1, 3) + c1 * math.pow(x - 1, 2);
}
ease_outbounce :: proc(x: f32) -> f32 {
    n1 :: 7.5625;
    d1 :: 2.75;

    if (x < 1 / d1) {
        return n1 * x * x
    } else if (x < 2 / d1) {
        return n1 * (x - 1.5 / d1) * x + 0.75
    } else if (x < 2.5 / d1) {
        return n1 * (x - 2.25 / d1) * x + 0.9375
    } else {
        return n1 * (x - 2.625 / d1) * x + 0.984375
    }
}

ease_inoutquad :: proc(x : f32) -> f32 {
    return x < 0.5 ? 2 * x * x : 1 - math.pow(-2 * x + 2, 2) / 2;
}
ease_inoutquart :: proc(x : f32) -> f32 {
    return x < 0.5 ? 8 * x * x * x * x : 1 - math.pow(-2 * x + 2, 4) / 2;
}
ease_inoutexpo :: proc(x : f32) -> f32 {
    return x == 0 ? 0 : x == 1 ? 1 : x < 0.5 ? math.pow(2, 20 * x - 10) / 2 : (2 - math.pow(2, -20 * x + 10)) / 2;
}
ease_inoutback :: proc(x : f32) -> f32 {
    c1 :: 1.70158;
    c2 :: c1 * 1.525;
    return x < 0.5 ? (math.pow(2 * x, 2) * ((c2 + 1) * 2 * x - c2)) / 2 : (math.pow(2 * x - 2, 2) * ((c2 + 1) * (x * 2 - 2) + c2) + 2) / 2;
}
ease_inoutbounce :: proc(x: f32) -> f32 {
    return x < 0.5 ? (1 - ease_outbounce(1 - 2 * x)) / 2 : (1 + ease_outbounce(2 * x - 1)) / 2;
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
    tween.easing_proc = ease_linear
    tween.done = false
}