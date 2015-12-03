local M =  {}
local harfbuzz = require "justenoughharfbuzz"
local usedfonts = {}

M.options = {font =  "TeX Gyre Termes", weight = 200,script = "", direction = "LTR", language = "en", size = 10, features = "+liga", variant = "normal"}


local utfchar =  function(x)
  -- print(x)
  return unicode.utf8.char(x) or x
end

-- helper function to get font options and font face
M.get_font = function(fontid)
  local fontoptions = usedfonts[fontid] or font.fonts[fontid] or {}
  usedfonts[fontid] = fontoptions
  -- we no longer use face, it is in spec.data now
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



local function shape(text,specification, dir, size)
  local feat = specification.features
  local script = feat.script
  local direction = dir
  -- direction = "LTR"
  local lang = feat.language
  local size = size
  local f = {}
  for k,v in pairs(feat) do
    if v == true then
      table.insert(f, "+"..k)
    end
  end
  local features = table.concat(f, ";")
  print( script, direction, lang, features)
  return {harfbuzz._shape(text,specification.data, 0,  script, direction, lang, size, features)}
end
  -- nodeoptions are options for glyph nodes
-- options are for harfbuzz
M.make_nodes = function(text, nodeoptions, options)
  local nodeoptions = nodeoptions or {}
  local fontid = nodeoptions.font
  local direction = options.direction
  local fontoptions = M.get_font(fontid)
  local size = fontoptions.size
  -- if not face then return {} end
  local spec = fontoptions.spec
  -- for k,v in pairs(options) do print("option",k,v) end;
  local result = shape(text, spec,direction, size)
  -- local result = {
  --   harfbuzz._shape(text,face,options.script, options.direction,
  --     options.language, options.size, options.features)
  -- }
  local nodetable = {}
  for _, v in ipairs(result) do
    -- character from backmap is sometimes too big for unicode.utf8.char
    -- print("hf",v.name) -- , utfchar(fontoptions.backmap[v.codepoint]))
    local n
    local char =  fontoptions.backmap[v.codepoint]
    n = node.new(37)
    --n.font = fontid
    --n.lang = language
    -- set node properties
    for k,j in pairs(nodeoptions) do
      n[k] = j
    end
    n.char = char
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
  -- directions are handled as stack
  local dir_stack = {tex.textdir}
  local handle_dir = function(dir)
    local operator, dir = dir:match "(.)(.-)"
    if operator  == "+" then
      table.insert(dir_stack, dir)
    elseif operator == "-" then
      table.remove(dir_stack)
    end
  end
  -- return current value of dir_stack
  local current_dir = function() return dir_stack[#dir_stack] end
  local convert_dir =  function(dir)
    -- map LuaTeX directions to OT directions
    local directions = {TLT = "LTR", TRT = "RTL", RTT = "TTB"}
    return directions[dir] or dir
  end
  local direction --= convert_dir(tex.textdir)
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
      local direction = current_dir()
      local options = M.get_font(current_font).options
      options.direction = convert_dir(direction)
      local nodeoptions = {
        font = current_font, 
        lang= current_text.lang, 
        subtype= 1
      }
      local newtext = M.make_nodes(text,nodeoptions ,options)
      -- fix for fonts with RTL direction and textdirection of TRT
      if options.direction == "RTL" and direction == "TRT" then      
        -- text is double reversed, we must reverse it back
        -- newtext = table_reverse(newtext)
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
    -- elseif n.id == 10 and  n.subtype == 0 then
      -- current_text[#current_text + 1] = " "
    elseif n.id == 0 or n.id == 1 then
      -- hlist and vlist nodes
      build_text()
      direction = n.dir
      local newhead = M.process_nodes(n.head,"")
      local newhlist = node.copy_list(n)
      newhlist.dir = n.dir
      newhlist.head = newhead
      insert_node(newhlist)
    elseif n.id == 7 and (n.subtype == 3 or n.subtype == 4 or n.subtype == 5) then
      -- print("Hypen", n.subtype)
    else
      build_text()
      -- handle dir whatsits
      if n.id == 8 and n.subtype == 7 then handle_dir(n.dir) end
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
    lang.hyphenate(newhead)
    node.kerning(newhead)
    -- node.flush_list(head)
    -- print "return newhead"
    return newhead
  end
  return head
end


return M