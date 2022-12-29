ODIN = odin
CC   = cl
LINK = lib
MAKE = nmake

TOOLS_DIR = D:\softw\msys2\usr\bin\

PROGRAM_NAME = MillionUV

OUTPUT_PATH = .\bin
ODIN_SOURCE = .\src

ODIN_COLLECTIONS = "-collection:pac=.\pac\"
ODIN_DEBUG_FLAGS = -debug
ODIN_RELEASE_FLAGS = -no-bounds-check -subsystem:windows -o:speed

ASSIMP_LIB_DIR = .\pac\assimp\lib
ASSIMP_DDL_NAME = assimp-vc143-mt.dll
ASSIMP_DDL_NAME_DEBUG = assimp-vc143-mtd.dll

all: program

program: debug release
	@echo "[ PROGRAME BUILDED ]"

imgui:
	cd pac\imgui\

	$(MAKE) cimgui_lib
	cd ..\..\

imgui_clean:
	cd pac\imgui\

	$(MAKE) cimgui_clean
	cd ..\..\

debug: prebuild_debug
	@echo "[ BUILD DEBUG VERSION ]"
	$(TOOLS_DIR)\mkdir -p "$(OUTPUT_PATH)\debug"
	$(ODIN) build $(ODIN_SOURCE) -out:$(OUTPUT_PATH)\debug\$(PROGRAM_NAME).exe $(ODIN_COLLECTIONS) $(ODIN_DEBUG_FLAGS)

release: prebuild_release
	@echo "[ BUILD RELEASE VERSION ]"
	$(TOOLS_DIR)\mkdir -p "$(OUTPUT_PATH)\release"
	$(ODIN) build $(ODIN_SOURCE) -out:$(OUTPUT_PATH)\release\$(PROGRAM_NAME).exe $(ODIN_COLLECTIONS) $(ODIN_RELEASE_FLAGS)

prebuild: prebuild_debug prebuild_release

prebuild_release:
	@echo "[ PREBUILD RELEASE ]"
	- robocopy $(ASSIMP_LIB_DIR) bin/release $(ASSIMP_DDL_NAME) /NJS /NJH
	@echo "Release DLL copied."

prebuild_debug:
	@echo "[ PREBUILD DEBUG ]"
	- robocopy $(ASSIMP_LIB_DIR) bin/debug   $(ASSIMP_DDL_NAME_DEBUG) /NJS /NJH
	@echo "Debug DLL copied."

clean:
	@echo "[ CLEAN ]"
	$(TOOLS_DIR)\rm -r -f .\bin