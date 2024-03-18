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

audio_clip_unload :: proc(clip: ^AudioClip) {
    ma.sound_uninit(&clip.sound)
}