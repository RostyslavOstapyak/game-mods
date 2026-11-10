-- Exact backpack actions. A fresh checksum accompanies every single item action.
-- The complete inventory is read after each action; uncertain actions are never resent.
local M={}
local DIR=debug.getinfo(1,'S').source:sub(2):gsub('\\','/'):match('^(.*)/[^/]+$')
local function valid(o)return o and o:IsValid()end
local function uid(value)
 assert(type(value)=='string'and value:match('^[1-9]%d*$'),'Invalid database identity.')
 local n=tonumber(value)
 assert(n and math.type(n)=='integer'and n>0 and tostring(n)==value,'Database identity cannot be represented exactly.')
 return n
end
local function checksum(snapshot)
 return snapshot and snapshot.kind=='backpack'and type(snapshot.checksum)=='number'and snapshot.checksum%1==0
  and snapshot.checksum>=0 and snapshot.checksum<=4294967295 and snapshot.checksumBusy==0
end
function M.plan(snapshot,rows,selection)
 assert(checksum(snapshot),'Потрібне свіже точне читання рюкзака з контрольною сумою.')
 local raw={};for _,row in ipairs(snapshot.rows)do assert(not raw[row.key],'Duplicate snapshot identity.');raw[row.key]=row end
 local seen,lines,units={},{},0
 for _,row in ipairs(rows)do
  assert(not seen[row.key],'Duplicate selected identity.');seen[row.key]=true
  local amount=selection[row.key]
  if amount then
   local source=assert(raw[row.key],'Selected item is absent from the full snapshot.')
   assert(row.entity==source.entity and row.database==source.database and row.item.id==source.template
    and row.count==source.count and row.slot==source.slot and row.inventory==snapshot.inventory,'Selected item identity changed.')
   assert(type(amount)=='number'and amount%1==0 and amount>0 and amount<=row.count,'Некоректна кількість предметів.')
   lines[#lines+1]={key=row.key,entity=row.entity,database=row.database,databaseUID=uid(row.database),
    slot=row.slot,template=row.item.id,before=row.count,units=amount,item=row.item}
   units=units+amount
  end
 end
 for key in pairs(selection)do assert(seen[key],'Вибраний предмет зник.')end
 assert(#lines>0 and #lines<=64,'Виберіть від 1 до 64 позицій.')
 table.sort(lines,function(a,b)return a.slot<b.slot end)
 return lines,units
end
local function expected(snapshot)
 local out={}
 for _,row in ipairs(snapshot.rows)do out[row.key]={template=row.template,count=row.count}end
 return out
end
local function matches(snapshot,wanted)
 local seen={}
 for _,row in ipairs(snapshot.rows)do
  local before=wanted[row.key]
  if not before or seen[row.key]or before.template~=row.template or before.count~=row.count then return false end
  seen[row.key]=true
 end
 for key in pairs(wanted)do if not seen[key]then return false end end
 return true
end
local function schema()
 local path='/Script/DuneSandbox.InventoryActionDeleteItem'
 local class=StaticFindObject(path);assert(valid(class),'Exact inventory action unavailable.')
 local actual={};class:ForEachProperty(function(p)actual[#actual+1]=p:GetFullName()end)
 local types={'ObjectProperty','IntProperty','StructProperty','IntProperty','EnumProperty','StrProperty','UInt32Property'}
 local names={'m_Inventory','m_ItemIndex','m_ItemDatabaseId','m_Quantity','m_ItemAddReason','m_ItemAddDetails','m_InventoryChecksum'}
 assert(#actual==#names,'Exact inventory action layout changed.')
 for i,name in ipairs(names)do assert(actual[i]==types[i]..' '..path..':'..name,'Exact inventory action parameter changed.')end
 local route='/Script/DuneSandbox.PlayerActionSystemHandler:ServerPerformAction'
 local fn=StaticFindObject(route);assert(valid(fn),'Inventory action handler unavailable.')
 local fields={};fn:ForEachProperty(function(p)fields[#fields+1]=p:GetFullName()end)
 assert(#fields==1 and fields[1]=='StructProperty '..route..':ActionPayLoad','Inventory action route changed.')
 local reason=StaticFindObject('/Script/DuneSandboxCore.EInventoryItemAddReason')
 assert(valid(reason)and reason:GetNameByValue(31):ToString()=='EInventoryItemAddReason::Landsraad','Inventory reason changed.')
 return class
end
function M.new(backend,snapshot,rows,selection)
 local lines,units=M.plan(snapshot,rows,selection)
 local term=backend:board().term
 local created=os.time();local sentId,verified
 local payment={template='gear_batch',mode='exact',units=units,beforeUnits=units,identities={},offer={entity='exact',database='exact',slot='exact'}}
 local groups,catalog={},{ }
 for _,line in ipairs(lines)do
  payment.identities[#payment.identities+1]={template=line.template,entity=line.entity,database=line.database,slot=line.slot,count=line.units}
  catalog[line.template]=line.item
  groups[line.template]=(groups[line.template]or 0)+line.units
 end
 local counters
 local function context()
  local s=backend:context()
  assert(s.controller:GetAddress()==snapshot.controller and s.pawn:GetAddress()==snapshot.pawn
   and s.controller:GetWorld():GetAddress()==snapshot.world,'Player/world changed during exact payment.')
  local inv=s.pawn.m_BackpackInventoryComponent:GetInventory()
  assert(valid(inv)and inv:GetAddress()==snapshot.inventory,'Backpack changed during exact payment.')
  return s,inv
 end
 local function counts(pawn)
  local out={}
  for id in pairs(groups)do
   local name=FName(id,FNAME_Find);assert(name:ToString()==id,'Item template changed.')
   local key={Name=name}
   out[id]={total=pawn:GetNumberOfItemsInInventory(key),equipment=pawn:GetNumberOfItemsInEquipmentInventory(key),ability=pawn:GetNumberOfItemsInAbilityInventory(key)}
  end
  return out
 end
 function payment.checkDebit()
  assert(backend.supportsExactItems==true and not backend.busy,'Exact payment backend unavailable or busy.')
  assert(os.time()-created<=5,'Підтвердження застаріло. Перегляньте пожертву ще раз.')
  local s=context();schema()
  local current=counts(s.pawn)
  if counters then for id,before in pairs(counters)do
   assert(current[id].total==before.total and current[id].equipment==before.equipment and current[id].ability==before.ability,'Inventory counts changed before payment.')
  end else counters=current end
 end
 function payment.read(pawn)
  local s=context();assert(s.pawn:GetAddress()==pawn:GetAddress(),'Character changed.')
  -- A zero here represents a verified complete native snapshot, not just an action return value.
  return verified and 0 or units
 end
 function payment.debit(pawn,amount,id)
  assert(not sentId and amount==units and type(id)=='string'and id:match('^[%d%-]+$'),'Invalid exact payment operation.')
  local s=context();assert(s.pawn:GetAddress()==pawn:GetAddress()and os.time()-created<=5,'Exact confirmation expired.')
  sentId=id -- no action is issued until the asynchronous reader is ready
 end
 function payment.awaitReceipt(app,done)
  assert(sentId,'Exact payment was not prepared.')
  local active=true;local wanted=expected(snapshot);local index=1
  local reader=dofile(DIR..'/backpack_native.lua')
  local watchdog
  local function finish(ok,why)
   if not active then return end;active=false;if watchdog then watchdog:cancel()end
   verified=ok==true;done(ok,why)
  end
  watchdog=assert(app:defer(90000,function()finish(false,'Exact inventory receipt timed out; do not repeat.')end))
  local function guarded(callback)
   if not active then return end
   local ok,why=pcall(callback);if not ok then finish(false,tostring(why))end
  end
  local function fresh(callback)
   if not active then return end
   reader.scan(app,backend,catalog,function(_,err,current)
    guarded(function()
     assert(current,err);context()
     assert(current.controller==snapshot.controller and current.pawn==snapshot.pawn and current.world==snapshot.world
      and current.inventory==snapshot.inventory and checksum(current),'Fresh exact snapshot unavailable.')
     callback(current)
    end)
   end)
  end
  local step
  step=function()
   fresh(function(current)
    assert(matches(current,wanted),'Рюкзак змінився під час пожертви. Повтор заблоковано.')
    local board=backend:board();assert(board.term==term and board.competition,'Landsraad cycle changed during exact payment.')
    local line=lines[index]
    if not line then
     local actual=counts(context().pawn)
     for id,before in pairs(counters)do assert(actual[id].total==before.total-groups[id]
      and actual[id].equipment==before.equipment and actual[id].ability==before.ability,'Equipment or item count changed unexpectedly.')end
     backend:journal(sentId..' exact_payment_confirmed selected_lines='..#lines..' units='..units..' other_items_unchanged=true equipment_unchanged=true remaining_entries='..#current.rows)
     finish(true);return
    end
    local live
    for _,row in ipairs(current.rows)do if row.key==line.key then live=row end end
    assert(live and live.template==line.template and live.database==line.database and live.count>=line.units,'Selected exact item changed.')
    local after={};for key,row in pairs(wanted)do after[key]={template=row.template,count=row.count}end
    if live.count==line.units then after[line.key]=nil else after[line.key].count=live.count-line.units end
    local s,inventory=context();local handler=s.controller.m_ActionHandler
    assert(valid(handler),'Inventory action handler unavailable.')
    local action=StaticConstructObject(schema(),handler,0,64);assert(valid(action),'Cannot create exact inventory action.')
    action.m_Instigator=s.controller;action.m_bIsListenAction=false;action.m_bIsRequestWithCallback=true
    action.m_bForceDebugActionsCheat=false;action.m_Inventory=inventory;action.m_ItemIndex=live.slot
    action.m_ItemDatabaseId.UID=line.databaseUID;action.m_Quantity=line.units;action.m_ItemAddReason=31
    action.m_ItemAddDetails='Landsraad Donations '..sentId;action.m_InventoryChecksum=current.checksum
    assert(action.m_ItemDatabaseId.UID==line.databaseUID and action.m_Inventory:GetAddress()==snapshot.inventory
     and action.m_ItemIndex==live.slot and action.m_Quantity==line.units and action.m_InventoryChecksum==current.checksum,'Exact action fields were not accepted.')
    backend:journal(sentId..' exact_debit_intent entity='..line.entity..' database='..line.database..' slot='..live.slot..' units='..line.units..' checksum='..current.checksum)
    handler:ServerPerformAction({m_ActionMessage=action}) -- once only, even if later reads time out
    backend:journal(sentId..' exact_debit_sent database='..line.database)
    backend.message='Перевіряємо списання предмета '..index..' з '..#lines..'…'
    local attempts=0
    local function receipt()
     fresh(function(result)
      if matches(result,after)then
       backend:journal(sentId..' exact_debit_confirmed database='..line.database..' units='..line.units)
       wanted=after;index=index+1;step();return
      end
      assert(matches(result,wanted),'Inventory changed beyond the selected item; do not repeat.')
      attempts=attempts+1;assert(attempts<12,'Exact deletion was not confirmed; action not repeated.')
      assert(app:defer(250,function()guarded(receipt)end))
     end)
    end
    assert(app:defer(250,function()guarded(receipt)end))
   end)
  end
  guarded(step)
 end
 payment.checkDebit()
 return payment
end
return M
