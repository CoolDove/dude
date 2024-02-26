package dude

import "core:math/linalg"
import "core:mem"
import "core:slice"
import "core:math"
import "core:log"
import "core:time"
import "core:fmt"
import "core:reflect"
import "core:runtime"
import "core:strings"

StatePhase :: enum {
    Enter, Update, Exit,
}

vec_i2f :: proc {
    vec_i2f_2,
    vec_i2f_3,
    vec_i2f_4,
}
vec_f2i :: proc {
    vec_f2i_2,
    vec_f2i_3,
    vec_f2i_4,
}

vec_i2f_2 :: #force_inline proc "contextless" (input: Vec2i) -> Vec2 {
    return { cast(f32)input.x, cast(f32)input.y }
}
vec_i2f_3 :: #force_inline proc "contextless" (input: Vec3i) -> Vec3 {
    return { cast(f32)input.x, cast(f32)input.y, cast(f32)input.z }
}
vec_i2f_4 :: #force_inline proc "contextless" (input: Vec4i) -> Vec4 {
    return { cast(f32)input.x, cast(f32)input.y, cast(f32)input.z, cast(f32)input.w }
}

vec_f2i_2 :: #force_inline proc "contextless" (input: Vec2, method: RoundingMethod = .Floor) -> Vec2i {
    switch method {
    case .Floor: return { cast(i32)input.x, cast(i32)input.y }
    case .Ceil: return { cast(i32)math.ceil(input.x), cast(i32)math.ceil(input.y) }
    case .Nearest: return { cast(i32)math.round(input.x), cast(i32)math.round(input.y) }
    }
    return {}
}
vec_f2i_3 :: #force_inline proc "contextless" (input: Vec3, method: RoundingMethod = .Floor) -> Vec3i {
    switch method {
    case .Floor: return { cast(i32)input.x, cast(i32)input.y, cast(i32)input.z }
    case .Ceil: return { cast(i32)math.ceil(input.x), cast(i32)math.ceil(input.y), cast(i32)math.ceil(input.z)}
    case .Nearest: return { cast(i32)math.round(input.x), cast(i32)math.round(input.y), cast(i32)math.round(input.z) }
    }
    return {}
}
vec_f2i_4 :: #force_inline proc "contextless" (input: Vec4, method: RoundingMethod = .Floor) -> Vec4i {
    switch method {
    case .Floor: return { cast(i32)input.x, cast(i32)input.y, cast(i32)input.z, cast(i32)input.w, }
    case .Ceil: return { cast(i32)math.ceil(input.x), cast(i32)math.ceil(input.y), cast(i32)math.ceil(input.z), cast(i32)math.ceil(input.w)}
    case .Nearest: return { cast(i32)math.round(input.x), cast(i32)math.round(input.y), cast(i32)math.round(input.z), cast(i32)math.round(input.w) }
    }
    return {}
}


col_u2f :: proc(color : Color32) -> Vec4 {
    return {(cast(f32)color.x)/255.0, (cast(f32)color.y)/255.0, (cast(f32)color.z)/255.0, (cast(f32)color.w)/255.0}
}
col_f2u :: proc(color : Vec4) -> Color32 {
    return {cast(u8)(color.x*255.0), cast(u8)(color.y*255.0), cast(u8)(color.z*255.0), cast(u8)(color.w*255.0)}
}

RoundingMethod :: enum {
    Floor, Ceil, Nearest,
}

enum_step :: proc($E: typeid, value: E) -> E {
    values := reflect.enum_field_values(typeid_of(E))
    for v, idx in values {
        if transmute(reflect.Type_Info_Enum_Value)value == v {
            if idx == len(values) - 1 do return transmute(E)values[0]
            else do return transmute(E)values[idx + 1]
        }
    }
    return {}
}

readable_format_bytes :: proc(bytes_count: int, allocator:=context.allocator) -> string {
    context.allocator = allocator;
    kb := cast(f64)(bytes_count % 1024.0)/1024.0 + cast(f64)(bytes_count/1024.0);
    mb := kb / 1024.0;
    gb := mb / 1024.0;

    value : f64;
    unit  : string;

    if kb < 1.0 {
        value = f64(bytes_count);
        unit = "Bytes";
    } else if kb < 1024.0 {
        value = kb;
        unit = "KB";
    } else if mb < 1024.0 {
        value = mb;
        unit = "MB";
    } else {
        value = gb;
        unit = "GB";
    }
    
    return fmt.aprintf("% 8.3f %s", value, unit);
}


// Strings
string_bytes :: proc(str: string) -> []byte {
    rstr := transmute(runtime.Raw_String)str
    return rstr.data[0:rstr.len]
}

ActionProcess :: struct {
    process : proc(data: rawptr),
    data : rawptr,
}
execute_process :: proc(process: ActionProcess) {
    process.process(process.data)
}
