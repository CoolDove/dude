package dude


import "dgl"


// anchor: x: [0,1], y: [0,1]
mesher_quad :: proc(mb: ^dgl.MeshBuilder, size, anchor: Vec2, offset:Vec2={0,0}, uv_min:Vec2={0,0},uv_max:Vec2={1,1}) {
    assert(mb.vertex_format == dgl.VERTEX_FORMAT_P2U2, "Mesher: Only P2U2 format is supported.")
    idx := cast(u32)len(mb.vertices)/4
    min := -anchor * size + offset
    max := (1-anchor) * size + offset
    dgl.mesh_builder_add_vertices(mb, 
        {v4={min.x,min.y, uv_min.x, uv_min.y}},
        {v4={max.x,min.y, uv_max.x, uv_min.y}},
        {v4={min.x,max.y, uv_min.x, uv_max.y}},
        {v4={max.x,max.y, uv_max.x, uv_max.y}},
    )
    dgl.mesh_builder_add_indices(mb, idx+0,idx+1,idx+2, idx+1,idx+3,idx+2)
}

mesher_line_grid :: proc(mb: ^dgl.MeshBuilder, half_size:int, unit: f32, color: Color, subcell_size := 0, color_b := Color{1,0,1,1}) {
    assert(mb.vertex_format == dgl.VERTEX_FORMAT_P2U2C4, "Mesher: Only P2U2C4 format is supported.")
    size := 2 * half_size
    min := -cast(f32)half_size * unit;
    max := cast(f32)half_size * unit;

    col : Color
    for i in 0..=size {
        x := min + cast(f32)i * unit
        col = color_b if subcell_size != 0 && i % subcell_size == 0 else color
        dgl.mesh_builder_add_vertices(mb, {v8={x,min, 0,0, col.r,col.g,col.b,col.a}})
        dgl.mesh_builder_add_vertices(mb, {v8={x,max, 0,0, col.r,col.g,col.b,col.a}})
    }
    for i in 0..=size {
        y := min + cast(f32)i * unit
        col = color_b if subcell_size != 0 && i % subcell_size == 0 else color
        dgl.mesh_builder_add_vertices(mb, {v8={min,y, 0,0, col.r,col.g,col.b,col.a}})
        dgl.mesh_builder_add_vertices(mb, {v8={max,y, 0,0, col.r,col.g,col.b,col.a}})
    }
}
