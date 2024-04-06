# Maybe a self use game framework.

## How to build
Run `make debug` or `make release` (maybe you need MSYS2 on windows).

## FIXME
- [x] Cannot build debug, why? (dont know the reason, but it disapears when you use -thread-count:1 with -debug)
- [x] When quit the game, a win32 exception is thrown (maybe something is wrong while releasing).

- [...] DPackage
    - [x] Endian safety!
        - [x] Package header
        - [x] Block header
    - [ ] More asset type: 
        - [x] font
        - [ ] shader
        - [x] audio
    - [x] endian handling
    - [ ] put the default loading handler in a right place.

- [x] **The memory explodes after loading audio clips from bytes, fix this!**
- [x] Draw immediate text
- [x] Remove useless RObjs.
- [x] Replace imgui with microui
    - [x] Microui polish
        - [x] scissor
        - [x] text input
- [x]*Multi line text rendering.
- [x] Text rendering: Query closet fixed size from fontstash (8, 16, 32, 64, 128) (to not put too much glyphs with different sizes into the atlas)

- [x] module: imdraw
- [x]*module: render
- [...] audio system (not good actually).
- [ ] animation system

- [x] Refactor resource loading and asset packaging.
~~- [ ]*Replace SDL2 with glfw.~~