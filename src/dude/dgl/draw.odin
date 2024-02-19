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