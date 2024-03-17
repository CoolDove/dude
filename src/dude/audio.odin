package dude

import "core:runtime"
import "core:log"
import "core:strings"
import ma "vendor:miniaudio"

AudioEngine :: struct {
    engine : ma.engine,
    fence : ma.fence,
}

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

// TODO: Audio clip loading with custom flags like Stream, Async, Decode ...
audio_load :: proc(path: string, clip: ^AudioClip) {
    using audio_engine
    cpath := strings.clone_to_cstring(path, context.temp_allocator)
    if ma.sound_init_from_file(&engine, cpath, 0, nil, nil, &clip.sound) != .SUCCESS {
        log.errorf("AudioLoad: Failed to load clip: {}", path)
    }
}

audio_unload :: proc(clip: ^AudioClip) {
    ma.sound_uninit(&clip.sound)
}