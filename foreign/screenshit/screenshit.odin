package screenshit

import "core:fmt"
import "core:c"

when ODIN_OS == .Windows {
    foreign import screenshit "bin/screenshit.lib"
}
when ODIN_OS == .Linux {
	foreign import screenshit "bin/screenshit.a"
}

foreign screenshit {
	@(link_name="test_add", private)
	_add :: proc(a, b : c.int) -> c.int ---
	@(link_name="alloc_mem", private)
	_alloc :: proc(count:c.int) -> rawptr ---
	@(link_name="release_mem", private)
	_release :: proc(ptr:rawptr) ---

}

export_add :: proc(a, b : int) -> int {
	return cast(int)_add(cast(i32)a, cast(i32)b);
}

alloc_mem :: proc(count:i32) -> [^]c.int {
	return cast([^]c.int)_alloc(count);
}
release_mem :: proc(ptr:[^]i32) {
	_release(cast(rawptr)ptr);
}
