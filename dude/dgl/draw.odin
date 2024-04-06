package dgl

import gl "vendor:OpenGL"

draw_mesh :: proc(mesh : Mesh) {
	gl.BindVertexArray(mesh.vao)
	gl.DrawElements(gl.TRIANGLES, mesh.index_count, gl.UNSIGNED_INT, nil)
	gl.BindVertexArray(0)
}

draw_mesh_material :: proc(mesh : Mesh, material: Material) {
    material_upload(material)
	gl.BindVertexArray(mesh.vao)
	gl.DrawElements(gl.TRIANGLES, mesh.index_count, gl.UNSIGNED_INT, nil)
	gl.BindVertexArray(0)
}

draw_lines :: proc(count: i32) {
    polygon_mode_stash : u32
    gl.GetIntegerv(gl.POLYGON_MODE, cast(^i32)&polygon_mode_stash)
    gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE)
    gl.DrawArrays(gl.LINES, 0, count)
    gl.PolygonMode(gl.FRONT_AND_BACK, polygon_mode_stash)
}

draw_linestrip :: proc(count: i32) {
    polygon_mode_stash : u32
    gl.GetIntegerv(gl.POLYGON_MODE, cast(^i32)&polygon_mode_stash)
    gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE)
    gl.DrawArrays(gl.LINE_STRIP, 0, count)
    gl.PolygonMode(gl.FRONT_AND_BACK, polygon_mode_stash)
}