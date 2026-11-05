-- Narrow first live debit test: one unique compactor in backpack, none elsewhere on the character.
-- Not called at startup or from the donation UI. No progression/XP action in this probe.
local M={template='StaticCompactor_Unique_Compact_06'}
local function valid(o)return o and o:IsValid()end
local function identity()
 local name=FName(M.template,FNAME_Find);assert(name:ToString()==M.template,'Compactor template changed.');return{Name=name}
end
local function signature(name,expected)
 local path='/Script/DuneSandbox.DuneCharacter:'..name
 local fn=StaticFindObject(path);assert(valid(fn),'Missing compactor interface: '..name)
 local actual={};fn:ForEachProperty(function(p)actual[#actual+1]=p:GetFullName()end)
 assert(#actual==#expected,'Changed compactor interface: '..name)
 for i,p in ipairs(expected)do assert(actual[i]==p..' '..path..':'..(i==1 and'InItemTemplateID'or i==2 and'Amount'or i==3 and'Reason'or i==4 and'ItemAddDetails'or'ReturnValue'),'Changed compactor parameter.')end
end
function M.preflight(backend,snapshot,rows,operationId)
 assert(not backend.busy or(operationId and(backend.compactorTestId==operationId or backend.itemPaymentOperationId==operationId)),'Donation backend is busy.')
 local s=backend:context()
 assert(snapshot and snapshot.kind=='backpack'and s.controller:GetAddress()==snapshot.controller
  and s.pawn:GetAddress()==snapshot.pawn and s.controller:GetWorld():GetAddress()==snapshot.world,'Compactor snapshot context changed.')
 local inv=s.pawn.m_BackpackInventoryComponent:GetInventory();assert(valid(inv)and inv:GetAddress()==snapshot.inventory,'Backpack changed.')
 local found
 for _,row in ipairs(rows)do if row.item.id==M.template then assert(not found,'Several compactors in backpack.');found=row end end
 assert(found and found.count==1 and found.entity and found.database,'Exactly one compactor instance is required.')
 local key=identity()
 assert(s.pawn:GetNumberOfItemsInInventory(key)==1 and s.pawn:GetNumberOfItemsInBackpackInventory(key)==1,'Compactor is not unique on character.')
 assert(s.pawn:GetNumberOfItemsInEquipmentInventory(key)==0 and s.pawn:GetNumberOfItemsInAbilityInventory(key)==0,'Compactor is equipped.')
 signature('RemoveItemAmountFromBackpackByTemplateId',{'StructProperty','IntProperty','EnumProperty','StrProperty','BoolProperty'})
 local reasons=StaticFindObject('/Script/DuneSandboxCore.EInventoryItemAddReason')
 assert(valid(reasons)and reasons:GetNameByValue(31):ToString()=='EInventoryItemAddReason::Landsraad','Inventory reason changed.')
 return {controller=snapshot.controller,pawn=snapshot.pawn,world=snapshot.world,inventory=snapshot.inventory,
  entity=found.entity,database=found.database,slot=found.slot,template=M.template,bank=backend:balance(s.controller)}
end
function M.debit(backend,offer,operationId,freshSnapshot,freshRows)
 assert(type(operationId)=='string'and operationId:match('^[%d%-]+$'),'Invalid operation id.')
 local fresh=M.preflight(backend,freshSnapshot,freshRows,operationId)
 for _,field in ipairs({'controller','pawn','world','inventory','entity','database','slot','template','bank'})do
  assert(fresh[field]==offer[field],'Compactor changed since selection: '..field)
 end
 local s=backend:context();local key=identity()
 assert(s.controller:GetAddress()==offer.controller and s.pawn:GetAddress()==offer.pawn
  and s.controller:GetWorld():GetAddress()==offer.world,'Player changed before compactor debit.')
 assert(s.pawn.m_BackpackInventoryComponent:GetInventory():GetAddress()==offer.inventory,'Backpack changed.')
 assert(s.pawn:GetNumberOfItemsInInventory(key)==1 and s.pawn:GetNumberOfItemsInBackpackInventory(key)==1,'Compactor count changed.')
 assert(s.pawn:GetNumberOfItemsInEquipmentInventory(key)==0 and s.pawn:GetNumberOfItemsInAbilityInventory(key)==0,'Compactor moved to equipment.')
 assert(backend:balance(s.controller)==offer.bank,'Bank changed before test.')
 -- Sole-template-instance constraint is essential: this native API selects by template, not entity id.
 assert(s.pawn:RemoveItemAmountFromBackpackByTemplateId(key,1,31,'Landsraad Donations compactor test '..operationId)==true,'Compactor removal returned no confirmation; never retry.')
end
function M.receipt(backend,offer)
 local s=backend:context();assert(s.controller:GetAddress()==offer.controller and s.pawn:GetAddress()==offer.pawn,'Player changed before receipt.')
 local key=identity()
 assert(s.pawn:GetNumberOfItemsInInventory(key)==0 and s.pawn:GetNumberOfItemsInBackpackInventory(key)==0,'Compactor disappearance not confirmed.')
 assert(backend:balance(s.controller)==offer.bank,'Bank changed during compactor test.')
 return true
end
return M
