debug:
	@echo "Building with retry..."
	@while true; do \
		odin build ./src -debug -out:game.exe; \
		if [ $$? -eq 0 ]; then \
			echo "Build succeeded."; \
			break; \
		else \
			echo "Build failed. Retrying after 0.01 second..."; \
			sleep 0.01; \
		fi; \
	done
release:
	odin build ./src -resource:app.rc -out:game.exe -subsystem:windows

clean:
	rm game.exe game.pdb

cody:
	@cody -direxclude ./src/dude/vendor -q
