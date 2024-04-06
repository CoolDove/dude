package dpac

import "core:slice"
import "core:strconv"
import "core:os"
import "core:reflect"
import "core:bytes"
import "core:encoding/endian"
import "core:strings"


// Dpackage is designed to use a struct as the meta data for a dpackage.
// Use field tag: dpac to indicate the file path. If a field is not tagged 
//  by `dpac` and it's a struct, the dpac will take it as a nested struct.
// You can tag an array/slice's load path like "./res/texture_$(index).png"
//  the index should be continuous.

// If you just want to bundle a dpackage, you can do it without intializing
//  the dude. But loading a dpackage depends on the dude, so you have to 
//  initialize the dude before loading a dpackage.


MAGIC :[8]u8: {'D','P','A','C','D','P','A','C'}
VERSION :u64: 1

DPAC_TAG :: "dpac"

PacEvent :: enum {
    Load, Release,
}

register_load_handler :: proc(handler: proc(event: PacEvent, p: rawptr, t: ^reflect.Type_Info, data: []u8)) {
    // Leak, but i don't care.
    append(&_handlers, handler)
}

release_handlers :: proc() {
    delete(_handlers)
}