package shader

import basic "../basic"

import gl "vendor:OpenGL"
import "core:log"
import "core:strings"

GLObject :: basic.GLObject

ShaderType :: enum u32 {
    FRAGMENT_SHADER        = gl.FRAGMENT_SHADER,
    VERTEX_SHADER          = gl.VERTEX_SHADER,
    // COMPUTE_SHADER         = gl.COMPUTE_SHADER,
    // TESS_CONTROL_SHADER    = gl.TESS_CONTROL_SHADER,
    // TESS_EVALUATION_SHADER = gl.TESS_EVALUATION_SHADER,
    GEOMETRY_SHADER        = gl.GEOMETRY_SHADER,
}

Shader :: struct {
    using obj : GLObject,
}

Component :: struct {
    using obj : GLObject,
    type : ShaderType,
}

create_component :: proc (type : ShaderType, source : string) -> Component {
    shader: Component

    shader.type = type

    shader.native_id = gl.CreateShader(cast(u32)type)

    id := shader.native_id
    
	cstr := strings.clone_to_cstring(source, context.temp_allocator)
    gl.ShaderSource(id, 1, &cstr, nil)
	gl.CompileShader(id)

	success : i32;
	gl.GetShaderiv(id, gl.COMPILE_STATUS, &success)

	if success == 0 {
		shader_log_length:i32
		info_buf : [512]u8
		gl.GetShaderInfoLog(id, 512, &shader_log_length, &info_buf[0])
		log.errorf("DGL: Shader Component Compile Error: \n%s\n", info_buf);
        return Component{}
	}
    return shader
}

destroy_component :: proc (using component : ^Component) -> bool {
    if native_id != 0 {
        gl.DeleteShader(native_id)
        native_id = 0
        return true
    }
    return false
}
destroy_components :: proc (comps: ..^Component) -> int {
    count := 0
    for c in comps {
        if destroy_component(c) do count += 1
    }
    return count
}


create :: proc {
    create_from_components,
}

destroy :: proc {
    destroy_single,
    destroy_multiple,
}
destroy_single :: proc(using shader: ^Shader) {
    gl.DeleteProgram(native_id)
}
destroy_multiple :: proc(shaders: ..^Shader) {
    for sh in shaders {
        gl.DeleteProgram(sh.native_id)
    }
}

create_from_components :: proc(comps: ..^Component) -> Shader {
    shader : Shader
    shader.native_id = gl.CreateProgram()
    for c in comps {
        gl.AttachShader(shader.native_id, c.native_id)
    }
    gl.LinkProgram(shader.native_id)

    success : i32

	gl.GetProgramiv(shader.native_id, gl.LINK_STATUS, &success)
	if success == 0 {
		info_length:i32
		info_buf : [512]u8
		gl.GetProgramInfoLog(shader.native_id, 512, &info_length, &info_buf[0]);
		log.debugf("DGL Error: Shader Linking Error: \n%s\n", info_buf)
        return Shader{}
	}

    return shader
}

bind :: proc(using shader: ^Shader) {
    if native_id == 0 {
        log.error("DGL Error: Failed to bind shader, the shader is not correctly initialized!")
    } else {
        gl.UseProgram(native_id)
    }
}