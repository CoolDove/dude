package main


DATA_ERROR :: []u8{0xab, 0xcd, 0xef}

DATA_IMG_BOX  :: #load("../res/texture/box.png")        or_else DATA_ERROR
DATA_IMG_ICON :: #load("../res/texture/walk_icon.png")  or_else DATA_ERROR


DATA_MOD_MUSHROOM_FBX :: #load("../res/model/mushroom.fbx") or_else DATA_ERROR