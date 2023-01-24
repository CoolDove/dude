package main

import "core:mem"
import "core:strings"
import "core:os"
import "core:io"
import "core:log"
import "core:fmt"
import "core:runtime"
import "core:c/libc"

import path "core:path/filepath"

/*
./build.exe run debug release

Run `./update_builder.bat`,
a builder program will be generated to build the project.

*/

when ODIN_OS == .Windows {

BuildFlag :: enum {
    Run, 
    Debug,
    Release,
    Treesize,
}

BuildFlags :: bit_set[ BuildFlag ]

NAME :: "Demo"
SRC  :: "./src"
COLLECTION_STR :: "-collection:pac=./pac/"

APP_RC :: "app.rc"

RC_CONTENT :string: `APP_ICON ICON "res/dude.ico"`

main :: proc() {
    logger := log.create_console_logger(.Debug, {.Level, .Terminal_Color})
    context.logger = logger

    flags := get_flags()

    current := os.get_current_directory()
    defer delete(current)
    
    log.debugf("Building program {}, current directory: {}", NAME, current)
    defer log.debugf("DONE")

    create_app_rc()
    defer delete_app_rc()

    log.debugf("**Copy DLLs**")
    copy_file(
        "./pac/assimp/lib/assimp-vc143-mt.dll",
        "./bin/release/assimp-vc143-mt.dll")
    copy_file(
        "./pac/assimp/lib/assimp-vc143-mtd.dll",
        "./bin/debug/assimp-vc143-mtd.dll")

    build_all := ! (BuildFlag.Debug in flags) && ! (BuildFlag.Release in flags)
    run_mode  := BuildFlag.Run in flags && !build_all

    if BuildFlag.Debug in flags || build_all {
        log.debugf("**Build Debug**")
        command := make_odin_command(
            NAME, SRC, " ", COLLECTION_STR, 
            true, run_mode)
        defer delete(command)
        libc.system(strings.clone_to_cstring(command))
        log_congratulations()
        if BuildFlag.Treesize in flags do libc.system("treesize bin/debug")
    }

    if BuildFlag.Release in flags || build_all {
        log.debugf("**Build Release**")
        command := make_odin_command(
            NAME, SRC, " -no-bounds-check -subsystem:windows -o:speed", COLLECTION_STR, 
            false, run_mode)
        defer delete(command)
        libc.system(strings.clone_to_cstring(command, context.temp_allocator))
        log_congratulations()
        if BuildFlag.Treesize in flags do libc.system("treesize bin/release")
    }

}

// ## Builder
get_flags :: proc() -> BuildFlags {
    args := os.args
    defer delete(args)

    flags : BuildFlags

    for arg in args[1:] {
        if arg == "debug" do incl(&flags, BuildFlag.Debug)
        else if arg == "release" do incl(&flags, BuildFlag.Release)
        else if arg == "run" do incl(&flags, BuildFlag.Run)
        else if arg == "size" do incl(&flags, BuildFlag.Treesize)
        else do log.errorf("Unkown arg: {}", arg)
    }

    return flags
}

create_app_rc :: proc() {
    data := transmute([]byte) RC_CONTENT
    if os.write_entire_file(APP_RC, data) do log.debugf("Create RC file.")
}
delete_app_rc :: proc() {
    if os.exists(APP_RC) do os.remove(APP_RC)
    res := fmt.tprintf("{}.res", path.stem(APP_RC))
    if os.exists(res) do os.remove(res)
    log.debugf("Remove windows rc file: {}, {}", APP_RC, res)
}

log_congratulations :: proc() {
    log.debug(`
========
Good Job
========`)
}

make_odin_command :: proc(name, src, args, collection_str: string, debug, run: bool, allocator:= context.allocator) -> string {
    dorr :string= "debug" if debug else "release"

    sb : strings.Builder
    strings.builder_init(&sb, 0, 256)

    strings.write_string(&sb, "odin ")
    strings.write_string(&sb, "run " if run else "build ")
    strings.write_string(&sb, src)
    strings.write_string(&sb, fmt.tprintf(" -out:bin/{}/{}.exe ", dorr, name))
    if debug do strings.write_string(&sb, "-debug ")

    strings.write_string(&sb, fmt.tprintf(" -resource:{} {} {}", APP_RC, args, collection_str))

    cmd := strings.to_string(sb)
    log.debugf("Odin Command: {}", cmd)

    return cmd
}


// ## Utils
mkdir :: proc(dir : string) -> bool {
    directory, new_alloc := path.to_slash(dir)
    if new_alloc do defer delete(directory)

    sb : strings.Builder
    strings.builder_init(&sb, 0, len(directory))
    defer strings.builder_destroy(&sb)

    for str in strings.split_after_iterator(&directory, "/") {
        strings.write_string(&sb, str)

        current := strings.to_string(sb)
        log.debugf("path: {}", current)

        if current != "" && !os.exists(current) {
            err := os.make_directory(current)
            if err != 0 {
                log.errorf("Failed to create directory: {}", current)
                return false
            } else {
                log.debugf("mkdir: {}", current)
            }
        }
    }
    return true
}

copy_dir :: proc(src, dst : string, ext : []string) {
    assert(false)
}

copy_file :: proc(src, dst : string) {
    if len(src) == 0 || len(dst) == 0{
        log.errorf("Copy src/dst is empty.", src)
        return
    }
    if !os.exists(src) {
        log.errorf("Copy src: {} doesn't exist!", src)
        return
    }
    if !os.is_file(src) {
        log.errorf("Copy src: {} is not a file!", src)
        return
    }

    data, _ := os.read_entire_file(src)
    defer delete(data)

    directory := path.dir(dst)
    defer delete(directory)

    mkdir(directory)

    if os.exists(dst) do os.remove(dst)

    if os.write_entire_file(dst, data) {
        log.debugf("Copy file: {} to {}.", src, dst)
    } else {
        log.errorf("Failed to copy file: {} to {}.", src, dst)
    } 
}


}