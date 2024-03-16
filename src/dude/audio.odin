package dude

import ma "vendor:miniaudio"

@(private="file")
ma_engine : ma.engine

@private
audio_init :: proc() {
    cfg : ma.engine_config
    ma.engine_init(nil, &ma_engine)
}

audio_play :: proc() {
    ma.engine_play_sound(&ma_engine, "./res/sfx/test.wav", nil)
}


@private
audio_release :: proc() {
    ma.engine_uninit(&ma_engine)
}