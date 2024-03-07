package dude

import "core:time"
import "core:log"
import "core:math"
import "core:math/linalg"
import "core:runtime"

import "core:mem"
import "core:fmt"

import hla "collections/hollow_array"

// NOTE:
// Do not keep the ^Tween, it's not stable.
// TODO:
//  Cancel token or immediately complete with a TweenHandle.
// Exp:
// handle := tween(&value, 1.0, 0.5).get_handle()
// // Some place in the code.
// handle->cancel()
// handle->complete()
// @(private="file")
// _tween_system_total_time : time.Duration


Tweener :: struct {
    tweens : hla.HollowArray(Tween),
}

tweener_update :: proc(tweener: ^Tweener, delta: f32/*in seconds*/) {
    using hla
    iterator : HollowArrayIterator
    for twn in hla_ite(&tweener.tweens, &iterator) {
        twn.time += delta
        interp := twn.time/twn.duration
        if interp >= 1.0 {
            _tween_set_data(twn, twn.end_value)
            if twn.on_complete != nil do twn.on_complete(twn.user_data)
            hla_remove_index(&tweener.tweens, iterator.buffer_idx)
        } else {
            assert(twn.easing_proc != nil, "Tween: easeing_proc missing.")
            assert(twn.impl != nil && twn.impl.interp != nil, "Tween: impl missing or broken.")
            eased_interp := twn.easing_proc(interp)
            _tween_set_data(twn, twn.impl.interp(twn, eased_interp))
        }
    }
}

tweener_init :: proc(tweener: ^Tweener, reserve: int, allocator:= context.allocator) {
    context.allocator = allocator
    tweener.tweens = hla.hla_make(Tween, 16)
}
tweener_release :: proc(tweener: ^Tweener) {
    hla.hla_delete(&tweener.tweens)
    tweener^ = {}
}
tweener_reset :: proc(tweener: ^Tweener) {
    hla.hla_clear(&tweener.tweens)
}

tweener_count :: proc(tweener: ^Tweener) -> int {
    return tweener.tweens.count
}

// ## types
Tween :: struct {
    data : rawptr,
    begin_value, end_value : TweenableValue,
    duration : f32,// in sec
    time : f32,// Accumulation

    dimension : i32, // How many floats to tween, calculated by the type.
    impl : ^TweenImplementation,
    easing_proc : EasingProc,
    on_complete : proc(user_data: rawptr),
    user_data : rawptr,
}

// tween :: proc(tweener: ^Tweener, value: ^$T, target : T, duration : f32, easing_proc := ease_linear) -> ^Tween {
//     ptr_type := type_info_of(^T).variant.(runtime.Type_Info_Pointer).elem.id
//     dimen := size_of(T)/size_of(f32)
//     assert(size_of(T)%size_of(f32) == 0, "This type is unable to tween.")
//     assert(dimen > 0 && dimen < 5, "This type is unable to tween.")

//     using hla
//     tween :^Tween= hla_get_pointer(hla_append(&tweener.tweens, Tween{}))

//     tween.dimension = cast(i32)dimen
//     tween.impl = &_impl_default

//     tween.easing_proc = easing_proc
//     tween.data = cast(rawptr)value

//     mem.copy(&tween.begin_value, value, size_of(T))
//     target := target
//     mem.copy(&tween.end_value, &target, size_of(T))

//     tween.duration = duration
//     tween.time = 0

//     return tween
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

// ** tween implements
TweenableValue :: struct #raw_union {
    v1 : f32,
    v2 : linalg.Vector2f32,
    v3 : linalg.Vector3f32,
    v4 : linalg.Vector4f32,
}

TweenImplementation :: struct {
    interp : proc(tween: ^Tween, interp: f32) -> TweenableValue,
}

@(private="file")
_impl_default :TweenImplementation= {
    _impl_interp_default,
}

@(private="file")
_impl_interp_default :: proc(using tween: ^Tween, interp: f32) -> TweenableValue {
    switch dimension {
    case 1:
        return {v1=(end_value.v1 - begin_value.v1) * interp + begin_value.v1}
    case 2:
        return {v2=(end_value.v2 - begin_value.v2) * interp + begin_value.v2}
    case 3:
        return {v3=(end_value.v3 - begin_value.v3) * interp + begin_value.v3}
    case 4:
        return {v4=(end_value.v4 - begin_value.v4) * interp + begin_value.v4}
    case:
        assert(false, "Invalid tween object.")
        return {}
    }
}

@(private="file")
_tween_set_data :: #force_inline proc(tween: ^Tween, value: TweenableValue) {
    value := value
    mem.copy(tween.data, &value, cast(int)tween.dimension * size_of(f32))
}