package dpac

import "core:fmt"
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

// TODO: Endian is not handled.

MAGIC :[4]u8: {'D','P','A','C'}
VERSION :u32: 1

bundle :: proc(T: typeid, allocator:= context.allocator) -> []byte {
    using strings
    b : Builder
    builder_init(&b)
    _write_object(&b, PackageHeader{transmute(u32)MAGIC, VERSION, cast(u32)endian.PLATFORM_BYTE_ORDER})

    if _bundle_struct(&b, type_info_of(T)) {
        fmt.printf("bundle success, size: {} bytes.", builder_len(b))
        return transmute([]u8)to_string(b)
    } else {
        builder_destroy(&b)
        fmt.printf("bundle failed.")
        return {}
    }
}