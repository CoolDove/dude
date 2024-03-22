# Maybe a self use game framework.

## How to build
Run `make debug` or `make release` (maybe you need MSYS2 on windows).

## FIXME
- [ ] The audio playback sometimes accidently stops.
- [ ] When quit the game, a win32 exception is thrown (maybe something is wrong while releasing).

## TODO
- [x] Draw immediate text
- [x] Remove useless RObjs.
- [x] Replace imgui with microui
    - [ ] Microui polish
        - [x] scissor
        - [ ] text input
- [x]*Multi line text rendering.

- [x] module: imdraw
- [ ]*module: render
- [ ] module: coordinate
- [...] audio system
- [ ] animation system

- [...] DPackage
    - [ ] More asset type: 
        - [x] font
        - [ ] shader
        - [ ] audio
    - [ ] endian handling
    - [ ] put the default loading handler in a right place.

- [x] Refactor resource loading and asset packaging.
- [ ]*Replace SDL2 with glfw.

- [ ] Tween for colors and quaternions.
- [ ] Try to use OpenGL 3.3