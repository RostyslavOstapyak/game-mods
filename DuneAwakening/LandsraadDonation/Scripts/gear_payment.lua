-- Backpack-only removal of templates with exactly one eligible unit.
-- This avoids claiming an entity-specific debit from a template-based native interface.
local M={}

local function valid(o)return o and o:IsValid()end
local function template(id)
 assert(type(id)=='string'and id:match('^[%w_]+$'),'Invalid item template.')
 local name=FName(id,FNAME_Find);assert(name:ToString()==id,'Item template changed.')
 return{Name=name}
end
function M.plan(rows,selection)
 local selected,groups={},{}
 for _,row in ipairs(rows)do
  if selection[row.key]~=nil then
   local id=row.item.id
   assert(row.key=='type:'..id and not selected[row.key] and row.count==1
    and selection[row.key]==1,'Select one eligible item per template.')
   selected[row.key]=true
   groups[#groups+1]={template=id,units=1,before=1}
  end
 end
 for key in pairs(selection)do assert(selected[key],'Selected item is no longer eligible.')end
 assert(#groups>0 and #groups<=64,'Select between 1 and 64 eligible items.')
 table.sort(groups,function(a,b)return a.template<b.template end)
 return groups,#groups
end
function M.new(backend,snapshot,rows,selection)
 local groups,units=M.plan(rows,selection)
 local created=os.time();local before=0;for _,group in ipairs(groups)do before=before+group.before end
 local payment={template='gear_batch',units=units,beforeUnits=before,groups=groups,identities={},offer={entity='batch',database='batch',slot='batch'}}
 for _,row in ipairs(rows)do if selection[row.key]then
  payment.identities[#payment.identities+1]={key=row.key,template=row.item.id,count=selection[row.key]}
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
