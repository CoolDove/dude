debug:
	odin build ./src -resource:app.rc -out:game.exe -debug
release:
	odin build ./src -resource:app.rc -out:game.exe -subsystem:windows

clean:
	rm zeno.exe zeno.pdb

cody:
	@cody -direxclude ./src/dude/vendor -q
