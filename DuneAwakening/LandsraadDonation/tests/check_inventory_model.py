import sys
from lupa.lua54 import LuaRuntime
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''
local model=dofile('Scripts/inventory_snapshot.lua')
local select=dofile('Scripts/item_selection.lua')
local text='I,1234,20,2,0,100;S,1234,1,18446744073709551001,9007199254740993,3,99,1,Sword6,Items.Holsters.MeleeWeapons;S,1234,4,42,43,1,1,1,Sword6,Items.Holsters.MeleeWeapons;'
local snap=model.parse(text,1234)
assert(snap.used==2 and snap.rows[1].entity=='18446744073709551001')
assert(snap.rows[1].database=='9007199254740993')
local rows=model.eligible(snap,{Sword6={id='Sword6',name='Sword'}})
assert(#rows==2 and rows[1].key~=rows[2].key)
assert(#model.eligible(snap,{})==0)
local selected=select.new();selected:selectAll(rows)
local summary=selected:summary(rows,function()return 0.5 end)
assert(summary.lines==2 and summary.units==4 and summary.points==2 and summary.quoteReady)
assert(selected:summary(rows,function()return 2000 end).overLimit)
assert(not selected:summary(rows,function()return nil end).quoteReady)
selected:set(rows[1],2)
local remaining,dropped=model.reconcile(selected.selected,rows);assert(dropped==0)
rows[1].slot=2
remaining,dropped=model.reconcile(selected.selected,rows);assert(dropped==1)
assert(selected:summary(rows,function()return 1 end).changed==1)
local function rejected(t,a)assert(not pcall(model.parse,t,a or 1234))end
rejected(text,9999)
rejected('I,1234,20,2,0,100;')
rejected('I,1234,20,1,0,100;U,1234,1,0,unresolved;')
rejected(text..'S,1234,4,44,45,1,1,1,Sword6,Items;')
selected:clear();assert(selected:summary(rows,function()return 1 end).lines==0)
''')
print('PASS: exact identifiers, separate instances, category filtering, batch selection, final rounding, cap, changed selection, incomplete/foreign/unresolved reads.')
