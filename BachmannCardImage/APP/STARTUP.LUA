--
-- This sample needs a GIO212 at slot #4
-- Channel configuration:
-- 1 : PT100
-- 5 : Digital output
-- 6 : Digital output
-- 7 : Digital output
-- 8 : Digital output
--

print("*** CN start ***")

cn = require 'cn.cn'
timers = require 'cn.timers'

local bus = sys.m1.getBus()

print('--- Devices on the local bus:')
for i, t in pairs(bus) do
  print('->', i, bus[i].name)
  --[[
  for k, v in pairs(t) do
    print("  ", k, " = ", v)
  end
  --]]
end 

assert(bus[104], 'No module on station 1, slot 4!')
assert(bus[104]:getValue(1) ~= 'GIO212', 'Not a GIO212!')
 
print(bus[104]:getValue(1), table.concat(bus[104]:getError(1)))

--
-- SVI sample: Read the PT100 temperature in 'C every 5 seconds
-- 
timers.add(
  5,
  function()
    print(sys.svi.readVariable('MIO/4/1') * 0.1 - 273.15)
  end
)

--
-- MIO sample: LED animation
--

timers.add(
  0.01,
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

while sys.idle() do end




 











