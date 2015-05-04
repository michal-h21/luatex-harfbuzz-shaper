local M =  {}
local harfbuzz = require "justenoughharfbuzz"
local usedfonts = {}

M.options = {font =  "TeX Gyre Termes", weight = 200,script = "", direction = "LTR", language = "en", size = 10, features = "+liga", variant = "normal"}
-- this is a little bit modified callback from:
-- http://wiki.luatex.org/index.php/Use_a_TrueType_font
luatexbase.add_to_callback("define_font",
  function(name, size)
    local fonttype, f
    local options = M.options--{font = name}
    options.font = name
    local hbfont = harfbuzz._face(options)
    f = {}
    name = hbfont.filename
    print("font file", name)
    local fonttype = string.match(string.lower(name), "otf$") and "opentype"
                  or string.match(string.lower(name), "ttf$") and "truetype"

    if fonttype then
      filename = kpse.find_file(name, "opentype fonts") or kpse.find_file(name, "truetype fonts")
      if size < 0 then
        size = (- 655.36) * size
      end
      ttffont = fontloader.to_table(fontloader.open(filename))
      if ttffont then
        f = { }
        f.name = ttffont.fontname
        f.face = hbfont.face
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
            name = glyph_table.name }
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
          version = 1 }
      end
    else
      f = font.read_tfm(name, size)
    end
  return f
  end, "custom fontloader")

local utfchar =  function(x)
  print(x)
  return unicode.utf8.char(x) or x
end

-- helper function to get font options and font face
local get_font_options = function(fontid)
  local fontoptions = usedfonts[fontid] or font.fonts[fontid]
  usedfonts[fontid] = fontoptions
  local face = fontoptions.face
  return fontoptions,face
end
-- nodeoptions are options for glyph nodes
-- options are for harfbuzz
M.make_nodes = function(text, nodeoptions, options)
  local nodeoptions = nodeoptions or {}
  local fontid = nodeoptions.font
  local fontoptions, face = get_font_options(fontid)
  if not face then return {} end
  local result = {
    harfbuzz._shape(text,face,options.script, options.direction,
      options.language, options.size, options.features)
  }
  local nodetable = {}
  for _, v in ipairs(result) do
    print("hf",v.name, utfchar(fontoptions.backmap[v.codepoint]))
    local n = node.new(37)
    --n.font = fontid
    --n.lang = language
    -- set node properties
    for k,v in pairs(nodeoptions) do
      n[k] = v
    end
    n.char = fontoptions.backmap[v.codepoint]
    --node.write(n)
    nodetable[#nodetable+1] = node.copy(n)
  end--]]
  return nodetable
end

M.write_nodes = function(nodetable)
  for _, n in ipairs(nodetable) do
    node.write(n)
  end
end

M.process_nodes = function(head) 
  local newhead_table = {}
  local current_text = {}
  local current_node = {}
  -- 
  local insert_node = function(curr_node)
    newhead_table[#newhead_table + 1] = curr_node
  end
  local build_text = function() 
    if #current_text > 0 then
      local text = table.concat(current_text)
      print("callback text",text)
    -- reset current_text
      --table.insert(newhead_table, M.make_nodes(text, current_text.font, current_text.lang,M.options))
      insert_node(M.make_nodes(text, {font = current_text.font, lang= current_text.lang},M.options))
    end
    current_text = {}
  end
  for n in node.traverse(head) do
    current_node = node.copy(n)
    if n.id ==37 then
      local _,face = get_font_options(n.font)
      -- process only fonts loaded by Harfbuzz
      if face then
        -- test for hypothetical situation that in list of succeeding glyphs
        -- are some glyphs with different font and lang
        -- can this even happen?
        if n.lang == current_text.lang and n.font == current_text.font and n.attribute == current_text.attribute then
        else
          build_text()
          current_text.font = n.font
          current_text.lang = n.lang
          current_text.attribute = n.attribute
        end
        current_text[#current_text + 1] = utfchar(n.char)
      else
        build_text()
        insert_node(n)
      end
    elseif n.id == 0 or n.id == 1 then
      -- hlist and vlist nodes
      build_text()
      insert_node(M.process_nodes(n.head))
      --n.head = M.process_nodes(n.head)
      -- node.insert_after(newhead,n.prev,n)
    else
      build_text()
      insert_node(n)
    end
  end
  build_text()
  -- make new node list from newhead_table
  if #newhead_table > 0 then
    -- process it only when we have any nodes
    -- new head of returned node list
    local newhead = newhead_table[1]
    -- we don't need first node anymore
    table.remove(newhead_table,1)
    local function process_newhead(nodes)
      -- process table with nodes and insert them to a new node list
      for _, n in ipairs(nodes) do
        -- if n is table, it contains glyph nodes which needs to be 
        -- inserted to the node list
        if type(n) == "table" then
          process_newhead(n)
        else
          node.insert_after(newhead, node.tail(newhead), n)
        end
      end
    end
    process_newhead(newhead_table)
    return newhead
  end
  return head
end
return M
