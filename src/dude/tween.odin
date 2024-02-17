package dude

import "core:time"
import "core:log"
import "core:math"
import "core:math/linalg"
import "core:runtime"

// NOTE:
// Do not keep the ^Tween, it's not stable.
// TODO:
//  Cancel token or immediately complete with a TweenHandle design.
// Exp:
// handle := tween(&value, 1.0, 0.5).get_handle()
// // Some place in the code.
// handle->cancel()
// handle->complete()
// @(private="file")
// _tween_system_total_time : time.Duration


Tweener :: struct {
    tweens : [dynamic]Tween,
    dead : [dynamic]int,
    available_id : int,
}

// TweenRef :: struct {
//     tweener : ^Tweener,
//     index, id : int,
// }

// tween setup
tween_system_init :: proc() {
    using runtime
    union_type := type_info_of(TweenableValue).variant.(Type_Info_Named).base
    tweenable_types = union_type.variant.(Type_Info_Union).variants
}

tweener_update :: proc(tweener: ^Tweener, delta: f32/*in seconds*/) {
    for &tween, idx in tweener.tweens {
        if tween.id <= 0 do continue
        tween.time += delta
        interp := tween.time/tween.duration
        if interp >= 1.0 {
            tween_set_data(tween.data, tween.end_value)
            if tween.on_complete != nil do tween.on_complete(tween.user_data)
            append(&tweener.dead, idx)
            tween.id = 0// Mark it as dead
        } else {
            assert(tween.easing_proc != nil, "Tween: easeing_proc missing.")
            eased_value := tween.easing_proc(interp)
            value := tween_value(tween.begin_value, tween.end_value, eased_value)
            tween_set_data(tween.data, value)
        }
    }
}

tweener_init :: proc(tweener: ^Tweener, reserve: int, allocator:= context.allocator) {
    context.allocator = allocator
    tweener.tweens = make_dynamic_array_len_cap([dynamic]Tween, 0, reserve)
    tweener.dead = make_dynamic_array_len_cap([dynamic]int, 0, reserve)
}
tweener_release :: proc(tweener: ^Tweener) {
    delete(tweener.tweens)
    delete(tweener.dead)
    tweener^ = {}
}
tweener_reset :: proc(tweener: ^Tweener) {
    clear(&tweener.tweens)
    clear(&tweener.dead)
    tweener.available_id = 0
}
tweener_count :: proc(tweener: ^Tweener) -> int {
    return len(tweener.tweens) - len(tweener.dead)
}

// ## types
Tween :: struct {
    id : int,

    using vtable : ^Tween_VTable,

    data : rawptr,
    begin_value, end_value : TweenableValue,
    duration : f32,// in sec
    time : f32,// Accumulation

    easing_proc : EasingProc,

    on_complete : proc(user_data: rawptr),
    user_data : rawptr,
}

Tween_VTable :: struct {
    set_on_complete : type_of(_set_on_complete),
    set_easing : type_of(_set_easing),
    // reference : type_of(_reference),
}

tween :: proc(tweener: ^Tweener, value: ^$T, target : T, duration : f32) -> ^Tween {
    ptr_type := type_info_of(^T).variant.(runtime.Type_Info_Pointer).elem.id
    assert(tween_type_is_valid(ptr_type), 
        "Invalid tween invoke.")

    tween :^Tween
    if len(tweener.dead) > 0 {
        reuse_idx := pop(&tweener.dead)
        tween = &tweener.tweens[reuse_idx]
    } else {
        append(&tweener.tweens, Tween{})
        tween = &tweener.tweens[len(tweener.tweens)-1]
    }
    
    tweener.available_id += 1
    tween.id = tweener.available_id

    tween.easing_proc = ease_linear
    tween.vtable = &_tween_vtable
    tween.data = transmute(^TweenableValue)value
    tween.begin_value = value^
    tween.end_value = cast(TweenableValue)target
    tween.duration = duration
    tween.time = 0
    return tween
}

// ## vtable setup
@(private="file")
_tween_vtable := Tween_VTable {
    _set_on_complete,
    _set_easing,
    // _reference,
}

@(private="file")
_set_on_complete :: proc(tween: ^Tween, callback: proc(use_data: rawptr), user_data: rawptr=nil) -> ^Tween {
    tween.on_complete = callback
    tween.user_data = user_data
    return tween
}
@(private="file")
_set_easing :: proc(tween: ^Tween, easing_proc : EasingProc) {
    tween.easing_proc = easing_proc
}
// @(private="file")
// _reference :: proc(tween: ^Tween) -> TweenRef {
//     assert(false, "Not implemented.")
//     return {}
// }

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
    f32, linalg.Vector2f32, linalg.Vector3f32, linalg.Vector4f32, linalg.Quaternionf32,
}

tweenable_types : []^runtime.Type_Info

tween_value :: proc(begin, end: TweenableValue, interp: f32) -> TweenableValue {
    using linalg
    switch _ in begin {
    case f32:
        return _tween_impl_f32(begin.(f32), end.(f32), interp)
    case Vector2f32:
        return _tween_impl_vec2(begin.(Vector2f32), end.(Vector2f32), interp)
    case Vector3f32:
        return _tween_impl_vec3(begin.(Vector3f32), end.(Vector3f32), interp)
    case Vector4f32:
        return _tween_impl_vec4(begin.(Vector4f32), end.(Vector4f32), interp)
    case Quaternionf32:
        return _tween_impl_quaternionf32(begin.(linalg.Quaternionf32), end.(linalg.Quaternionf32), interp)
    }
    return 0.0
}
tween_set_data :: proc(ptr: rawptr, value: TweenableValue) {
    using linalg
    switch i in value {
    case f32:
        data := transmute(^f32)ptr
        data^ = value.(f32)
    case Vector2f32:
        data := transmute(^Vector2f32)ptr
        data^ = value.(Vector2f32)
    case Vector3f32:
        data := transmute(^Vector3f32)ptr
        data^ = value.(Vector3f32)
    case Vector4f32:
        data := transmute(^Vector4f32)ptr
        data^ = value.(Vector4f32)
    case Quaternionf32:
        data := transmute(^Quaternionf32)ptr
        data^ = value.(Quaternionf32)
    }
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
_tween_impl_vec2 :: proc(begin, end: linalg.Vector2f32, interp: f32) -> linalg.Vector2f32 {
    return (end - begin) * interp + begin
}
@(private="file")
_tween_impl_vec3 :: proc(begin, end: linalg.Vector3f32, interp: f32) -> linalg.Vector3f32 {
    return (end - begin) * interp + begin
}
@(private="file")
_tween_impl_vec4 :: proc(begin, end: linalg.Vector4f32, interp: f32) -> linalg.Vector4f32 {
    return (end - begin) * interp + begin
}
@(private="file")
_tween_impl_quaternionf32 :: proc(begin, end: linalg.Quaternionf32, interp: f32) -> linalg.Quaternionf32 {
    return linalg.quaternion_slerp_f32(begin, end, interp)
}
