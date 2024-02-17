debug:
	odin build ./src/ -resource:app.rc -out:dude.exe -debug
release:
	odin build ./src/ -resource:app.rc -out:zeno.exe -subsystem:windows

run:
	./zeno.exe

clean:
	rm zeno.exe zeno.pdb
