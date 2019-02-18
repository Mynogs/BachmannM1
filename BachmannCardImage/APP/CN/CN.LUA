--[[
 *  CN library
 *  Copyright (C) Andre Riesberg, Ing. Buero Riesberg
 *  MIT Licence
 --]]

local sys = require 'sys'

local cn = {
  tickCount = 0,
  onTickCallbacks = {}
}

cn.idle = function()
  local isTicked, elapsedTime = sys.isTicked();
  --print(isTicked, elapsedTime, '\n')
  if isTicked then
    cn.tickCount = cn.tickCount + 1
    --print("-->", cn.tickCount) 
    for i = 1, #cn.onTickCallbacks do
      cn.onTickCallbacks[i](elapsedTime)
    end
  end
  return true
end

return cn

