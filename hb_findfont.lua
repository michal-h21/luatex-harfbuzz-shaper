-- Code copied from luaotfload-tool
-- we need a minimal interface to luaotfload font database
--
config                          = config or { }
local config                    = config
config.luaotfload               = config.luaotfload or { }

config.lualibs                  = config.lualibs or { }
config.lualibs.verbose          = false
config.lualibs.prefer_merged    = true
config.lualibs.load_extended    = true

require "lualibs"
local iosavedata                = io.savedata
local lfsisdir                  = lfs.isdir
local lfsisfile                 = lfs.isfile
local stringsplit               = string.split
local tableserialize            = table.serialize
local tablesortedkeys           = table.sortedkeys
local tabletohash               = table.tohash
local dummy_function = function ( ) end                                                                                                               
local backup = {                                                                                                                                      
  write     = texio.write,                                                                                                                          
  write_nl  = texio.write_nl,                                                                                                                       
  utilities = utilities,                                                                                                                            
}                                                                                                                                                     

local luaotfloadloader = function(name)
  local mod = require(name)
  mod.init()
end

fonts = fonts or {}
texio.write, texio.write_nl          = dummy_function, dummy_function                                                                                 
require"fontloader-basics-gen.lua"                                                                                                                    

texio.write, texio.write_nl          = backup.write, backup.write_nl                                                                                  
utilities                            = backup.utilities                                                                                               

require "luaotfload-log.lua"       --- this populates the luaotfload.log.* namespace                                                                  
luaotfloadloader "luaotfload-parsers"       --- fonts.conf, configuration, and request syntax                                                                  
-- parsers.init()
luaotfloadloader "luaotfload-configuration" --- configuration file handling    
-- configuration.init()
luaotfloadloader "luaotfload-database"
require "hb_lotfl_fix_features"

-- load default configuration

config.actions.apply_defaults()

-- local parser = luaotfload.parsers.font_request
-- local lpeg = lpeg
-- local lpegmatch = lpeg.match

-- local resolve_cached = fonts.names.resolve_cached

local resolve_cached = fonts.names.lookup_font_name_cached
local handle_request = fonts.names.handle_request
local resolve_fullpath = fonts.names.getfilename

local function find(specification, size)
  local request = {features = {}}
  local specification = specification or ""
  request.specification = specification
  local spec = handle_request(request)
  local spec = request

  -- for k,v in pairs(fonts.names) do
  --   print(k,v)
  -- end

  -- print "-----------------"
  -- for k,v in pairs(spec.features) do
  --   print(k,v)
  -- end

  local fontfile, a = resolve_cached(spec)
  if not fontfile then
    return nil, "Cannot load font " .. specification
  end

  local base, ext = fontfile:match("(.+)%.([^.]+)")
  if not base then 
    return nil, "Probably tfm font"
  end
  local fullpath = resolve_fullpath(base,ext)
  spec.fullpath = fullpath
  spec.filename = fontfile
  -- local f = io.open(fullpath, "r")
  -- spec.data = f:read("*all")
  -- f:close()
  return fullpath, spec
end

local M = {}

M.find = find

return M
