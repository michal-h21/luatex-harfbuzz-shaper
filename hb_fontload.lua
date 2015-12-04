-- Font loader
--
local M = {}

local find_font = require "hb_findfont"
local hb = require "harfbuzz"
local Face = hb.Face
local Font = hb.Font
-- set default parameters for tfm or vf fonts
local tfm_font_parameters = function(tfmdata)
  -- support for microtype
  -- copied from luaotfload
  local parameters = tfmdata.parameters or {}
  if not parameters.expansion then
    parameters.expansion = {
      stretch=tfmdata.stretch   or 0,
      shrink=tfmdata.shrink   or 0,
      step=tfmdata.step    or 0,
      auto=tfmdata.auto_expand or false,

    }
  end
  if not parameters.protrusion then
    parameters.protrusion={
      auto=auto_protrude
    }
  end
  tfmdata.parameters = parameters
  return tfmdata
end
-- this is a little bit modified callback from:
-- http://wiki.luatex.org/index.php/Use_a_TrueType_font
function M.loader(specification, size)
  -- first detect whether the font is tfm or vf file. harfbuzz always loads
  -- some fallback font, so we must filter them in advance
  if kpse.find_file(specification,"tfm") or kpse.find_file(specification,"ofm") then
    return tfm_font_parameters(font.read_tfm(specification,size))
  elseif kpse.find_file(specification,"vf") or kpse.find_file(specification,"ovf") then
    return tfm_font_parameters(font.read_vf(specification,size))
  end
  local fonttype, f
  local options = {}
  local path, spec = find_font.find(specification)
  -- for k,v in pairs(M.options) do--{font = name}
  --   options[k] = v
  -- end
  -- options.font = name
  -- local hbfont = harfbuzz._face(options)
  f = {}
  name = spec.filename
  print("font file", name)
  local fonttype = string.match(string.lower(name), "otf$") and "opentype" or string.match(string.lower(name), "ttf$") and "truetype"
  if fonttype then
    -- filename = kpse.find_file(name, "opentype fonts") or kpse.find_file(name, "truetype fonts")
    local filename = spec.fullpath
    if size < 0 then
      size = (- 655.36) * size
    end
    ttffont = fontloader.to_table(fontloader.open(filename))
    if ttffont then
      f = { }
      f.name = ttffont.fontname
      f.spec = spec
      if spec.fullpath then
        f.face = Face.new(spec.fullpath)
        f.hb_font = Font.new(f.face)
      end
      f.options = options
      f.fullname = ttffont.names[1].names.fullname
      f.parameters = { }
      f.designsize = size
      f.size = size
      f.direction = 0
      f.parameters.slant = 0
      f.parameters.space = size * 0.25
      f.parameters.space_stretch = 0.3 * size
      f.parameters.space_shrink = 0.1 * size
      f.parameters.x_height = 0.4 * size
      f.parameters.quad = 1.0 * size
      f.parameters.extra_space = 0
      f.characters = { }
      local mag = size / ttffont.units_per_em
      f.units_per_em = ttffont.units_per_em
      -- local utfchar = unicode.utf8.char
      local names_of_char = { }
      for char, glyph in pairs(ttffont.map.map) do
        names_of_char[ttffont.glyphs[glyph].name] = ttffont.map.backmap[glyph]
        -- print(glyph,ttffont.glyphs[glyph].name,utfchar(ttffont.map.backmap[glyph]))
      end
      -- save backmap in TeX font, so we can get char code from glyph index
      -- obtainded from Harfbuzz
      f.backmap = ttffont.map.backmap
      for char, glyph in pairs(ttffont.map.map) do
        local glyph_table = ttffont.glyphs[glyph]
        f.characters[char] = {
          index = glyph,
          width = glyph_table.width * mag,
          name = glyph_table.name,
          -- x_offset = (glyph_table.x_offset or 0) * mag,
          -- y_offset = (glyph_table.y_offset or 0) * mag,
          -- x_advance = (glyph_table.x_advance or 0) * mag,
          -- y_advance = (glyph_table.y_advance or 0) * mag,
        }
        if glyph_table.boundingbox[4] then
          f.characters[char].height = glyph_table.boundingbox[4] * mag
        end
        if glyph_table.boundingbox[2] then
          f.characters[char].depth = -glyph_table.boundingbox[2] * mag
        end
        if glyph_table.kerns then
          local kerns = { }
          for _, kern in pairs(glyph_table.kerns) do
            kerns[names_of_char[kern.char]] = kern.off * mag
          end
          f.characters[char].kerns = kerns
        end
      end
      f.filename = filename
      f.type = "real"
      f.format = fonttype
      f.embedding = "subset"
      f.cidinfo = {
        registry = "Adobe",
        ordering = "Identity",
        supplement = 0,
        version = 1 
      }
    end
  else
    -- this can't happen in reality, because some OpenType font is always
    -- loaded at this point 
    f = font.read_tfm(name, size)
  end
  return tfm_font_parameters(f)
end

return M

