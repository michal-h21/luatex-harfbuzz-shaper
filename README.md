# LuaTeX Harfbuzz shaper

You need to install [Luaharfbuzz](https://github.com/deepakjois/luaharfbuzz)
first. It  is best to use `luarocks` option, as we can load it directly. 


Run `make` to set correct paths in which `luaharfbuzz` will be searched. 

## About

This is just a proof of concept of using Harfbuzz library with LuaLaTeX.
Context and Luaotfload tries to do glyph shaping with Lua functions, but it is
lot of really hard work and complex scripts such as Arabic doesn't
seem to be supported fully. 

## Usage
    

    \documentclass{article}

    \usepackage{harfbuzz}
    \begin{document}



    \font\libertine={Linux Libertine O} at 12pt
    \libertine
    \SetFontOption{features}{}
    Normal text with Libertine: finance, grafika, 2015, 1/2

    \SetFontOption{features}{+zero}

    Zero: 2015

    \SetFontOption{features}{+onum}
    Oldstyle: 2015


    \SetFontOption{features}{+frac}
    Fractions: 1/2, 1/4

    \SetFontOption{features}{+smcp}

    Hello world

    \font\italic={Linux Libertine O/I} at 12pt

    \italic Text in italic font

    \font\arabic={amiri:script=arab;language=ara} at 12pt

    \libertine 
    \SetFontOption{features}{}
    Arabic text

    {\pardir TRT \textdir TRT
    \arabic ﻢﻗﺎﻟﺓ ﺎﻠﻳﻮﻣ ﺎﻠﻤﺨﺗﺍﺭﺓ}

   

    Kerning and features: VLTAVA finance

    \stopharfbuzz Without shaping: VLTAVA finance

    \end{document}

![Resulting document](http://i.imgur.com/bp8IfKH.png)

Fonts are loaded using `Luaotfload` libraries, which means that you can use
fonts in both your system font directories and in TeX tree. Also, `Luatfload` syntax
`\font\fontname= {System font name/Style:features} at size` is supported.
Classical `tfm` and `vf` fonts are supported, but without any text shaping,
obviously. To enable text shaping, use `\startharfbuzz`, to stop it, use
`\stopharfbuzz`. Shaping is enabled by default.

You can set harfbuzz options with `\SetFontOption`, most useful options are
`features`, `script` and `language`. All values must be valid OpenType names.

See files in `examples` directory for various examples of usage.

## Questions and issues

- hyphenation seems to work, but words are hyphenated before processing with
  Harfbuzz. Because only directly following glyph nodes are aaken as words,
  actual word may be broken into several chunks for Harbuzz processing. It
  probably isn't problem for latin typefaces, but what about complex scripts?
- what about kerning? 
- how to support complex scripts such as Arabic, where glyphs depends even on
  things like line start/end, hyphenation, etc.? Basic Arabic processing seems
  to work.
- `pdffonts` command reports this error message on `examples/scripts.pdf`:

        $ Syntax Error (103800): Dictionary key must be a name object
        Syntax Error (103834): Dictionary key must be a name object
        Syntax Error (103858): Dictionary key must be a name object
        Syntax Error (104209): Dictionary key must be a name object
        Syntax Error (104241): Dictionary key must be a name object
        Syntax Error (104253): Dictionary key must be a name object


  I have no idea what it means
