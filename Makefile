TEXMFHOME = $(shell kpsewhich -var-value=TEXMFHOME)
INSTALL_DIR = $(TEXMFHOME)/tex/latex/luaharfbuzz
CONTENT= harfbuzz.sty $(wildcard *.lua) 

all: hb_paths.lua

hb_paths.lua: make_paths

make_paths:
	texlua hb_make_paths.lua > hb_paths.lua

install: $(CONTENT)
	mkdir -p $(INSTALL_DIR)
	cp $(CONTENT) $(INSTALL_DIR)
