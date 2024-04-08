package dude

import sdl "vendor:sdl2"
import win32 "core:sys/windows"

foreign import imm32 "system:Imm32.lib"

@(private="file")
HIMC :: win32.HWND

@(private="file")
DwStyle :: enum {
	CFS_DEFAULT = 0x0000,
	CFS_RECT = 0x0001,
	CFS_POINT = 0x0002,
	CFS_FORCE_POSITION = 0x0020,
	CFS_CANDIDATEPOS = 0x0040,
	CFS_EXCLUDE = 0x0080,
}

@(private="file")
COMPOSITIONFORM :: struct {
	dwStyle : win32.DWORD,
	ptCurrentPos : win32.POINT,
	rcArea : win32.RECT,
}

@(default_calling_convention="system")
foreign imm32 {
	ImmSetCompositionWindow :: proc(unnamedParam1: HIMC, lpCompForm: ^COMPOSITIONFORM) ---
	ImmGetContext :: proc(unnamedParam1: win32.HWND) -> HIMC ---
}

window_imm_set_position :: proc(wnd: ^sdl.Window, pos: Vec2) {
	info : sdl.SysWMinfo
	sdl.GetWindowWMInfo(wnd, &info)
	hwnd := cast(win32.HWND)info.info.win.window

	himc := ImmGetContext(hwnd)
	comp :=COMPOSITIONFORM {
		auto_cast DwStyle.CFS_CANDIDATEPOS,
		{auto_cast pos.x, auto_cast pos.y},
		{},
	}
	ImmSetCompositionWindow(himc, &comp)
}