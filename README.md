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
lot of really hard work and complex scripts such as Arabic doesn't
seem to be supported fully. 

## Usage
    
    \documentclass{article}
    
    \usepackage{harfbuzz}
    \begin{document}
    
    \startharfbuzz
    
    
    \font\libertine={Linux Libertine O} at 12pt
    \libertine
    \SetFontOption{features}{}
    Normal text with Libertine: finance, grafika, 2015, 1/2
    
    \SetFontOption{features}{+zero}
    
    Zero: 2015
    
    \SetFontOption{features}{+onum,+dlig,+hist,+swsh}
    Oldstyle: 2015
    
    
    \SetFontOption{features}{+frac}
    Fractions: 1/2, 1/4
    
    \SetFontOption{features}{+smcp}
    
    Hello world

    \end{document}

![Resulting document](http://i.imgur.com/74U0JNn.png?1)

Fonts are loaded Plain TeX way, with `\font\fontname= {System font name} at
size`. Classical `Type1` fonts are supported, but without any text shaping,
obviously. To enable text shaping, use `\startharfbuzz`, to stop it, use
`\stopharfbuzz`.

You can set harfbuzz options with `\SetFontOption`, most useful options are
`features`, `script` and `language`. All values must be valid OpenType names.

Results of `examples/scripts.tex`:

![Complex scripts](http://i.imgur.com/mvxGNYJ.png)


## Questions and issues

- harfbuzz does lookup only for system fonts, not fonts installed with TeX
- does hyphenation work on ligatured words? can we get ligature components from
  Harbuzz?
- what about node attributes? 
- how to support bidi? Is it better to use direction, or to build node lists by
  hand? harfbuzz can return characters in correct order for RTL text
- how to support complex scripts such as Arabic, where glyphs depends even on
  things like line start/end, hyphenation, etc.? 
- why some fonts fail completely? For example Gentium with OpenType features,
  or Amiri for Arabic
- `pdffonts` command reports this error message on `examples/scripts.pdf`:

    $ Syntax Error (103800): Dictionary key must be a name object
    Syntax Error (103834): Dictionary key must be a name object
    Syntax Error (103858): Dictionary key must be a name object
    Syntax Error (104209): Dictionary key must be a name object
    Syntax Error (104241): Dictionary key must be a name object
    Syntax Error (104253): Dictionary key must be a name object


  I have no idea what it means
