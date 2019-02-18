
local cn = require 'cn.cn'	
local timers = require 'cn.timers'	
local m1 = require 'm1'
local bus = m1.getBus()
 
assert(bus[104], 'No module on station 1, slot 4!')
assert(bus[104]:getValue(1) ~= 'GIO212', 'Not a GIO212!')
 
--
-- MIO sample: LED animation
--
 
timers.add(
  0.05,
  coroutine.create(
    function()
      while true do
        bus[104]:setValue(5, true)
        coroutine.yield()      
        bus[104]:setValue(6, true)
        coroutine.yield()      
        bus[104]:setValue(7, true)
      	coroutine.yield()      
        bus[104]:setValue(8, true)
      	coroutine.yield()      
        bus[104]:setValue(5, false)
        coroutine.yield()      
        bus[104]:setValue(6, false)
        coroutine.yield()      
        bus[104]:setValue(7, false)
        coroutine.yield()      
        bus[104]:setValue(8, false)
        coroutine.yield()
      end
    end   
  )
)
 
while cn.idle() do end