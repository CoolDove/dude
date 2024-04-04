package main

import "core:strings"
import win32 "core:sys/windows"


execute :: proc(cmd: string, allocator:= context.allocator) -> string {
    context.allocator = allocator
    using win32
    hPipeRead, hPipeWrite : HANDLE
    saAttr := SECURITY_ATTRIBUTES{size_of(SECURITY_ATTRIBUTES), nil, true}
    si : STARTUPINFOW
    pi : PROCESS_INFORMATION

    buf : [4096]u8
    // SECURITY_ATTRIBUTES saAttr = { sizeof(SECURITY_ATTRIBUTES), NULL, TRUE };
    // STARTUPINFO si;
    // PROCESS_INFORMATION pi;
    // char buf[4096];

    bytesRead : DWORD
    totalBytesRead : DWORD
    result : strings.Builder

    strings.builder_init(&result)
    
    // bytesRead: DWORD
    // totalBytesRead :DWORD = 0
    // char* result = NULL

    // 创建管道
    if !CreatePipe(&hPipeRead, &hPipeWrite, &saAttr, 0) do return {}

    // 设置启动信息
    // ZeroMemory(&si, size_of(STARTUPINFOW));
    si.cb = size_of(STARTUPINFOW)
    si.hStdError = hPipeWrite
    si.hStdOutput = hPipeWrite
    si.dwFlags |= STARTF_USESTDHANDLES

    // 启动进程
    cmd_wstr := utf8_to_wstring(cmd)
    if !CreateProcessW(nil, cmd_wstr, nil, nil, true, 0, nil, nil, &si, &pi) {
        CloseHandle(hPipeWrite)
        CloseHandle(hPipeRead)
        return {}
    }

    // 关闭管道的写端
    CloseHandle(hPipeWrite);

    // 读取进程的标准输出
    for ReadFile(hPipeRead, raw_data(buf[:]), size_of(buf), &bytesRead, nil) && bytesRead > 0 {
        strings.write_bytes(&result, buf[:bytesRead])
        // char* tmp = realloc(result, totalBytesRead + bytesRead + 1);
        // if (tmp == NULL) {
        //     free(result);
        //     result = NULL;
        //     break;
        // }
        // result = tmp;

        // memcpy(result + totalBytesRead, buf, bytesRead);
        totalBytesRead += bytesRead;
    }

    // 添加字符串结束符
    // if (result != NULL)
    //     result[totalBytesRead] = '\0';

    // 关闭句柄
    CloseHandle(hPipeRead);
    CloseHandle(pi.hThread);
    CloseHandle(pi.hProcess);

    return strings.to_string(result);
}