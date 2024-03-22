debug:
	odin build ./src -out:game.exe -debug --thread-count:1
release:
	odin build ./src -resource:app.rc -out:game.exe -subsystem:windows

clean:
	rm game.exe game.pdb

cody:
	@cody -direxclude ./src/dude/vendor -q
