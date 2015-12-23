local M =  {}
M.loglevel = 0
local harfbuzz = require "harfbuzz"
local Buffer = harfbuzz.Buffer
local usedfonts = {}

-- harfbuzz processing can be disabled using attributes
local luatexbase = luatexbase or {}
luatexbase.registernumber = luatexbase.registernumber or function(s) return false end
local hb_attr = luatexbase.registernumber("harfbuzzenabled")
local hb_enabled = 1
local hb_disabled = 0


M.options = {font =  "TeX Gyre Termes", weight = 200,script = "", direction = "LTR", language = "en", size = 10, features = "+liga", variant = "normal"}


local glyph_id = node.id "glyph"
local whatsit_id = node.id "whatsit"
local hlist_id = node.id "hlist"
local vlist_id = node.id "vlist"
local disc_id = node.id "disc"
local kern_id = node.id "kern"
local penalty_id = node.id "penalty"

local max_char = 0x10FFFF
local utfchar =  function(x)
  -- print(x)
  if x <= max_char then
    return unicode.utf8.char(x) or x
  else
    return " "
  end
end

local function debug(level, fn)
  if M.loglevel >= level then
    fn()
  end
end

local function log(format, ...)
  local args = table.pack(...)
  debug(1, function()
    print(string.format(format, table.unpack(args)))
  end)
end

log("harfbuzz attr no: %i", hb_attr)
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
  -- if value == "" then value = nil end
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

local feat_cache = {}
local function parse_features(feat_str)
  if feat_str == nil then return "" end
  local cached = feat_cache[feat_str]
  if cached then return cached end
  -- semicolons are used in luaotfload to separate features, harfbuzz uses commas
  local feat = feat_str:gsub(";",",")  
  feat_cache[feat_str] = feat
  return feat
end

-- different kerning functions for different directions
local kernfn = {
  ltr = function(nodetable, n, calcfield)
    local x_advance = calcfield "x_advance"
    if x_advance and math.abs(x_advance - n.width) > 1 then
      local kern = node.new "kern"
      -- this formula is good for latin text, but what about TRL
      kern.kern = (x_advance - n.width  ) 
      -- really this? I am not sure why
      nodetable[#nodetable+1] = kern
      debug(1,function()
        local char = utfchar(n.char)
        log("kern \t%s\t%i\t%i", char, n.width, x_advance)
      end)
    end
    return nodetable
  end,
  rtl = function(nodetable, n, calcfield)    
    local x_advance = calcfield "x_advance"
    if x_advance and math.abs(x_advance - n.width) > 1 then
      local kern = node.new "kern"
      kern.kern = (n.width - x_advance) * -1
      -- it seems that kerns are inserted wrongly for RTL, we must fix it
      local pos = #nodetable --- 1
      if pos < 1 then pos = 1 end
      table.insert(nodetable,pos, kern)
      debug(1,function()
        local char = utfchar(n.char)
        log("kern \t%s\t%i\t%i", char, n.width, x_advance)
      end)
    end
    return nodetable
  end,
  -- this is workn in progress
  -- and it doesn't seem to work at all
  ttb = function(nodetable, n, calcfield)
    -- local x_advance = calcfield "x_advance"
    local y_advance = calcfield "y_advance"
    local total  = ((n.height + n.depth) + y_advance) -- * -1
    local glue = node.new "glue"
    local gs = node.new "glue_spec"
    gs.width = total
    gs.stretch=total 
    gs.stretch_order=0;
    gs.shrink=0.05 * n.width
    gs.shrink_order=0;
    glue.spec = gs
    local kern = node.new "kern"
    kern.kern = total * -1
    debug(1,function()
      local char = utfchar(n.char)
      log("kern \t%s\t%i\t%i\t%i", char, n.width, x_advance, total)
    end)
    nodetable[#nodetable+1] = glue
    -- nodetable[#nodetable+1] = kern
    return nodetable
  end
}

local function shape(text,fontoptions, dir, size)
  local specification = fontoptions.spec
  local feat = specification.features
  -- options specified directly in the document, it can overwrite font options
  local docoptions = fontoptions.options 
  local script =  docoptions.script or  feat.script 
  local direction = dir 
  if direction == "" then direction = nil end
  -- direction = "LTR"
  local lang = docoptions.language or feat.language
  local size = size
  local f = {}
  -- font features passed from luaotfload
  for k,v in pairs(feat) do
    if v == true then
      table.insert(f, "+"..k)
    elseif v==false then 
      table.insert(f, "-"..k)
      -- we must remove script and language, they aren't valid features
    elseif k=="script" or k=="language" or k=="featurefile" then
    else
      table.insert(f, string.format("+%s=%s",k,v))
    end
  end
  -- features specified in \SetFontOption
  local doc_feat = parse_features(docoptions.features)
  local features = table.concat(f, ",") .. ","..doc_feat
  local buffer = Buffer.new()
  -- buffer:add_utf8(text)
  -- we got segfault when we tried to use directly text table 
  local t = {}
  for i=1, #text do t[#t+1] = text[i] end
  buffer:add_codepoints(t)
  local Font = fontoptions.hb_font
  local options = {script = script, language = language, direction = direction, features = features}
  harfbuzz.shape(Font, buffer, options)
  local newdir = buffer:get_direction()
  debug(1, function()
    local x = {}
    for i = 1,#text do x[#x+1] = utfchar(text[i]) end
    log("%s\t%s\t%s\t%s\t%s", table.concat(x), script, newdir, lang, features)
  end)
  if newdir == "rtl" or  newdir == "RTL" then
    buffer:reverse()
  end
  -- return {harfbuzz._shape(text,specification.data, 0,  script, direction, lang, size, features)}
  return buffer:get_glyph_infos_and_positions(), newdir
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
  -- for k,v in pairs(options) do print("option",k,v) end;
  local result, direction = shape(text, fontoptions,direction, size)
  -- local result = {
  --   harfbuzz._shape(text,face,options.script, options.direction,
  --     options.language, options.size, options.features)
  -- }
  local get_kern = kernfn[direction] or function(nodetable) return nodetable end
  local nodetable = {}
  for _, v in ipairs(result) do
    -- character from backmap is sometimes too big for unicode.utf8.char
    -- it is because it is often PUA
    -- print("hf",v.name) -- , utfchar(fontoptions.backmap[v.codepoint]))
    local n
    local char =  fontoptions.backmap[v.codepoint]
    n = node.new("glyph")
    --n.font = fontid
    --n.lang = language
    -- set node properties
    for k,j in pairs(nodeoptions) do
      n[k] = j
    end
    n.char = char
    local factor = 1
    if direction == "rtl" or direction == "RTL" then 
      factor = -1 
    end
    local function calc_dim(field)
      return math.floor(v[field] / fontoptions.units_per_em * fontoptions.size)
    end
    -- deal with kerning
    local x_advance = calc_dim "x_advance"
    -- width and height are set from font, we can't change them anyway
    -- n.height = calc_dim "y_advance"
    n.xoffset = (calc_dim "x_offset") * factor
    n.yoffset = calc_dim "y_offset"
    --node.write(n)
    nodetable[#nodetable+1] = node.copy(n)
    -- detect kerning
    -- we must rule out rounding errors first
    -- we skip this for top to bottom direction
    nodetable = get_kern(nodetable, n, calc_dim)
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
-- "vbox" groupcode fails. why?
M.processed_groupcodes = {[""]=true, hbox=true, adjusted_hbox=true, align_set=true, fin_row=true}
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
  -- should this be removed? This is really messy when \halligns and other stuff
  -- is involved
  local proc_groupcodes = M.processed_groupcodes
  if not proc_groupcodes[groupcode] then
    return head
  end
  local insert_node = function(curr_node)
    newhead_table[#newhead_table + 1] = curr_node
  end
  -- local table_reverse = function(t)
  --   local n = {}
  --   for i = #t, 1, -1 do
  --     n[#n+1]=t[i]
  --   end
  --   return n
  -- end
  local build_text = function() 
    if #current_text > 0 then
      -- local text = table.concat(current_text)
      local text = current_text
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
      insert_node(newtext)
    end
    current_text = {}
  end
  for n in node.traverse(head) do
    current_node = node.copy(n)
    if n.id ==glyph_id and node.has_attribute(n, hb_attr, hb_enabled)  then
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
        current_text[#current_text + 1] = n.char --utfchar(n.char)
      else
        build_text()
        insert_node(n)
      end
    -- elseif n.id == 10 and  n.subtype == 0 then
      -- current_text[#current_text + 1] = " "
    elseif n.id == hlist_id or n.id == vlist_id then
      -- hlist and vlist nodes
      build_text()
      direction = n.dir
      local newhead = M.process_nodes(n.head,"")
      local newhlist = node.copy_list(n)
      newhlist.dir = n.dir
      newhlist.head = newhead
      insert_node(newhlist)
    elseif n.id == disc_id and (n.subtype == 3 or n.subtype == 4 or n.subtype == 5) then
      -- print("Hypen", n.subtype)
      -- Ignore kerning from font
    elseif n.id == kern_id and n.subtype == 0 then
    else
      build_text()
      -- handle dir whatsits
      if n.id == whatsit_id and n.subtype == 7 then 
        handle_dir(n.dir) end
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
