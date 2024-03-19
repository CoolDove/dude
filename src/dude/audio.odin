package dude

import "core:runtime"
import "core:log"
import "core:strings"
import ma "vendor:miniaudio"

AudioEngine :: struct {
    engine : ma.engine,
    fence : ma.fence,
}
AudioClipLoadFlag :: enum {
    Stream = 1<<0,/* MA_RESOURCE_MANAGER_DATA_SOURCE_FLAG_STREAM */
    Async  = 1<<1,/* MA_RESOURCE_MANAGER_DATA_SOURCE_FLAG_DECODE */
    Decode = 1<<2,/* MA_RESOURCE_MANAGER_DATA_SOURCE_FLAG_ASYNC */
}
AudioClipLoadFlags :: bit_set[AudioClipLoadFlag]

@private
audio_engine : AudioEngine

AudioClip :: struct {
    sound : ma.sound,
    buffer : ^ma.audio_buffer,
}


@private
audio_init :: proc() {
    using audio_engine
    ma.engine_init(nil, &engine)
}

@private
audio_release :: proc() {
    using audio_engine
    ma.engine_uninit(&engine)
}

audio_play :: proc(clip: ^AudioClip) {
    using audio_engine
    if ma.sound_start(&clip.sound) != .SUCCESS {
        log.errorf("AudioPlay: failed to start device.")
    }
}

audio_clip_load :: proc(path: string, clip: ^AudioClip, flags: AudioClipLoadFlags={}) {
    using audio_engine
    cpath := strings.clone_to_cstring(path, context.temp_allocator)
    flags :u32= cast(u32)(transmute(u8)flags)
    if ma.sound_init_from_file(&engine, cpath, flags, nil, nil, &clip.sound) != .SUCCESS {
        log.errorf("AudioLoad: Failed to load clip: {}", path)
    }
}
// Return decoded audio data.
audio_clip_load_from_mem :: proc(data: []u8, clip: ^AudioClip, flags: AudioClipLoadFlags={}) -> (frames:rawptr, frame_count: u64) {
    using audio_engine
    channels := ma.engine_get_channels(&engine)
    format := ma.format.f32
    decoder_cfg := ma.decoder_config_init(format, channels, 48000)
    
    decode_memory_res := ma.decode_memory(raw_data(data), len(data), &decoder_cfg, &frame_count, &frames)
    audio_buffer_cfg := ma.audio_buffer_config_init(format, channels, frame_count, frames, nil)   
    ma.audio_buffer_alloc_and_init(&audio_buffer_cfg, &clip.buffer)
    flags :u32= cast(u32)(transmute(u8)flags)
    if ma.sound_init_from_data_source(&engine, auto_cast clip.buffer, flags, nil, &clip.sound) != .SUCCESS {
        log.errorf("Failed to init audio clip from data source")
    }
    return
}

audio_clip_unload :: proc(clip: ^AudioClip) {
    ma.sound_uninit(&clip.sound)
    ma.audio_buffer_uninit_and_free(clip.buffer)
}