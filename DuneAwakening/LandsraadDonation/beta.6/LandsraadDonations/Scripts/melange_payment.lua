local M={template='MelangeSpice'}
local function signature(name,fields)
 local path='/Script/DuneSandbox.DuneCharacter:'..name
 local f=StaticFindObject(path);assert(f and f:IsValid(),'Melange interface unavailable: '..name)
 local actual={};f:ForEachProperty(function(p)actual[#actual+1]=p:GetFullName()end)
 assert(#actual==#fields,'Melange interface changed: '..name)
 for i,field in ipairs(fields)do
  local kind,key=field:match('(%S+) (%S+)')
  assert(actual[i]==kind..' '..path..':'..key,'Melange parameter changed: '..name)
 end
end
local function template()
 local name=FName(M.template,FNAME_Find);assert(name:ToString()==M.template,'Melange template unavailable.')
 return{Name=name}
end
function M.read(pawn)
 assert(pawn and pawn:IsValid(),'Character unavailable.')
 signature('GetNumberOfItemsInBackpackInventory',{'StructProperty InItemTemplateID','IntProperty ReturnValue'})
 local component=pawn.m_BackpackInventoryComponent;assert(component and component:IsValid(),'Backpack unavailable.')
 local inventory=component:GetInventory();assert(inventory and inventory:IsValid()and inventory:IsInitialContentReceived(),'Backpack is still loading.')
 local amount=pawn:GetNumberOfItemsInBackpackInventory(template())
 assert(type(amount)=='number'and amount%1==0 and amount>=0 and amount<=2147483647,'Invalid Melange quantity.')
 return amount
end
function M.checkDebit()
 signature('RemoveItemAmountFromBackpackByTemplateId',{'StructProperty InItemTemplateID','IntProperty Amount','EnumProperty Reason','StrProperty ItemAddDetails','BoolProperty ReturnValue'})
 local reason=StaticFindObject('/Script/DuneSandboxCore.EInventoryItemAddReason')
 assert(reason and reason:IsValid()and reason:GetNameByValue(31):ToString()=='EInventoryItemAddReason::Landsraad','Landsraad item reason changed.')
end
function M.debit(pawn,units,id)
 assert(type(units)=='number'and units%1==0 and units>=1 and units<=2147483647,'Invalid Melange payment quantity.')
 M.checkDebit();assert(M.read(pawn)>=units,'Недостатньо меланжу в рюкзаку.')
 -- One native action. A false return or uncertain receipt must never trigger retry.
 assert(pawn:RemoveItemAmountFromBackpackByTemplateId(template(),units,31,'Landsraad Donations '..id)==true,'Melange removal was not confirmed by the game.')
end
return M
