package dude

import "core:runtime"
import "core:log"
import "core:strings"
import ma "vendor:miniaudio"

// NOTE: 
// The audio system is not good to use. Still needs much more modification during
//  usage.

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
    decoder : ma.decoder,
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

audio_clip_load_from_mem :: proc(data: []u8, clip: ^AudioClip, flags: AudioClipLoadFlags={}) {
    using audio_engine
    decoder_cfg := ma.decoder_config_init_default()
    ma.decoder_init_memory(raw_data(data), len(data), &decoder_cfg, &clip.decoder)
    
    flags :u32= cast(u32)(transmute(u8)flags)
    if ma.sound_init_from_data_source(&engine, auto_cast &clip.decoder, flags, nil, &clip.sound) != .SUCCESS {
        log.errorf("Failed to init audio clip from data source")
    }
    return
}

audio_clip_set_frame :: proc(clip: ^AudioClip, target_frame: u64) {
    ma.decoder_seek_to_pcm_frame(&clip.decoder, target_frame)
}


audio_clip_unload :: proc(clip: ^AudioClip) {
    ma.sound_uninit(&clip.sound)
    ma.decoder_uninit(&clip.decoder)
}