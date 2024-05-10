package render

import dd "../"
import "../dgl"

Pass :: dd.RenderPass
RenderObject :: dd.RenderObject
RenderObjectEx :: dd.RenderObjectEx

UniformTableTransform :: dd.UniformTableTransform
UniformTableGeneral :: dd.UniformTableGeneral
UniformTableSprite :: dd.UniformTableSprite

RObj :: dd.RObj
RObjMesh :: dd.RObjMesh
RObjImmediateScreenMesh :: dd.RObjImmediateScreenMesh
RObjTextMesh :: dd.RObjTextMesh
RObjTextMeshScreen :: dd.RObjTextMeshScreen
RObjSprite :: dd.RObjSprite
RObjCustom :: dd.RObjCustom

RenderCamera :: dd.RenderCamera
CameraUniformData :: dd.CameraUniformData
RenderSystem :: dd.RenderSystem

get_default_framebuffer :: dd._get_default_framebuffer
get_temp_mesh_builder :: proc() -> ^dgl.MeshBuilder {
    return &dd.rsys.temp_mesh_builder
}
system :: proc() -> ^dd.RenderSystem {
    return &dd.rsys
}

get_default_font :: #force_inline proc() -> dd.DynamicFont {
	return system().default_font
}

pass_init :: dd.render_pass_init
pass_release :: dd.render_pass_release

pass_add_obj :: dd.render_pass_add_object
// Immediate objects would be deleted after drawn.
pass_add_immediate_obj :: dd.render_pass_add_object_immediate

// `RObjHandle` is returned by `pass_add_obj`.
pass_get_obj :: dd.render_pass_get_object
// `RObjHandle` is returned by `pass_add_obj`.
pass_remove_obj :: dd.render_pass_remove_object
