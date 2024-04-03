package render

import dd "../"
import "../dgl"

get_default_framebuffer :: dd._get_default_framebuffer
get_temp_mesh_builder :: proc() -> ^dgl.MeshBuilder {
    return &dd.rsys.temp_mesh_builder
}
system :: proc() -> ^dd.RenderSystem {
    return &dd.rsys
}
