-- Backpack-only template removal. Every instance of each selected template must be selected.
-- This avoids claiming an entity-specific debit from a template-based native interface.
local M={}
local DIR=debug.getinfo(1,'S').source:sub(2):gsub('\\','/'):match('^(.*)/[^/]+$')
local function valid(o)return o and o:IsValid()end
local function template(id)
 assert(type(id)=='string'and id:match('^[%w_]+$'),'Invalid item template.')
 local name=FName(id,FNAME_Find);assert(name:ToString()==id,'Item template changed.')
 return{Name=name}
end
function M.plan(rows,selection,snapshot)
 if snapshot and snapshot.checksum and snapshot.checksumBusy==0 then return dofile(DIR..'/exact_gear_payment.lua').plan(snapshot,rows,selection)end
 local groups,keys,units={}, {},0
 for _,row in ipairs(rows)do
  assert(not keys[row.key],'Duplicate inventory identity.');keys[row.key]=true
  if selection[row.key]then
   assert(type(selection[row.key])=='number'and selection[row.key]%1==0 and selection[row.key]>0 and selection[row.key]<=row.count,'Некоректна кількість предметів.')
   assert(row.entity and row.database and row.slot and row.inventory,'Exact item identity is unavailable.')
   local id=row.item.id;groups[id]=groups[id]or{units=0,before=0,rows=0}
   local group=groups[id];group.units=group.units+selection[row.key];group.before=group.before+row.count;group.rows=group.rows+1
   units=units+selection[row.key]
  end
 end
 for key in pairs(selection)do assert(keys[key],'Вибраний предмет зник із рюкзака.')end
 assert(units>0,'Виберіть предмети.')
 for _,row in ipairs(rows)do
  assert(not groups[row.item.id]or selection[row.key],'Для цього типу потрібно вибрати всі його екземпляри в рюкзаку.')
 end
 local result={}
 for id,group in pairs(groups)do
  assert(group.units==group.before or group.rows==1,'Частину стопки можна передати, якщо вона єдина цього типу в рюкзаку.')
  result[#result+1]={template=id,units=group.units,before=group.before}
 end
 table.sort(result,function(a,b)return a.template<b.template end)
 assert(#result<=64,'За одну пожертву доступно не більше 64 типів предметів.')
 return result,units
end
function M.new(backend,snapshot,rows,selection)
 if backend.supportsExactItems and snapshot and snapshot.checksum and snapshot.checksumBusy==0 then
  return dofile(DIR..'/exact_gear_payment.lua').new(backend,snapshot,rows,selection)
 end
 local groups,units=M.plan(rows,selection)
 local created=os.time();local before=0;for _,group in ipairs(groups)do before=before+group.before end
 local payment={template='gear_batch',units=units,beforeUnits=before,groups=groups,identities={},offer={entity='batch',database='batch',slot='batch'}}
 for _,row in ipairs(rows)do if selection[row.key]then
  payment.identities[#payment.identities+1]={template=row.item.id,entity=row.entity,database=row.database,slot=row.slot,count=selection[row.key]}
 end end
 local function context()
  local s=backend:context()
  assert(snapshot and snapshot.kind=='backpack'and s.controller:GetAddress()==snapshot.controller
   and s.pawn:GetAddress()==snapshot.pawn and s.controller:GetWorld():GetAddress()==snapshot.world,'Inventory context changed.')
  local inv=s.pawn.m_BackpackInventoryComponent:GetInventory()
  assert(valid(inv)and inv:GetAddress()==snapshot.inventory,'Backpack changed.')
  return s
 end
 function payment.checkDebit()
  assert(os.time()-created<=5,'Підтвердження застаріло. Оновіть список.')
  local s=context();assert(not backend.busy,'Wait for the previous donation.')
  for _,group in ipairs(groups)do
   local key=template(group.template)
   assert(s.pawn:GetNumberOfItemsInEquipmentInventory(key)==0 and s.pawn:GetNumberOfItemsInAbilityInventory(key)==0,'Предмет цього типу екіпірований. Зніміть його або виключіть цей тип із пожертви.')
   assert(s.pawn:GetNumberOfItemsInInventory(key)==group.before and s.pawn:GetNumberOfItemsInBackpackInventory(key)==group.before,'Кількість предметів змінилася. Оновіть список.')
  end
  local path='/Script/DuneSandbox.DuneCharacter:RemoveItemAmountFromBackpackByTemplateId'
  local fn=StaticFindObject(path);assert(valid(fn),'Item debit unavailable.')
  local actual={};fn:ForEachProperty(function(p)actual[#actual+1]=p:GetFullName()end)
  local expected={'StructProperty','IntProperty','EnumProperty','StrProperty','BoolProperty'}
  local names={'InItemTemplateID','Amount','Reason','ItemAddDetails','ReturnValue'}
  assert(#actual==#expected,'Item debit signature changed.')
  for i,kind in ipairs(expected)do assert(actual[i]==kind..' '..path..':'..names[i],'Item debit parameter changed.')end
  local reasons=StaticFindObject('/Script/DuneSandboxCore.EInventoryItemAddReason')
  assert(valid(reasons)and reasons:GetNameByValue(31):ToString()=='EInventoryItemAddReason::Landsraad','Inventory reason changed.')
 end
 function payment.read(pawn)
  local s=context();assert(pawn:GetAddress()==s.pawn:GetAddress(),'Character changed.')
  local total=0
  for _,group in ipairs(groups)do
   local key=template(group.template)
   local count=pawn:GetNumberOfItemsInBackpackInventory(key)
   assert(pawn:GetNumberOfItemsInInventory(key)==count and pawn:GetNumberOfItemsInEquipmentInventory(key)==0
    and pawn:GetNumberOfItemsInAbilityInventory(key)==0,'Предмети переміщені під час пожертви.')
   assert(count>=group.before-group.units and count<=group.before,'Unexpected item count.')
   total=total+count
  end
  return total
 end
 function payment.debit(pawn,count,id)
  assert(count==units and type(id)=='string'and id:match('^[%d%-]+$'),'Invalid item debit.')
  -- Recheck while still outside the busy kernel, then verify again immediately before each native call.
  local s=context();assert(pawn:GetAddress()==s.pawn:GetAddress()and os.time()-created<=5,'Item confirmation expired.')
  for _,group in ipairs(groups)do
   local key=template(group.template)
   assert(pawn:GetNumberOfItemsInInventory(key)==group.before and pawn:GetNumberOfItemsInBackpackInventory(key)==group.before
    and pawn:GetNumberOfItemsInEquipmentInventory(key)==0 and pawn:GetNumberOfItemsInAbilityInventory(key)==0,'Item count changed before debit.')
  end
  for _,group in ipairs(groups)do
   local key=template(group.template)
   assert(pawn:GetNumberOfItemsInInventory(key)==group.before and pawn:GetNumberOfItemsInBackpackInventory(key)==group.before
    and pawn:GetNumberOfItemsInEquipmentInventory(key)==0 and pawn:GetNumberOfItemsInAbilityInventory(key)==0,'Item moved before native debit.')
   backend:journal(id..' item_debit_intent template='..group.template..' units='..group.units)
   assert(pawn:RemoveItemAmountFromBackpackByTemplateId(key,group.units,31,'Landsraad Donations '..id)==true,'Item debit uncertain; do not repeat.')
   backend:journal(id..' item_debit_called template='..group.template..' units='..group.units)
  end
 end
 payment.checkDebit()
 return payment
end
return M
