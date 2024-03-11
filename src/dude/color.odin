package dude

@(private="file")
_COLORS :: struct { 
    RED,
    GREEN,
    BLUE,

    WHITE,
    GRAY,
    BLACK : Color,
}

COLORS :: _COLORS {
    Color {1, 0, 0, 1},
    Color {0, 1, 0, 1},
    Color {0, 0, 1, 1},

    Color {1, 1, 1, 1},
    Color {.5, .5, .5, 1},
    Color {0, 0, 0, 1},
}

COL32_WHITE :Color32: {255,255,255,255}
COL32_BLACK :Color32: {0,0,0,255}
COL32_RED :Color32: {255,0,0,255}
COL32_BLUE :Color32: {0,0,255,255}
COL32_GREEN :Color32: {0,255,0,255}