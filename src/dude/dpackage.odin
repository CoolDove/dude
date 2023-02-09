package dude

import "core:log"
import "core:os"
import "core:strings"

dpackage_init :: proc(path: string, allocator:= context.allocator) -> (^DPackage, bool) {
    context.allocator = allocator
    data, ok := os.read_entire_file(path)
    defer delete(data)
    if ok {
        source := cast(string)data
        return dpackage_init_from_source(source)
    } else {
        return nil, false
    }
}
dpackage_init_from_source :: proc(source: string, allocator:= context.allocator) -> (^DPackage, bool) {
    dpac := generate_package_from_source(source)
    log.debugf("DPac: dpackage [ {} ] loaded!", strings.to_string(dpac.name))
    return dpac, true
}

dpackage_destroy :: proc(dpac: ^DPackage) {

}