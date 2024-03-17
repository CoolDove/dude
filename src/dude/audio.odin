package dude

import "core:runtime"
import "core:log"
import "core:strings"
import ma "vendor:miniaudio"

AudioEngine :: struct {
    engine : ma.engine,
    device : ma.device,
    resmgr : ma.resource_manager,
    source : ma.resource_manager_data_source,
}

@private
audio_engine : AudioEngine

@private
audio_init :: proc() {
    using audio_engine
    ma.engine_init(nil, &engine)
    
    device_cfg := ma.device_config_init(.playback)
    device_cfg.dataCallback = device_data_callback
    device_cfg.pUserData = &source
    if ma.device_init(nil, &device_cfg, &device) != .SUCCESS {
        panic("Failed to initialize miniaudio device.")
    }
    resmgr_cfg := ma.resource_manager_config_init()
    resmgr_cfg.decodedFormat     = device.playback.playback_format
    resmgr_cfg.decodedChannels   = device.playback.channels
    resmgr_cfg.decodedSampleRate = device.sampleRate
    
    if ma.resource_manager_init(&resmgr_cfg, &resmgr) != .SUCCESS {
        ma.device_uninit(&device)
        panic("Failed to initialize miniaudio resource manager.")
    }
}

@(private="file")
device_data_callback :: proc "c" (device: ^ma.device, output, input: rawptr, frame_count: u32) {
    context = runtime.default_context()
    log.debugf("read pcm frame")
    ma.data_source_read_pcm_frames(cast(^ma.data_source)device.pUserData, output, auto_cast frame_count, nil)
}

audio_play :: proc(path: string) {
    log.debugf("AudioPlay: audio play")
    using audio_engine
    cpath := strings.clone_to_cstring(path, context.temp_allocator)
    log.debugf("AudioPlay: data source starts to load.")
    ma.resource_manager_data_source_init(&resmgr, cpath,
        cast(u32)(ma.sound_flags.STREAM | ma.sound_flags.DECODE | ma.sound_flags.ASYNC),
        nil,
        &source)
    log.debugf("AudioPlay: data source loaded.")
    if ma.device_start(&device) != .SUCCESS {
        log.debugf("AudioPlay: failed to start device.")
    }
}

@private
audio_release :: proc() {
    using audio_engine
    ma.resource_manager_uninit(&resmgr)
    ma.device_uninit(&device)
    ma.engine_uninit(&engine)
}