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

# LaTeX font selection commands

You can define font families which can be used in standard LaTeX commands such
as `\textit`, `\textbf` or `\textsc`. The commands are:

    \MainFamily[font options]{font name}
    \SansFamily[font options]{font name}
    \MonoFamily[font options]{font name}

example:


    \documentclass{article}
    \usepackage{harfbuzz}
    \MainFamily[script=latn;+onum;]{TeX Gyre Termes}
    \MonoFamily{Inconsolatazi4}
    
    \begin{document}
    \section{Section}
    Ligatures: finance 12345 \textit{diacritics: příliš} {\itshape font switch} 
    \textsc{Small caps} \textit{\textbf{bold italic} italic} \texttt{monospace}
    
    \begin{verbatim}
      for k,v in ipairs(t) do print(k,v) end
    \end{verbatim}
    
    \[ \frac{\sqrt{a^2 +b ^ 2}}{c^2} \]
    \end{document}

![Result](http://i.imgur.com/wZJTZqW.png)

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

- Hyphenation works, except for ligatures. We need to investigate how to detect
  ligatures and how to create discretionaries needed by LuaTeX in order to
  enable hyphenation 
- kerning seems to work
- complex scripts such as Arabic seems to work, even Urdu
- how to handle font expansion and protrusion?
