import pathlib,sys
sys.path.insert(0,'work/lua-check')
from lupa.lua54 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
module=lua.execute('return dofile(...)',str(pathlib.Path('work/LandsraadDonations/Scripts/board_progress.lua')).replace('\\','/'))
lua.globals().reader=module
lua.execute('''
local function rows(values)
 return{ForEach=function(_,callback)
  for i,value in ipairs(values)do callback(i,{get=function()return value end})end
 end}
end
local function faction(name,amount)
 return{m_Faction={Name={ToString=function()return name end}},m_ProgressAmount=amount}
end
local function task(index,values)
 return{m_BoardIndex=index,m_TaskProgressPerFaction=rows(values)}
end
local data=reader.read(rows({task(9,{faction('Atreides',2000),faction('Harkonnen',1500)}),task(23,{faction('Harkonnen',4000)})}))
assert(data[9].Atreides==2000 and data[9].Harkonnen==1500)
assert(data[23].Atreides==0 and data[23].Harkonnen==4000)
assert(not pcall(reader.read,rows({})))
assert(not pcall(reader.read,rows({task(25,{})})))
assert(not pcall(reader.read,rows({task(9,{}),task(9,{})})))
assert(not pcall(reader.read,rows({task(9,{faction('Harkonnen',-1)})})))
assert(not pcall(reader.read,rows({task(9,{faction('Harkonnen',1),faction('Harkonnen',2)})})))
''')
print('PASS: nested faction response, both factions on one house, enemy-only capture, invalid/empty/duplicate data. No game actions.')
