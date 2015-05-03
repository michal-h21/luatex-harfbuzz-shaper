# LuaTeX Harfbuzz shaper

you need Lua bindings for Harfbuzz library, which is distributed with [SILE](http://www.sile-typesetter.org/index.html). 

You need to build SILE first, see the [instructions](https://github.com/simoncozens/sile#getting-and-installing). After SILE build, copy the file

    path to sile/core/justenoughharfbuzz.so

to directory with this library. In order to run example file, `ahoj.tex`, you
need to install
[Siddhanta](http://svayambhava.blogspot.cz/p/siddhanta-devanagariunicode-open-type.html) 
and [Amiri](http://www.amirifont.org/)
typefaces.

## About

This is just a proof of concept of using Harfbuzz library with LuaLaTeX.
Context and Luaotfload tries to do glyph shaping with Lua functions, but it is
lot of really hard work and complex scripts such as Indic or Arabic doesn't
seem to be supported fully. 

Some simple node callback function, `hf_fontload.process_nodes`, is provided.
See `ahoj.tex` for usage.

## Questions and issues

- harfbuzz does lookup only for system fonts, not fonts installed with TeX
- does hyphenation work on ligatured words? can we get ligature components from
  Harbuzz?
- what about node attributes? 
- how to support bidi? Is it better to use direction, or to build node lists by
  hand? harfbuzz can return characters in correct order for RTL text
- how to support complex scripts such as Arabic, where glyphs depends even on
  things like line start/end, hyphenation, etc.?
- how does Sile support OpenType features? I can't get it to work.
