package dude


import "dgl"


// anchor: x: [0,1], y: [0,1]
mesher_quad :: proc(mb: ^dgl.MeshBuilder, size, anchor: Vec2) {
    assert(mb.vertex_format == dgl.VERTEX_FORMAT_P2U2, "Mesher: Only P2U2 format is supported.")
    idx := cast(u32)len(mb.vertices)
    min := -anchor * size
    max := (1-anchor) * size
    dgl.mesh_builder_add_vertices(mb, 
        {v4={min.x,min.y, 0,0}},
        {v4={max.x,min.y, 1,0}},
        {v4={min.x,max.y, 0,1}},
        {v4={max.x,max.y, 1,1}},
    )
    dgl.mesh_builder_add_indices(mb, idx+0,idx+1,idx+2, idx+1,idx+3,idx+2)
}

mesher_line_grid :: proc(mb: ^dgl.MeshBuilder, half_size:int, unit: f32) {
    assert(mb.vertex_format == dgl.VERTEX_FORMAT_P2U2, "Mesher: Only P2U2 format is supported.")
    size := 2 * half_size
    min := -cast(f32)half_size * unit;
    max := cast(f32)half_size * unit;

    for i in 0..=size {
        x := min + cast(f32)i * unit
        dgl.mesh_builder_add_vertices(mb, {v2={x,min}})
        dgl.mesh_builder_add_vertices(mb, {v2={x,max}})
    }
    for i in 0..=size {
        y := min + cast(f32)i * unit
        dgl.mesh_builder_add_vertices(mb, {v2={min,y}})
        dgl.mesh_builder_add_vertices(mb, {v2={max,y}})
    }
}
