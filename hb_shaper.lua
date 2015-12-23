local M =  {}
M.loglevel = 0
local harfbuzz = require "harfbuzz"
local diff = require "hb_diff"
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
  local x = x or 0
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

local function make_text(text)
  if type(text) == "string" then return text end
  local t = {}
  for i=1, #text do t[#t+1] = utfchar(text[i]) end
  return table.concat(t)
end

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
  if type(text)== "string" then
    buffer:add_utf8(text)
  else
    -- we got segfault when we tried to use directly text table 
    local t = {}
    for i=1, #text do t[#t+1] = text[i] end
    buffer:add_codepoints(t)
  end
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
-- We should work with graphemes in reshaping
local glen = unicode.grapheme.len
local ulen = unicode.utf8.len
local gpos = unicode.grapheme.sub

-- function reshape is called only when a word contains some glyph unsupported by a font
-- we will make graphemes, test each for shapping support, join graphemes with the same category
-- (shaped/unshaped) and shape them separatelly
local function reshape(chars, nodeoptions, options,fontoptions, shape_count)
  local text = make_text(chars)
  local function make_graphemes(text)
    local t = {}
    for i = 1, glen(text) do
      t[#t+1] = gpos(text, i, i)
    end
    return t
  end
  local function guess_script(text)
    local buf = Buffer.new()
    buf:add_utf8(text)
    buf:guess_segment_properties()
    local script =  buf:get_script()
    -- use latn as default script when detection fails
    if script == "" then script = "latn" end
    return script:lower()
  end
  local function shape_graphemes(graphemes)
    local t = {}
    local dir = options.dir
    local size = fontoptions.size
    for k, v in pairs(graphemes) do 
      local res = shape(v, fontoptions, dir, size)
      -- shape returns table with one element in this case
      local element = res[1]
      -- save current grapheme to table
      local a = {text = v}
      if element.codepoint == 0 then
        -- save script only for unshaped glyphs
        a.script = guess_script(v)
      end
      t[#t+1] = a
    end
    return t
  end
  -- process grapheme table and join graphemes with same script
  local function join_scripts(shapes, results, i)
    local i = i or 1
    if i > #shapes then return results end
    local shapes = shapes or {}
    local results = results or {}
    local t = {}
    local curr_script = shapes[i].script
    while i<=#shapes and shapes[i].script == curr_script  do
      t[#t+1] = shapes[i].text
      i = i + 1
    end
    local new = {text = table.concat(t), script = curr_script}
    results[#results+1] = new
    return join_scripts(shapes, results, i)
  end
  -- we must create character table
  -- text is now real text
  -- get table with all graphemes and their scripts
  local shapes = shape_graphemes(make_graphemes(text))
  local segments = join_scripts(shapes)
  local newnodes = {}
  local opt = fontoptions.options or {}
  for k,v in ipairs(segments) do
    print("Segment", v.text, v.script)
    local script = v.script
    local newfont
    if script then
      newfont = opt[script] or -1
    end
    print ("Reshaping using ".. (script or "-") .. " font: ", newfont)
    local newnodeopts = {}
    for k,v in pairs(nodeoptions) do newnodeopts[k] = v end
    if newfont and newfont > -1 then 
      newnodeopts.font = newfont
    end
    local curr_nodes =  M.make_nodes(v.text, newnodeopts, options, shape_count)
    for _,y in ipairs(curr_nodes) do newnodes[#newnodes+1] = y end
  end
  if #newnodes>0 then
    return newnodes
  end
  print "No substitute font"
  return {}
end




local function handle_ligatures(nodetable, chars, fontoptions, dir, size)
  local docoption = fontoptions.options or {}
  local ligatable = fontoptions.options.ligatable or {}
  local unprocessed  = 0
  local text = make_text(chars)
  local find_components = function()
    -- we must save features, 
    local saved_features = docoption.features
    -- add features to feature list
    -- disable ligatures
    local new_features = table.concat({(saved_features or ""), "-liga;-clig;-hlig;-dlig;-rlig"}, ";")
    docoption.features = new_features
    -- get new glyph list without ligatures
    local new_nodes = shape(chars, fontoptions, dir, size)
    -- and restore features later, we don't want to disable ligatures in the document
    docoption.features = saved_features
    -- we must create tables for shaped text with and without ligatures
    local new_chars = {}
    local old_chars = {}
    -- process glyph list for characters
    for k,v in ipairs(new_nodes) do 
      local c = fontoptions.backmap[v.codepoint]
      new_chars[#new_chars + 1] = c
    end
    -- make character table for the node list with ligatures
    for k,v in ipairs(nodetable) do old_chars[#old_chars + 1] = v.char end
    -- make difference table between two character tables
    -- diff function is saved in hb_diff.lua
    local diffed = diff(old_chars, new_chars)
    for k,v in ipairs(diffed) do
      local c = v.text
      -- detected ligatures are saved as coomonents field in diffed table
      local components = v.components or false
      ligatable[c] = components
    end
  end
  local insert_ligacomponents = function(x)
    -- insert child nodes for ligatured glyph
    x.subtype = 3
    local head, prev
    -- the component characters are saved in ligatable 
    local components = ligatable[x.char]
    for _, component in ipairs(components) do
      local n = node.new "glyph"
      n.char = component
      n.font = x.font
      n.lang = x.lang
      n.uchyph = x.uchyph
      n.left = x.left
      n.right = x.right
      n.attr = x.attr
      n.subtype = 1
      if not head then 
        head = n
      else
        node.insert_after(head, prev, n)
      end
      prev = n
    end
    x.components = head
    return x
  end
  -- first detect whether there are any characters which haven't been saved in ligatable yet
  for _, x in ipairs(nodetable) do
    local c = x.char
    if c then -- ignore non glyph nodes
      -- glyph which haven't been saved in ligatable yet, we need to rebuild the whole string
      if ligatable[c] == nil then
        unprocessed = unprocessed + 1
      elseif ligatable[c] ~= false then
        x = insert_ligacomponents(x)
      end
    end
  end
  -- when node list contains characters which haven't been saved to ligatable yet, we need to rebuild it
  if unprocessed > 0 then
    find_components()
    fontoptions.options.ligatable = ligatable 
    return handle_ligatures(nodetable, chars, fontoptions, dir, size)
  end
  fontoptions.options.ligatable = ligatable 
  return nodetable
end

local function hyphenate_ligatures(head)
  local glyphpos = 0
  local newhead, prev 
  local discretionaries = {}
  -- we want to hyphenate node lists which contain ligatures
  -- ligatured words are not hyphenated, we create temporary list with
  -- decomposed ligatures, hyphenate it, and the insert discretionaries back to 
  -- original node list
  for n in node.traverse(head) do
    -- hyphenation also doesn't work with kerns, so we must ignore them
    -- but only kerns with subtype 0, which comes from font kerning
    if n.id == kern_id and n.subtype == 0 then
    elseif n.subtype ~= 3 or n.id ~= glyph_id then
      local copy = node.copy(n)
      if not newhead then
        newhead = copy 
      else
        node.insert_after(newhead, node.tail(newhead), copy)
      end
    else
      for comp in node.traverse(n.components) do
        local x = node.copy(comp) 
        x.subtype = 1
        if not newhead then 
          newhead = x
        else
          node.insert_after(newhead, node.tail(newhead),x)
        end
      end
    end
  end
  -- hyphenate unligatured node list
  lang.hyphenate(newhead)
  -- save positions of discretionaries
  for k in node.traverse(newhead) do
    if k.id == glyph_id then
      glyphpos = glyphpos + 1
    elseif k.id == disc_id then
      discretionaries[glyphpos] = node.copy(k) 
    end
  end
  -- free the memory
  node.flush_list(newhead)
  glyphpos = 0
  local advance_glyphpos = function(n)
    -- test for discretionary on current glyph pos
    local d = discretionaries[glyphpos]
    if d then
      node.insert_before(head, n, d)
    end
    glyphpos = glyphpos + 1
  end
  -- insert discretionaries into the original list
  for n in node.traverse(head) do
    if n.id == glyph_id then
      -- count glyph nodes
      if n.subtype==3 then
        for j in node.traverse(n.components) do
          advance_glyphpos(n)
        end
      else
          advance_glyphpos(n)
      end
    end
  end
  return head
end
 

  -- nodeoptions are options for glyph nodes
-- options are for harfbuzz
M.make_nodes = function(text, nodeoptions, options, shape_count)
  -- shaping may be called several times in the case os missing glyphs
  local shape_count = shape_count or 0
  if shape_count > 1 then 
    return {} 
  end
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
    -- do reshape if missing glyph is detected. Whole word is reshaped
    if v.codepoint==0 then
      log("Detected missing glyph: %s", make_text(text))
      return reshape(text, nodeoptions, options, fontoptions, shape_count + 1)
    end
    local n
    local char =  fontoptions.backmap[v.codepoint]
    n = node.new("glyph")
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
  nodetable = handle_ligatures(nodetable, text, fontoptions, direction, size)
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
        uchyph = current_text.uchyph,
        left = current_text.left,
        right = current_text.right,
        font = current_font, 
        lang= current_text.lang, 
        attr = current_text.attr,
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
        if n.lang == current_text.lang and n.font == current_text.font and n.attr == current_text.attr then
        else
          build_text()
          current_text.font = n.font
          current_text.lang = n.lang
          current_text.attr = n.attr
          current_text.left = n.left
          current_text.right = n.right
          current_text.uchyph = n.uchyph
          -- we should save individual expansion_factors
          current_text.expansion_factor = n.expansion_factor
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
    local ligatured = false
    -- lang.hyphenate(newhead)
    -- hyphenation doesn't work also with kern nodes, so use 
    -- hyphenate_ligatures in every case
    newhead = hyphenate_ligatures(newhead)
    -- kerning is done by harfbuzz
    -- node.kerning(newhead)
    -- node.flush_list(head)
    -- print "return newhead"
    return newhead
  end
  return head
end


return M
