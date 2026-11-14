import sys,pathlib
from lupa.lua54 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
policy=lua.execute('return dofile(...)','Scripts/item_quote.lua')
quote=policy['quote']
for points,units,actual in [(1,1,60),(60,1,60),(61,2,120),(1000,17,1020),(6000,100,6000),(5999,100,6000)]:
 assert quote(points,1000,60000,6000)==(units,actual)
for price,value in [(1000,60000),(7,10),(1000,1),(1000000,60000)]:
 for requested in [1,17,1000,5999,6000]:
  try: units,actual=quote(requested,price,value,6000)
  except Exception:
   units=(requested*price+value-1)//value
   assert units*value//price>6000 or units>2147483647
  else:
   assert actual==units*value//price and actual>=requested and actual<=6000
   assert units==1 or (units-1)*value//price<requested,'Must choose the smallest sufficient whole item quantity'
for points in [0,-1,6001,1.5,'nan']:
 try:quote(points,1000,60000,6000)
 except Exception:pass
 else:raise AssertionError(points)
print('PASS: Melange value 60000 Solari, whole-item rounding, actual contribution, minimal quantity and hard 6000-point cap.')
