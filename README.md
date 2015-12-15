# LuaTeX Harfbuzz shaper

You need to install [Luaharfbuzz](https://github.com/deepakjois/luaharfbuzz)
first. It  is best to use `luarocks` option, as we can load it directly. 


Run `make install` to set correct paths in which `luaharfbuzz` will be
searched. The library will be installed in yout local TEXMF tree.

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

    Hello world in small caps

    \font\italic={Linux Libertine O/I} at 12pt

    \italic Text in italic font

    \font\arabic={amiri:script=arab;language=ara} at 12pt

    \libertine 
    \SetFontOption{features}{}
    Arabic text

    {\pardir TRT \textdir TRT
    \arabic مقالة اليوم المختارة}

   

    Kerning and features: VLTAVA finance

    \stopharfbuzz Without shaping: VLTAVA finance

    \end{document}

![Resulting document](http://i.imgur.com/kZFsEzt.png)

Fonts are loaded using `Luaotfload` libraries, which means that you can use
fonts in both your system font directories and in TeX tree. Also, `Luatfload` syntax
`\font\fontname= {System font name/Style:features} at size` is supported.
Classical `tfm` and `vf` fonts are supported, but without any text shaping,
obviously. To enable text shaping, use `\startharfbuzz`, to stop it, use
`\stopharfbuzz`. Shaping is enabled by default.

You can set harfbuzz options with `\SetFontOption`, most useful options are
`features`, `script` and `language`. All values must be valid OpenType names.

For missing glyph substitution, use `\SetFontSubstitute`. It has two
parameters, first is script, for which font should be used, second is font to
be used.

`\SetFontOption` and `\SetFontSubstitute` must be used when the configured font is used, it means not directly after declaration with `\font`, but 
after it is really used in the document:


    \documentclass{article}
    \usepackage{harfbuzz}
    \font\latin={TeX Gyre Schola} at 18pt
    \font\noto={Noto Nastaliq Urdu:script=arab;language=URD} at 18pt
    \def\textlatin#1{\bgroup\textdir TLT #1\egroup}
    \begin{document}
    \pagedir TRT \bodydir TRT \pardir TRT \textdir TRT
    
    \noto
    \SetFontSubstitute{latn}{\latin}
    پراگ (\textlatin{Prague}) چیک جمہوریہ کا
    \end{document}

See files in `examples` directory for various examples of usage.

## Questions and issues

- Hyphenation works, except for ligatures. We need to investigate how to detect
  ligatures and how to create discretionaries needed by LuaTeX in order to
  enable hyphenation 
- kerning seems to work
- complex scripts such as Arabic seems to work, even Urdu
- how to handle font expansion and protrusion?
