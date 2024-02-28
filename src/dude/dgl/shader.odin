package dgl

import gl "vendor:OpenGL"
import "core:log"
import "core:strings"
import "core:fmt"

ShaderType :: enum u32 {
    FRAGMENT_SHADER        = gl.FRAGMENT_SHADER,
    VERTEX_SHADER          = gl.VERTEX_SHADER,
    // COMPUTE_SHADER         = gl.COMPUTE_SHADER,
    // TESS_CONTROL_SHADER    = gl.TESS_CONTROL_SHADER,
    // TESS_EVALUATION_SHADER = gl.TESS_EVALUATION_SHADER,
    GEOMETRY_SHADER        = gl.GEOMETRY_SHADER,
}

ShaderId :: u32

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
		fmt.printf("DGL: Shader ShaderComponent Compile Error: \n%s\n", info_buf);
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
shader_destroy_single :: proc(shader: ShaderId) {
    shader := shader
    gl.DeleteProgram(shader)
}
shader_destroy_multiple :: proc(shaders: ..ShaderId) {
    for sh in shaders {
        gl.DeleteProgram(sh)
    }
}

shader_create_from_components :: proc(comps: ..^ShaderComponent) -> ShaderId {
    shader : ShaderId
    shader = auto_cast gl.CreateProgram()
    for c in comps {
        gl.AttachShader(auto_cast shader, c.id)
    }
    gl.LinkProgram(auto_cast shader)

    success : i32

	gl.GetProgramiv(shader, gl.LINK_STATUS, &success)
	if success == 0 {
		info_length:i32
		info_buf : [512]u8
		gl.GetProgramInfoLog(shader, 512, &info_length, &info_buf[0]);
		fmt.printf("DGL Error: Shader Linking Error: \n%s\n", info_buf)
        return 0
	}
    return shader
}

shader_bind :: proc(shader: ShaderId) {
    gl.UseProgram(shader)
}

shader_current :: proc() -> ShaderId {
    id : i32
    gl.GetIntegerv(gl.CURRENT_PROGRAM, &id)
    return cast(u32)id
}

shader_load_from_sources :: proc(vertex_source, fragment_source : string, preprocess:= false) -> ShaderId {
    vert, frag := vertex_source, fragment_source
    if preprocess {
        vert, frag = shader_preprocess(vert), shader_preprocess(frag)
    }
    defer if preprocess {
        delete(vert); delete(frag)
    }
	shader_comp_vertex := shader_create_component(.VERTEX_SHADER, vert)
    if shader_comp_vertex.id <= 0 {
        log.errorf("DGL shader: failed to compile vertex shader:\n{}", vertex_source)
        return 0
    }
	shader_comp_fragment := shader_create_component(.FRAGMENT_SHADER, frag)
    if shader_comp_fragment.id <= 0 {
        log.errorf("DGL shader: failed to compile fragment shader:\n{}", fragment_source)
        return 0
    }
	shader := shader_create(&shader_comp_vertex, &shader_comp_fragment)
    if shader <= 0 {
        log.errorf("DGL shader: failed to load shader:\n{}\n{}", vertex_source, fragment_source)
    }
	shader_destroy_components(&shader_comp_vertex, &shader_comp_fragment)
	return shader
}