
local luarocks = io.popen("luarocks path", "r")
if not luarocks then
  print("Can't open luarocks path")
  os.exit(1)
end
local paths = luarocks:read("*all")
luarocks:close()
local path = paths:match("PATH='(.-)'")
local cpath = paths:match("CPATH='(.-)'")
print('package.cpath=package.cpath .. '.. "';" .. cpath .."'")
print('package.path=package.path .. '.. "';" .. path .."'")
