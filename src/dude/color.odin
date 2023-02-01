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