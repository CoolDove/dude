package main

when ODIN_OS == .Windows {
    foreign import kernel32 "system:kernel32.lib"

    @(default_calling_convention="system")
    foreign kernel32 {
        @(link_name="SetConsoleOutputCP") os_windows_set_console_output_cp :: proc(cp : u32) ---
    }
}
