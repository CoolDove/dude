package dude

import sdl "vendor:sdl2"
import win32 "core:sys/windows"

foreign import imm32 "system:Imm32.lib"

@(private="file")
HIMC :: win32.HWND

@(private="file")
CFS_DEFAULT			:win32.DWORD: 0x0000
@(private="file")
CFS_RECT			:win32.DWORD: 0x0001
@(private="file")
CFS_POINT			:win32.DWORD: 0x0002
@(private="file")
CFS_FORCE_POSITION	:win32.DWORD: 0x0020
@(private="file")
CFS_CANDIDATEPOS	:win32.DWORD: 0x0040
@(private="file")
CFS_EXCLUDE			:win32.DWORD: 0x0080

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
		CFS_POINT,
		{auto_cast pos.x, auto_cast pos.y},
		{},
	}
	ImmSetCompositionWindow(himc, &comp)
}