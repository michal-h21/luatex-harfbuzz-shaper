local M =  {}
local harfbuzz = require "justenoughharfbuzz"
local usedfonts = {}

M.options = {font =  "TeX Gyre Termes", weight = 200,script = "", direction = "LTR", language = "en", size = 10, features = "+liga", variant = "normal"}
-- this is a little bit modified callback from:
-- http://wiki.luatex.org/index.php/Use_a_TrueType_font
luatexbase.add_to_callback("define_font",
  function(name, size)
    -- first detect whether the font is tfm or vf file. harfbuzz always loads
    -- some fallback font, so we must filter them in advance
    if kpse.find_file(name,"tfm") or kpse.find_file(name,"ofm") then
      return font.read_tfm(name,size)
    elseif kpse.find_file(name,"vf") or kpse.find_file(name,"ovf") then
      return font.read_vf(name,size)
    end
    local fonttype, f
    local options = {}
    for k,v in pairs(M.options) do--{font = name}
      options[k] = v
    end
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
      -- this can't happen in reality, because some OpenType font is always
      -- loaded at this point 
      f = font.read_tfm(name, size)
    end
  return f
  end, "custom fontloader")

local utfchar =  function(x)
  -- print(x)
  return unicode.utf8.char(x) or x
end

-- helper function to get font options and font face
M.get_font = function(fontid)
  local fontoptions = usedfonts[fontid] or font.fonts[fontid]
  usedfonts[fontid] = fontoptions
  local face = fontoptions.face
  return fontoptions,face
end

local current_options = nil
-- set Harfbuzz options for a font
M.set_font_option = function(name, value)
  current_options = current_options or {}
  current_options[name] = value
end

M.save_options = function(fontid)
  if current_options then
    local current_font = M.get_font(fontid)
    local options = current_font.options or {}
    for k,v in pairs(current_options) do
      options[k] = v
    end
    current_options = nil
    current_font.options = options
  end
end


  -- nodeoptions are options for glyph nodes
-- options are for harfbuzz
M.make_nodes = function(text, nodeoptions, options)
  local nodeoptions = nodeoptions or {}
  local fontid = nodeoptions.font
  local fontoptions, face = M.get_font(fontid)
  if not face then return {} end
  -- for k,v in pairs(options) do print("option",k,v) end;
  local result = {
    harfbuzz._shape(text,face,options.script, options.direction,
      options.language, options.size, options.features)
  }
  local nodetable = {}
  for _, v in ipairs(result) do
    -- character from backmap is sometimes too big for unicode.utf8.char
    -- print("hf",v.name) -- , utfchar(fontoptions.backmap[v.codepoint]))
    local n = node.new(37)
    --n.font = fontid
    --n.lang = language
    -- set node properties
    for k,j in pairs(nodeoptions) do
      n[k] = j
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


-- process_nodes callback can be called multiple times on the same head,
-- we should allow the processing only for some cases, which are enabled in
-- processed_groupcodes table
-- process only main vertical list by default
M.processed_groupcodes = {[""]=true}
M.process_nodes = function(head,groupcode) 
  local newhead_table = {}
  local current_text = {}
  local current_node = {}
  local direction 
  local proc_groupcodes = M.processed_groupcodes
  if not proc_groupcodes[groupcode] then
    return head
  end
  local insert_node = function(curr_node)
    newhead_table[#newhead_table + 1] = curr_node
  end
  local table_reverse = function(t)
    local n = {}
    for i = #t, 1, -1 do
      n[#n+1]=t[i]
    end
    return n
  end
  local build_text = function() 
    if #current_text > 0 then
      local text = table.concat(current_text)
      -- print("callback text",text)
    -- reset current_text
      --table.insert(newhead_table, M.make_nodes(text, current_text.font, current_text.lang,M.options))
      local current_font = current_text.font
      local options = M.get_font(current_font).options
      local newtext = M.make_nodes(text, {font = current_font, lang= current_text.lang},options)
      -- fix for fonts with RTL direction and textdirection of TRT
      if options.direction == "RTL" and direction == "TRT" then      
        -- text is double reversed, we must reverse it back
        newtext = table_reverse(newtext)
      end
      insert_node(newtext)
    end
    current_text = {}
  end
  for n in node.traverse(head) do
    current_node = node.copy(n)
    if n.id ==37 then
      M.save_options(n.font)
      local _,face = M.get_font(n.font)
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
      direction = n.dir
      local newhead = M.process_nodes(n.head,"")
      local newhlist = node.copy_list(n)
      newhlist.dir = n.dir
      newhlist.head = newhead
      insert_node(newhlist)
    else
      build_text()
      insert_node(n)
    end
  end
  build_text()
  -- make new node list from newhead_table
  if #newhead_table > 0 then
    -- local newhead = newhead_table[1]
    local newhead
    local function process_newhead(nodes, newhead)
      local newhead = newhead
      -- process table with nodes and insert them to a new node list
      for _, n in ipairs(nodes) do
        -- if n is table, it contains glyph nodes which needs to be 
        -- inserted to the node list
        if type(n) == "table" then
           -- print "newhead table"
          newhead = process_newhead(n,newhead)
        else
          if not newhead then 
             -- print("No newhead", n.id)
            newhead = node.copy(n)
          else
            -- print("node insert",n.id, utfchar(n.char or 0))
            -- why not node.copy? it breaks pardir. why? don't know.
            -- node.insert_after(newhead, node.tail(newhead), node.copy(n))
            node.insert_after(newhead, node.tail(newhead), (n))
          end
        end
      end
      return newhead
    end
    -- process it only when we have any nodes
    -- new head of returned node list
    -- we don't need first node anymore
    -- table.remove(newhead_table,1)
    newhead = process_newhead(newhead_table)
    -- node.flush_list(head)
    -- print "return newhead"
    return newhead
  end
  return head
end


return M
