local t1 = {"g","r","a","f_i","k","a", "f_i"}
local t2 = {"g","r","a","f","i","k","a", "f", "i"}

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

local function get_diff(t1,t2)
  local diffs = compute_diff(t1, t2)
  local result = {}
  for i,v in ipairs(diffs) do
    if v > 0 then
      result = {text = t1[i]}
    else
      local start = (diffs[i-1] or 0) + 1
      local stop  = (diffs[i+1] or #t2) - 1
      print(start, stop)
    end
  end
end



get_diff(t1,t2)




  
  
