
-- get 
local function compute_diff(t1,t2)
  local t1 = t1 or {}
  local t2 = t2 or {}
  local t3 = {}
  local pos1, pos2 = 1,1
  for pos1 = 1, #t1 do
    if t1[pos1] == t2[pos2] then
      t3[pos1] = pos2
    else
      t3[pos1] = 0
      pos1 = pos1 + 1
      -- pos2 = pos2 + 1
      while t1[pos1] ~= t2[pos2 + 1] and pos2 < #t2  do
        pos2 = pos2 + 1
      end
    end
    pos2 = pos2 + 1
  end
  return t3
end

local function get_table_part(t,x,y)
  local n = {}
  for i=x,y do
    n[#n+1] = t[i]
  end
  return n
end

local function get_diff(t1,t2)
  local diffs = compute_diff(t1, t2)
  local result = {}
  for i,v in ipairs(diffs) do
    if v > 0 then
      result[#result+1] = {text = t1[i]}
    else
      local start = (diffs[i-1] or 0) + 1
      local stop  = (diffs[i+1] or (#t2 + 1)) - 1
      print(start, stop)
      result[#result+1] = {text=t1[i], components = get_table_part(t2, start, stop)}
    end
  end
  return result
end

return get_diff



  
  
