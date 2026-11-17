-- Read-only template totals; deliberately does not pretend to identify equipment instances.
local M={}

local function valid(o)return o and o:IsValid()end
function M.scan(app,backend,items,callback)
 local token={active=true}
 function token:cancel()self.active=false end
 local s=backend:context();local owner,pawn=s.controller:GetAddress(),s.pawn:GetAddress()
 local path='/Script/DuneSandbox.DuneCharacter:GetNumberOfItemsInBackpackInventory'
 local fn=StaticFindObject(path);assert(valid(fn),'Backpack reader unavailable.')
 local fields={};fn:ForEachProperty(function(p)fields[#fields+1]=p:GetFullName()end)
 assert(#fields==2 and fields[1]=='StructProperty '..path..':InItemTemplateID'and fields[2]=='IntProperty '..path..':ReturnValue','Backpack reader changed.')
  local inventory=s.pawn.m_BackpackInventoryComponent:GetInventory()
 assert(valid(inventory)and inventory:IsInitialContentReceived(),'Backpack is loading.')
 local snapshot={kind='backpack',controller=owner,pawn=pawn,world=s.controller:GetWorld():GetAddress(),inventory=inventory:GetAddress()}
 local at,result=1,{}
 local function batch()
  if not token.active then return end
  local ok,err=pcall(function()
   local current=backend:context()
   assert(current.controller:GetAddress()==owner and current.pawn:GetAddress()==pawn,'Character changed while reading backpack.')
   local inv=current.pawn.m_BackpackInventoryComponent:GetInventory()
   assert(valid(inv)and inv:IsInitialContentReceived()and inv:GetAddress()==snapshot.inventory and current.controller:GetWorld():GetAddress()==snapshot.world,'Backpack changed.')
   for _=1,12 do
    local item=items[at];if not item then break end;at=at+1
    local name=FName(item.id,FNAME_Find);assert(name:ToString():lower()==item.id:lower(),'Unknown item identity.')
    local count=current.pawn:GetNumberOfItemsInBackpackInventory({Name=name})
    assert(type(count)=='number'and count%1==0 and count>=0 and count<=2147483647,'Invalid item count.')
    if count==1 and current.pawn:GetNumberOfItemsInInventory({Name=name})==1
     and current.pawn:GetNumberOfItemsInEquipmentInventory({Name=name})==0
     and current.pawn:GetNumberOfItemsInAbilityInventory({Name=name})==0 then
     result[#result+1]={key='type:'..item.id,item=item,count=1}
    end
   end
   if at<=#items then assert(app:defer(100,batch))else token.active=false;callback(result,nil,snapshot)end
  end)
  if not ok then token.active=false;callback(nil,tostring(err))end
 end
 assert(app:defer(1,batch));return token
end
return M
