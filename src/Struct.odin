package main

import "core:math/linalg"
import "dgl"

Vec2 :: dgl.Vec2
Vec3 :: dgl.Vec3
Vec4 :: dgl.Vec4

Vec2i :: dgl.Vec2i
Vec3i :: dgl.Vec3i
Vec4i :: dgl.Vec4i

VertexPCU  :: dgl.VertexPCU
VertexPCNU :: dgl.VertexPCNU

Transform :: dgl.Transform

Camera :: struct {
    using dglcam : dgl.Camera
}