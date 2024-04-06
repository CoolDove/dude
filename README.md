# Maybe a self use game framework.

## How to start
Just clone the repository into your project and `import`. You got different modules:
### dude/core
The functions to create a window and initialize your game or application. You can get access to 
some basic properties like window width, frame delta time etc in this. There're also some basic types 
and some utility processes.

### dude/render
To put something in the render pass (a render queue). You can get different pass rendered one by 
one. Each pass is bound to a camera and a render target.

Just `render.pass_init(&the_pass)` and then `append(&game.render_pass, &the_pass)`, it'll be rendered 
every frame.

### dude/imdraw
Immediate draw, they're in different style with `render` module. But they share the same render queue.
You can specify the `order` to mix them with elements that are added by `render` api. But all the 
immediate elements will be removed after drawn.

### dude/input
Handle input.

### dude/tween
A tween library. There's a default `tweener`(which is a manager of tweens) you can access by `core.get_global_tweener()`. 
You can also manually create a `Tweener` and call the `tweener_update()` somewhere you like.

### dude/dpac
A game asset packaging tool. You just define a struct, and tag the fields with `dpac` to specify the 
asset's path. Then call `dpac.bundle()`, all the resources will be bundled in to a single file. Extract 
the file into the same struct with `dpac.load()`.

### dude/microui
Microui that have some modifications, use this instead of Odin's `vendor:microui`.

### dude/collections/...
Some collections used in the dude.


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