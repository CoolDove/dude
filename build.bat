@robocopy res/ bin/res/ /e /NFL /NDL /NJH /NJS /np
@echo #res dir copied

@echo #build lib
@pushd %~dp0foreign\screenshit
@call ./build_lib.bat
@popd

@echo #build package main
@mkdir bin
@odin build ./src/ -out:bin/sdl.exe -collection:foreign=./foreign/ -collection:pac=./pac/
