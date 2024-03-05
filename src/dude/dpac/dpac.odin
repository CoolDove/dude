package dpac

import "core:math/linalg"
import "core:log"
import "core:mem"
import "core:math/rand"
import "core:slice"
import "core:runtime"
import "core:bytes"
import "core:strings"
import "core:encoding/json"

// Dpackage is designed to use a struct as the meta data for a dpackage.
// Use field tag: dpac to indicate the file location.

Writer :: struct {
    toc : [dynamic]Block,
    buffer : strings.Builder,
}

Block :: struct {
    name : string,
    offset, size : u64,
}

writer_init :: proc(writer: ^Writer, allocator:= context.allocator) {
    context.allocator = allocator
    writer.toc = make([dynamic]Block, 0, 32)
    strings.builder_init(&writer.buffer, 0, 4 * 1024 * 1024)
}
writer_release :: proc(writer: ^Writer) {
    delete(writer.toc)
    strings.builder_destroy(&writer.buffer)
}

append_thing :: proc(writer: ^Writer, name: string, thing: $T) {
    offset := strings.builder_len(writer.buffer)
    copy := thing
    content := (cast([^]byte)(&copy))[:size_of(thing)]
    append_content(writer, name, content)
}

append_content :: proc(writer: ^Writer, name: string, content: []byte) {
    using strings, writer
    offset := builder_len(buffer)
    n := write_bytes(&buffer, content)
    append(&writer.toc, Block{name, auto_cast offset, auto_cast n})
}

write :: proc(writer: ^Writer, allocator:= context.allocator) -> []byte {
    context.allocator = allocator
    using strings
    sb: Builder
    builder_init(&sb)

    /*
    |MAGIC|u64(size of TocJson)|*TocJson|*Content|
    */

    // MAGIC
    write_string(&sb, MAGIC)
    // Header
    pos_toc_size := builder_len(sb)
    write_i64(&sb, 0) // place holder for a u64 to indicate header size.

    opt : json.Marshal_Options
    opt.pretty = false
    toc_size := builder_len(sb)
    json.marshal_to_builder(&sb, writer.toc[:], &opt)
    toc_size = builder_len(sb) - toc_size

    ptr_toc_size := cast(^u64)(&sb.buf[pos_toc_size])
    ptr_toc_size^ = cast(u64)toc_size
    
    // Content
    write_bytes(&sb, writer.buffer.buf[:])

    return transmute([]byte)to_string(sb)
}

Reader :: struct {
    buffer : []byte,
    toc : map[string]Block,
}

reader_release :: proc(reader: ^Reader) {
    delete(reader.toc)
}

read :: proc(data: []byte, allocator:= context.allocator) -> (Reader, bool) {
    context.allocator = allocator
    magic := transmute(string)data[:len(MAGIC)]
    if magic != MAGIC do return {}, false
    
    size_of_toc := (cast(^u64)&data[len(MAGIC)])^

    toc_start_idx := cast(u64)(len(MAGIC) + size_of(u64))
    toc_json := data[toc_start_idx:size_of_toc+toc_start_idx]

    blocks : []Block
    json.unmarshal(toc_json, &blocks)
    defer delete(blocks)

    r := Reader{
        buffer = data,
        toc = make_map(map[string]Block),
    }

    for &b in blocks {
        b.offset += size_of_toc + toc_start_idx
        map_insert(&r.toc, b.name, b)
    }

    return r, true
}

read_block :: proc(reader: ^Reader, name: string) -> []byte {
    if block, ok := reader.toc[name]; ok {
        return reader.buffer[block.offset:block.offset + block.size]
    }
    return {}
}

bundle :: proc(pac: ^$T, allocator:= context.allocator) -> []byte {
    using strings
    sb : Builder
    builder_init(&sb); defer builder_destroy(&sb)
    _write_object(&sb, PackageHeader{MAGIC, VERSION})
}

_write_object :: proc(builder: strings.Builder, obj: $T) {
    obj := obj
    strings.write_bytes(builder, (transmute([size_of(T)]u8)obj)[:])
}


PackageHeader :: struct {
    magic : u32,
    version : u32,
}
BlockHeader :: struct {
    type : BlockType,
    info : u32,
    from, to: u32,
}
BlockType :: enum u32 {
    Data,   // `info` is not used.
    Array,  // `info` is count.
}

MAGIC :u32: 0xbeacea01
VERSION :u32: 1

// @private
// MAGIC :string: "DPAC"

DoveGameAssets :: struct {
    logo : AssetTexture `dpac:"res/logo.png"`,
    using player : PlayerAssets,
    postfx : AssetShader `dpac:"res/postfx.vert, res/postfx.frag"`,
    bgmusic : AssetShader `dpac:"hotel_california.wav"`,
}

PlayerAssets :: struct {
    player_idle : []AssetTexture `dpac:"res/player_idle_$(idx).png"`,
    player_run : []AssetTexture `dpac:"res/player_run_$(idx).png"`,
}

pac_loader :: proc(asset: ^$T, data: []u8) {
}

AssetTexture :: struct {
    id : u32,
    size : [2]i32,
    channel : i32,
}
AssetShader :: distinct u32
AssetAudio :: distinct u32 // Not done yet