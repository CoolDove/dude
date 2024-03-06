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

DPAC_TAG :: "dpac"

bundle :: proc(T: typeid, allocator:= context.allocator) -> (output: []byte, err: BundleErr) {
    using strings
    b : Builder
    builder_init(&b)

    dpac_header := PackageHeader{transmute(u32)MAGIC, VERSION, cast(u32)endian.PLATFORM_BYTE_ORDER}
    write_bytes(&b, slice.bytes_from_ptr(&dpac_header, size_of(PackageHeader)))

    if err = _bundle_struct(&b, type_info_of(T)); err == .None {
        fmt.printf("bundle success, size: {} bytes.\n", builder_len(b))
        return transmute([]u8)to_string(b), err
    } else {
        builder_destroy(&b)
        fmt.printf("bundle failed.")
        return {}, err
    }
}