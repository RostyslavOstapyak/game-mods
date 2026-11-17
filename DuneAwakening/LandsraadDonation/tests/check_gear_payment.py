from lupa.lua54 import LuaRuntime

LuaRuntime().execute(r"""
local function object(address)
 return {IsValid=function()return true end,GetAddress=function()return address end}
end
local inv=object(1)
function inv:IsInitialContentReceived()return true end
local pawn,controller,world=object(2),object(3),object(4)
function controller:GetWorld()return world end
pawn.m_BackpackInventoryComponent={GetInventory=function()return inv end}
function FName(id)return {ToString=function()return id end}end
function StaticFindObject(path)
 local fn=object(5)
 function fn:GetNameByValue()return FName('EInventoryItemAddReason::Landsraad')end
 function fn:ForEachProperty(callback)
  local fields=path:match('RemoveItem') and {
   {'Struct','InItemTemplateID'},{'Int','Amount'},{'Enum','Reason'},{'Str','ItemAddDetails'},{'Bool','ReturnValue'}
  } or {{'Struct','InItemTemplateID'},{'Int','ReturnValue'}}
  for _,field in ipairs(fields)do
   callback({GetFullName=function()return field[1]..'Property '..path..':'..field[2]end})
  end
 end
 return fn
end
local backpack={Single=1,Duplicate=2,Equipped=1,Ability=1,Other=1}
local equipment={Equipped=1}
local ability={Ability=1}
function pawn:GetNumberOfItemsInBackpackInventory(key)return backpack[key.Name:ToString()] or 0 end
function pawn:GetNumberOfItemsInEquipmentInventory(key)return equipment[key.Name:ToString()] or 0 end
function pawn:GetNumberOfItemsInAbilityInventory(key)return ability[key.Name:ToString()] or 0 end
function pawn:GetNumberOfItemsInInventory(key)
 return self:GetNumberOfItemsInBackpackInventory(key)+self:GetNumberOfItemsInEquipmentInventory(key)+self:GetNumberOfItemsInAbilityInventory(key)
end
local removed={}
function pawn:RemoveItemAmountFromBackpackByTemplateId(key,units,reason)
 local id=key.Name:ToString()
 assert(units==1 and reason==31 and backpack[id]==1)
 backpack[id]=0;removed[#removed+1]=id
 return true
end
local backend={context=function()return {pawn=pawn,controller=controller}end,journal=function()end}
local pending,scanError,rows,snapshot
local app={defer=function(_,_,callback)pending=callback;return true end}
local scan=dofile('Scripts/item_inventory.lua')
scan.scan(app,backend,{{id='Single'},{id='Duplicate'},{id='Equipped'},{id='Ability'},{id='Other'}},function(found,err,ctx)
 rows,scanError,snapshot=found,err,ctx
end)
pending()
assert(not scanError and #rows==2 and rows[1].key=='type:Single' and rows[2].key=='type:Other')
local gear=dofile('Scripts/gear_payment.lua')
assert(not pcall(gear.plan,rows,{['type:Duplicate']=1}))
assert(not pcall(gear.plan,rows,{['type:Single']=2}))
local payment=gear.new(backend,snapshot,rows,{['type:Single']=1,['type:Other']=1})
assert(payment.read(pawn)==2 and payment.identities[1].key=='type:Single')
backpack.Single=2
assert(not pcall(payment.debit,pawn,2,'1') and #removed==0)
backpack.Single=1;equipment.Other=1
assert(not pcall(payment.debit,pawn,2,'1') and #removed==0)
equipment.Other=0
payment.debit(pawn,2,'1')
assert(payment.read(pawn)==0 and #removed==2 and backpack.Duplicate==2 and backpack.Equipped==1)
""")
print('PASS: singleton scanning, stale selection, equipment exclusion and mixed-template debit.')
