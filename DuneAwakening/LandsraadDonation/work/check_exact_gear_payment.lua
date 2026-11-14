local root,mode=...
local realDofile=dofile
local queue,now,actions,logs={},0,0,{}
local generation=123456
local equipment,ability=1,1
local function valid()return true end
local function row(entity,database,slot,template,count)
 return{key=entity..':'..database,entity=entity,database=database,slot=slot,template=template,count=count}
end
local inventoryRows={row('18050761536560958201','101',0,'Compactor',1),row('18050761536560958202','102',1,'Compactor',1),row('18050761536560958203','103',3,'Cutteray',3)}
local function snapshot()
 local rows={};for _,r in ipairs(inventoryRows)do local c={};for k,v in pairs(r)do c[k]=v end;rows[#rows+1]=c end
 return{kind='backpack',inventory=44,controller=11,pawn=22,world=33,checksum=generation,checksumBusy=0,rows=rows}
end
local inv={IsValid=valid,GetAddress=function()return 44 end}
local world={GetAddress=function()return 33 end}
local pawn={GetAddress=function()return 22 end,m_BackpackInventoryComponent={GetInventory=function()return inv end}}
function FName(id)return{ToString=function()return id end}end
function pawn:GetNumberOfItemsInInventory(key)
 local id=key.Name:ToString();local n=0;for _,r in ipairs(inventoryRows)do if r.template==id then n=n+r.count end end
 return n+(id=='Compactor'and equipment+ability or 0)
end
function pawn:GetNumberOfItemsInEquipmentInventory(key)return key.Name:ToString()=='Compactor'and equipment or 0 end
function pawn:GetNumberOfItemsInAbilityInventory(key)return key.Name:ToString()=='Compactor'and ability or 0 end
local handler={IsValid=valid}
function handler:ServerPerformAction(payload)
 actions=actions+1;local a=payload.m_ActionMessage
 assert(a.m_Inventory==inv and a.m_InventoryChecksum==generation and a.m_ItemAddReason==31)
 assert(a.m_bForceDebugActionsCheat==false and a.m_bIsListenAction==false)
 if mode=='no_removal'then return end
 local found
 for index,r in ipairs(inventoryRows)do if r.slot==a.m_ItemIndex and tonumber(r.database)==a.m_ItemDatabaseId.UID then
  found=true;r.count=r.count-a.m_Quantity;if r.count==0 then table.remove(inventoryRows,index)end;break
 end end
 assert(found,'Wrong exact target');generation=generation+1
 if mode=='unselected_changed'then inventoryRows[1].count=inventoryRows[1].count+1 end
 if mode=='equipment_changed'then equipment=equipment+1 end
end
local pc={GetAddress=function()return 11 end,GetWorld=function()return world end,m_ActionHandler=handler}
local backend={supportsExactItems=true,busy=false,context=function()return{controller=pc,pawn=pawn}end,
 board=function()return{term=6,competition=true}end,journal=function(_,text)logs[#logs+1]=text end}
local app={}
function app:defer(delay,callback)
 local token={active=true};function token:cancel()self.active=false end
 queue[#queue+1]={at=now+delay,callback=callback,token=token};return token
end
function StaticFindObject(path)
 local o={IsValid=valid,GetNameByValue=function()return{ToString=function()return'EInventoryItemAddReason::Landsraad'end}end}
 function o:ForEachProperty(callback)
  local types,names
  if path:find('InventoryActionDeleteItem',1,true)then
   types={'ObjectProperty','IntProperty','StructProperty','IntProperty','EnumProperty','StrProperty','UInt32Property'}
   names={'m_Inventory','m_ItemIndex','m_ItemDatabaseId','m_Quantity','m_ItemAddReason','m_ItemAddDetails','m_InventoryChecksum'}
  else types={'StructProperty'};names={'ActionPayLoad'}end
  for i,name in ipairs(names)do local text=types[i]..' '..path..':'..name;callback{GetFullName=function()return text end}end
 end
 return o
end
function StaticConstructObject()return{IsValid=valid,m_ItemDatabaseId={UID=0}}end
function dofile(path)
 if path==root..'/backpack_native.lua'then return{scan=function(_,_,_,callback)
  return app:defer(1,function()callback({},nil,snapshot())end)
 end}end
 return realDofile(path)
end
local before=snapshot();local rows={}
for _,r in ipairs(before.rows)do rows[#rows+1]={key=r.key,entity=r.entity,database=r.database,slot=r.slot,count=r.count,inventory=44,item={id=r.template}}end
local selection={[rows[1].key]=1}
if mode=='two_types'then selection[rows[3].key]=2 end
if mode=='partial_stack'then selection={[rows[3].key]=1}end
local adapter=realDofile(root..'/exact_gear_payment.lua')
if mode=='bad_uid'then
 rows[1].database='9223372036854775808';rows[1].key=rows[1].entity..':'..rows[1].database
 before.rows[1].database=rows[1].database;before.rows[1].key=rows[1].key
 assert(not pcall(adapter.plan,before,rows,{[rows[1].key]=1}));assert(actions==0);return true
end
if mode=='missing_checksum'then before.checksum=nil;assert(not pcall(adapter.new,backend,before,rows,selection));assert(actions==0);return true end
local payment=adapter.new(backend,before,rows,selection)
assert(payment.mode=='exact'and payment.read(pawn)==payment.units)
backend.busy=true;payment.debit(pawn,payment.units,'123-456')
assert(actions==0,'debit must wait for fresh snapshot')
local result,reason
payment.awaitReceipt(app,function(ok,why)result=ok;reason=why end)
local ticks=0
while #queue>0 do
 table.sort(queue,function(a,b)return a.at<b.at end)
 local job=table.remove(queue,1);now=job.at
 if job.token.active then ticks=ticks+1;assert(ticks<120);job.callback()end
end
if mode=='no_removal'or mode=='unselected_changed'or mode=='equipment_changed'then
 assert(result==false,reason);assert(actions==1,'Uncertain action must never repeat');return true
end
assert(result==true,reason);assert(payment.read(pawn)==0)
assert(actions==(mode=='two_types'and 2 or 1))
assert(equipment==1 and ability==1)
local remaining={};for _,r in ipairs(inventoryRows)do remaining[r.database]=r.count end
if mode=='partial_stack'then assert(remaining['101']==1 and remaining['102']==1 and remaining['103']==2)
else assert(remaining['101']==nil and remaining['102']==1 and remaining['103']==(mode=='two_types'and 1 or 3))end
return true
