package dude


import "core:log"
import "core:io"
import "core:strings"


import gl "vendor:OpenGL"

dshader_load_from_source :: proc(source: string) -> u32 {
    using strings

    vertex_sb, fragment_sb : Builder
    builder_init_len_cap(&vertex_sb, 0, 2048)
    builder_init_len_cap(&fragment_sb, 0, 2048)
    defer {
        builder_destroy(&vertex_sb)
        builder_destroy(&fragment_sb)
    }
    
    src := source
    linec := 0
    target : ^Builder= nil
    for line in split_lines_iterator(&src) {
        linec += 1

        if len(line) > 2 && line[0:2] == "##" {
            target_name := trim_space(line[2:])
            if target_name == "VERTEX" do target = &vertex_sb
            else if target_name == "FRAGMENT" || target_name == "FRAG" do target = &fragment_sb
            continue
        }
        if target != nil {
            write_string(target, line)
            write_byte(target, '\n')
        }
    }

    id := glsl_load_vertex_and_fragment(to_string(vertex_sb), to_string(fragment_sb))


	if id == 0 {
		log.warnf("VertexSource: {}", to_string(vertex_sb))
		log.warnf("FragmentSource: {}", to_string(fragment_sb))
	}

    return id
}


ShaderType :: enum u32 {
    FRAGMENT_SHADER        = gl.FRAGMENT_SHADER,
    VERTEX_SHADER          = gl.VERTEX_SHADER,
    // COMPUTE_SHADER         = gl.COMPUTE_SHADER,
    // TESS_CONTROL_SHADER    = gl.TESS_CONTROL_SHADER,
    // TESS_EVALUATION_SHADER = gl.TESS_EVALUATION_SHADER,
    GEOMETRY_SHADER        = gl.GEOMETRY_SHADER,
}

ShaderComponent :: struct {
    id : u32,
    type : ShaderType,
}

glsl_create_component :: proc (shader_type : ShaderType, source : string) -> ShaderComponent {
    shader := ShaderComponent{ 
        id = gl.CreateShader(cast(u32)shader_type),
        type = shader_type, 
    }
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
		log.errorf("Shader: ShaderComponent Compile Error: \n%s\n", info_buf);
        return ShaderComponent{}
	}
    return shader
}
glsl_destroy_component :: proc (using component : ^ShaderComponent) -> bool {
    if id != 0 {
        gl.DeleteShader(id)
        id = 0
        return true
    }
    return false
}
glsl_destroy_components :: proc (comps: ..^ShaderComponent) -> int {
    count := 0
    for c in comps {
        if glsl_destroy_component(c) do count += 1
    }
    return count
}

glsl_create_from_components :: proc(comps: ..^ShaderComponent) -> u32 {
    // shader : u32
    shader := gl.CreateProgram()
    for c in comps {
        gl.AttachShader(shader, c.id)
    }
    gl.LinkProgram(shader)

    success : i32

	gl.GetProgramiv(shader, gl.LINK_STATUS, &success)
	if success == 0 {
		info_length:i32
		info_buf : [512]u8
		gl.GetProgramInfoLog(shader, 512, &info_length, &info_buf[0]);
		log.debugf("DGL Error: Shader Linking Error: \n%s\n", info_buf)
        return 0
	}

    return shader
}

glsl_load_vertex_and_fragment :: proc(vertex_source, fragment_source : string) -> u32 {
	shader_comp_vertex := glsl_create_component(.VERTEX_SHADER, vertex_source)
	shader_comp_fragment := glsl_create_component(.FRAGMENT_SHADER, fragment_source)
	shader := glsl_create_from_components(&shader_comp_vertex, &shader_comp_fragment)
	glsl_destroy_components(&shader_comp_vertex, &shader_comp_fragment)
	return shader
}
