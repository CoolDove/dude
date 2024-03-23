# Maybe a self use game framework.

## How to build
Run `make debug` or `make release` (maybe you need MSYS2 on windows).

## FIXME
- [x] Cannot build debug, why? (dont know the reason, but it disapears when you use -thread-count:1 with -debug)
- [ ] When quit the game, a win32 exception is thrown (maybe something is wrong while releasing).

## TODO
- [x] **The memory explodes after loading audio clips from bytes, fix this!**
- [x] Draw immediate text
- [x] Remove useless RObjs.
- [x] Replace imgui with microui
    - [ ] Microui polish
        - [x] scissor
        - [ ] text input
- [x]*Multi line text rendering.
- [ ] Text rendering: Query closet fixed size from fontstash (8, 16, 32, 64, 128) (to not put too much glyphs with different sizes into the atlas)

- [x] module: imdraw
- [ ]*module: render
- [ ] module: coordinate
- [...] audio system
- [ ] animation system

- [...] DPackage
    - [ ] More asset type: 
        - [x] font
        - [ ] shader
        - [x] audio
    - [ ] endian handling
    - [ ] put the default loading handler in a right place.

- [x] Refactor resource loading and asset packaging.
~~- [ ]*Replace SDL2 with glfw.~~

- [ ] Tween for colors and quaternions.
- [ ] Try to use OpenGL 3.3