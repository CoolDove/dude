package dude

import "core:strings"
import win32 "core:sys/windows"


// TODO: More api on child process.
//  You can easily create execute a child process with this.

execute :: proc(cmd: string, allocator:= context.allocator) -> string {
    context.allocator = allocator
    using win32
    hPipeRead, hPipeWrite : HANDLE
    saAttr := SECURITY_ATTRIBUTES{size_of(SECURITY_ATTRIBUTES), nil, true}
    si : STARTUPINFOW
    pi : PROCESS_INFORMATION

    buf : [4096]u8

    bytesRead : DWORD
    totalBytesRead : DWORD
    result : strings.Builder

    strings.builder_init(&result)

    if !CreatePipe(&hPipeRead, &hPipeWrite, &saAttr, 0) do return {}

    si.cb = size_of(STARTUPINFOW)
    si.hStdError = hPipeWrite
    si.hStdOutput = hPipeWrite
    si.dwFlags |= STARTF_USESTDHANDLES

    cmd_wstr := utf8_to_wstring(cmd)
    if !CreateProcessW(nil, cmd_wstr, nil, nil, true, 0, nil, nil, &si, &pi) {
        CloseHandle(hPipeWrite)
        CloseHandle(hPipeRead)
        return {}
    }

    CloseHandle(hPipeWrite);

    for ReadFile(hPipeRead, raw_data(buf[:]), size_of(buf), &bytesRead, nil) && bytesRead > 0 {
        strings.write_bytes(&result, buf[:bytesRead])
        totalBytesRead += bytesRead;
    }

    CloseHandle(hPipeRead);
    CloseHandle(pi.hThread);
    CloseHandle(pi.hProcess);

    return strings.to_string(result);
}