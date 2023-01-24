package dgl

import gl "vendor:OpenGL"
import "core:log"
import "core:strings"

ShaderType :: enum u32 {
    FRAGMENT_SHADER        = gl.FRAGMENT_SHADER,
    VERTEX_SHADER          = gl.VERTEX_SHADER,
    // COMPUTE_SHADER         = gl.COMPUTE_SHADER,
    // TESS_CONTROL_SHADER    = gl.TESS_CONTROL_SHADER,
    // TESS_EVALUATION_SHADER = gl.TESS_EVALUATION_SHADER,
    GEOMETRY_SHADER        = gl.GEOMETRY_SHADER,
}

Shader :: struct {
    id : u32,
}

ShaderComponent :: struct {
    id : u32,
    type : ShaderType,
}

shader_create_component :: proc (type : ShaderType, source : string) -> ShaderComponent {
    shader: ShaderComponent

    shader.type = type

    shader.id = gl.CreateShader(cast(u32)type)

    id := shader.id
    
	cstr := strings.clone_to_cstring(source, context.temp_allocator)
    gl.ShaderSource(id, 1, &cstr, nil)
	gl.CompileShader(id)

	success : i32;
	gl.GetShaderiv(id, gl.COMPILE_STATUS, &success)

	if success == 0 {
		shader_log_length:i32
		info_buf : [512]u8
		gl.GetShaderInfoLog(id, 512, &shader_log_length, &info_buf[0])
		log.errorf("DGL: Shader ShaderComponent Compile Error: \n%s\n", info_buf);
        return ShaderComponent{}
	}
    return shader
}

shader_destroy_component :: proc (using component : ^ShaderComponent) -> bool {
    if id != 0 {
        gl.DeleteShader(id)
        id = 0
        return true
    }
    return false
}
shader_destroy_components :: proc (comps: ..^ShaderComponent) -> int {
    count := 0
    for c in comps {
        if shader_destroy_component(c) do count += 1
    }
    return count
}


shader_create :: proc {
    shader_create_from_components,
}

shader_destroy :: proc {
    shader_destroy_single,
    shader_destroy_multiple,
}
shader_destroy_single :: proc(using shader: ^Shader) {
    gl.DeleteProgram(id)
}
shader_destroy_multiple :: proc(shaders: ..^Shader) {
    for sh in shaders {
        gl.DeleteProgram(sh.id)
    }
}

shader_create_from_components :: proc(comps: ..^ShaderComponent) -> Shader {
    shader : Shader
    shader.id = gl.CreateProgram()
    for c in comps {
        gl.AttachShader(shader.id, c.id)
    }
    gl.LinkProgram(shader.id)

    success : i32

	gl.GetProgramiv(shader.id, gl.LINK_STATUS, &success)
	if success == 0 {
		info_length:i32
		info_buf : [512]u8
		gl.GetProgramInfoLog(shader.id, 512, &info_length, &info_buf[0]);
		log.debugf("DGL Error: Shader Linking Error: \n%s\n", info_buf)
        return Shader{}
	}

    return shader
}

shader_bind :: proc(using shader: ^Shader) {
    if id == 0 {
        log.error("DGL Error: Failed to bind shader, the shader is not correctly initialized!")
    } else {
        gl.UseProgram(id)
    }
}

shader_load_vertex_and_fragment :: proc(vertex_source, fragment_source : string) -> Shader {
	shader_comp_vertex := shader_create_component(.VERTEX_SHADER, vertex_source)
	shader_comp_fragment := shader_create_component(.FRAGMENT_SHADER, fragment_source)
	shader := shader_create(&shader_comp_vertex, &shader_comp_fragment)
	shader_destroy_components(&shader_comp_vertex, &shader_comp_fragment)
	return shader
}