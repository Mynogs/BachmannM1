
--**************************************************************************$
--* Copyright (C) 2013-2018 Ing. Buero Riesberg - All Rights Reserved
--* MIT Licence
--***************************************************************************/

-- 15.09.2017 08:31:00 AR V1.0a
-- 18.12.2017 08:26:16 AR V1.0a
-- 19.12.2017 11:24:03 AR V1.0b Move model tun 'run' directore. Extend taget lua searchpath
-- 01.05.2018 07:24:22 AR V1.0d Add gloabl sys = require 'sys'

target = {
  name = 'Bachmann M1',

  parameter = {
    ip = '192.168.1.177',
    protocoll = 'TCP',
    user = 'M1',
    password = 'bachmann',
    directory = '/pcc0/app',
    modul = 'CN',
  },

  init = function(self)
  end,

  open = function(self)
    local m1 = require 'bachmann_m1com'
    local info
    if not version then
      info = '<br><br><font color = "#008000">Version of the \'m1com.dll\' is ' .. m1.version() .. '</font>'
    else
      info = '<br><br><font color = "#800000"><b>Can\'t load \'m1com.dll\'!</b></font>'
    end
    gui.add('HTMLInfo', 'Info', self.name, [[
<b>CN on the Bachmann M1 PLC</b><br><br>
For more infomations about Bachmann PLC visit <a href="www.bachmann.at">www.bachmann.at</a><br><br>
You have to install the CN on the Bachmann PLC: <a href="riesberg-net.de/cn-fuer-bachmann-m1">Install the CN on the Bachmann PLC</a>
]] .. info, {Height = 140})
    gui.add('Edit', 'EditIP', 'IP')
    gui.add('Edit', 'EditUser', 'User name')
    gui.add('Edit', 'EditPassword', 'Password')
    gui.add('Edit', 'EditDirectory', 'Target directory', {Width = 200})
    gui.add('Edit', 'EditModul', 'Modul')
    gui.set('EditIP', self.parameter.ip)
    gui.set('EditUser', self.parameter.user)
    gui.set('EditPassword', self.parameter.password)
    gui.set('EditDirectory', self.parameter.directory)
    gui.set('EditModul', self.parameter.modul)
  end,

  apply = function(self)
    self.parameter.ip = gui.get('EditIP', 'Text')
    self.parameter.user = gui.get('EditUser', 'Text')
    self.parameter.password = gui.get('EditPassword', 'Text')
    self.parameter.directory = gui.get('EditDirectory', 'Text')
    self.parameter.modul = gui.get('EditModul', 'Text')
    if self.parameter.directory:sub(-1) ~= '/' then
      self.parameter.directory = self.parameter.directory .. '/'
    end
  end,

  close = function(self)
  end,

  generate = function(self, what)
    if what == 'GENERATOR_HEADER' then
      return [[
function mangle(name)
  return name:sub(1, 8)
end
      ]]
    end
    if what == 'GENERATOR_REQUIRE' then
      -- Default path is:
      -- #define LUA_PATH_DEFAULT "/pcc0/app/?.lua;/cfc0/app/?.lua"
      -- #define LUA_CPATH_DEFAULT "/pcc0/app/?.o;/cfc0/app/?.o"
      local source = "package.path = package.path .. ';" .. self.parameter.directory .. "?.lua'\n"
      source = source ..
[[
-- Patch require function to use short file names
__require = require
require = function(path)
  --print(1, path)
  local l = {}
  for p in path:gmatch('([^%.]+)') do
    l[#l + 1] = p:sub(1, 8)
  end
  path = table.concat(l, '.')
  --print(2, path)
  return __require(path)
end
]]
      return source ..
[[
sys = require 'sys'
token = {set = function() end, get = function() end}token = {set = function() end, get = function() end}
]]
    end
    if what == 'GENERATOR_HELPER_FUNCTIONS' then
      return [[
  sim.directory = ']] .. self.parameter.directory .. [['
]]
    end
    if what == 'GENERATOR_MAIN' then
      return [[
do
  while true do
    local tick, ellapsedS = sys.isTicked()
    if tick then
      sim.timeS = sim.timeS + ellapsedS
      if not nextS then
        nextS = sim.timeS
      end
      if sim.timeS >= nextS then
        block.step()
        sim.step = sim.step + 1
        sim.stepT0 = sim.stepT0 + 1
        nextS = nextS + sim.stepRateS
        collectgarbage()
      end
    end
  end
end
      ]]
    end
  end,

  inject = function(self, files, xml)
    local sys = require 'sys'
    local token = require 'token'
    local m1 = require 'bachmann_m1com'
    sys.debug('Injector start')
    do
      -- Connect to Bachmann M1
      injector.addLabel('Try to connect to Bachmann M1 at ' .. self.parameter.ip .. ' as user \'' .. self.parameter.user .. '\'')
      local dev = m1:newTarget(self.parameter.ip, m1.M1C_TCP)
      dev:connect()
      injector.addLabel('Connection status is ' .. dev:getConnectionState())
      injector.assert(dev:getConnectionState() == 'ONLINE', 'Bachmann M1 is not in the ONLINE state!')
      -- Check if the modul is loaded
      do
        local modules = dev:getModules()
        local found = false
        for i = 1, #modules do
          if modules[i] == self.parameter.modul then
            found = true
            break
          end
        end
        injector.assert(found, 'Module \'' .. self.parameter.modul .. '\' not found. Install and start the modul first')
      end
      -- Connect to the modul, reset it, transfer files via FTP an start it
      local cn = dev:createModul(self.parameter.modul)
      injector.assert(cn:connect(), 'Can\'t connect to modul \'' .. self.parameter.modul .. '\'')
      function check(s)
        local result = 0
        for i = 1, #s do
          result = result * 10 + s:byte(i)
        end
        injector.assert(result == 0, 'SMI call fails: ' .. result)
      end
      injector.addLabel('Reset modul')
      check(cn:sendCall(m1.SMI_PROC_RESET, 2, sys.format('%*s', m1.SMI_RESET_C_SIZE, self.parameter.modul .. '.m'), m1.SMI_RESET_R_SIZE))
      do
        local target = injector.newFTP()
        target:connect(self.parameter.ip, self.parameter.user, self.parameter.password)
        local pb1 = injector.addProgressBar('Upload files', #files, true)
        local fl = injector.addFileList('Uploading')
        local bytes = 0
        for i = 1, #files do
          --print(files[i].host, '-->', self.parameter.directory .. files[i].remote)
          injector.setProgressBar(pb1, i)
          -- Shorten all names to max 8 chars
          local path, ext = files[i].remote:match('([^%.]+)(.*)')
          --print('#', path, ext)
          local t = {}
          for name in path:gmatch("[^%/]+") do
            --print(name)
            t[#t + 1] = name:sub(1, 8)
          end
          local remoteName = table.concat(t, '/') .. (ext or '')
          injector.addFile(fl, remoteName)
          bytes = bytes + target:put(files[i].host, self.parameter.directory .. remoteName)
        end
        injector.addLabel('Upload succesfull: ' .. bytes .. ' bytes in ' .. #files .. ' files')
        target:disconnect()
      end
      injector.addLabel('Start modul')
      check(cn:sendCall(m1.SMI_PROC_ENDOFINIT, 2, sys.format('%*s', m1.SMI_ENDOFINIT_C_SIZE, self.parameter.modul .. '.m'), m1.SMI_ENDOFINIT_R_SIZE))
    end
  end,
}









