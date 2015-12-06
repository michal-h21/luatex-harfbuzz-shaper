all: hb_paths.lua

hb_paths.lua: make_paths

make_paths:
	texlua hb_make_paths.lua > hb_paths.lua
