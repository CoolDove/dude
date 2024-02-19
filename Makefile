debug:
	odin build ./src/game -resource:app.rc -out:game.exe -debug
release:
	odin build ./src/game -resource:app.rc -out:game.exe -subsystem:windows

dude-package-game:
	@odin build ./src/game -define:DUDE_STARTUP_COMMAND=PACKAGE_GAME -out:dude_package_game.exe -debug
	./dude_package_game.exe
	@rm dude_package_game.exe
dude-test:
	@odin build ./src/game -define:DUDE_STARTUP_COMMAND=TEST -out:test.exe -debug
	./test.exe
	@rm test.exe

clean:
	rm zeno.exe zeno.pdb

cody:
	@cody -direxclude ./src/dude/vendor -q
