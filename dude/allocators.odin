package dude

import "core:mem"
import "core:log"
import "core:runtime"


@(private="file")
MB :: 1024 * 1024
@(private="file")
KB :: 1024

@(private="file")
debug_arena_size :: 8 * MB
@(private="file")
frame_arena_size :: 8 * MB
@(private="file")
level_arena_size :: 32 * MB

@(private="file")
debug_buffer : [debug_arena_size] byte
@(private="file")
frame_buffer : [frame_arena_size] byte
// @(private="file")
// level_buffer : [level_arena_size] byte

DudeAllocators :: struct {
    debug_arena, level_arena, frame_arena : mem.Arena,
    debug, level, frame : mem.Allocator,
    default : mem.Allocator,
}

allocators : DudeAllocators

buffer : [dynamic]byte

allocators_init :: proc() {
	mem.arena_init(&allocators.debug_arena, debug_buffer[:])
	allocators.debug = mem.arena_allocator(&allocators.debug_arena)

    mem.arena_init(&allocators.frame_arena, frame_buffer[:])
    allocators.frame = mem.arena_allocator(&allocators.frame_arena)

    allocators.default = runtime.default_allocator()

    // mem.arena_init(&allocators.level_arena, level_buffer[:])
    // allocators.level = mem.arena_allocator(&allocators.level_arena)
}

allocators_release :: proc() {
}
