TEXMFHOME = $(shell kpsewhich -var-value=TEXMFHOME)
INSTALL_DIR = $(TEXMFHOME)/tex/latex/luaharfbuzz
CONTENT= harfbuzz.sty $(wildcard *.lua) 

all: 

hb_paths.lua: make_paths

make_paths:
	texlua hb_make_paths.lua > hb_paths.lua

install: $(CONTENT) hb_paths.lua
	mkdir -p $(INSTALL_DIR)
	cp $(CONTENT) $(INSTALL_DIR)

examples: $(CONTENT)
	cd examples && lualatex newsample.tex
	cd examples && lualatex ahoj.tex
	cd examples && lualatex amiri-sample.tex
	cd examples && lualatex scripts.tex
	cd examples && lualatex kerning.tex


clean:
	rm examples/*.aux
	rm examples/*.log
