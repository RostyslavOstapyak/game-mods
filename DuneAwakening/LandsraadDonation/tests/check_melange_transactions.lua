local directory,source,mode=...
local melange,removals,grants,bank,personal=1043,0,0,100000,1000
local queue={}
local valid=function()return true end
local pawn={Role=3,IsValid=valid,GetAddress=function()return mode=='pawn_change'and removals>0 and 99 or 43 end}
local pc={Role=3,GetAddress=function()return 42 end}
local function p(s)return{GetFullName=function()return s end}end
function FName(s)return{ToString=function()return s end}end
function StaticFindObject(path)
 local o={IsValid=valid,IsSoloPlay=function()return true end}
 function o:GetNameByValue(v)assert(v==31);return FName('EInventoryItemAddReason::Landsraad')end
 function o:ForEachProperty(callback)
  local fields
  if path:match('GetNumberOfItemsInBackpackInventory$')then fields={'StructProperty InItemTemplateID','IntProperty ReturnValue'}
  elseif path:match('RemoveItemAmountFromBackpackByTemplateId$')then fields={'StructProperty InItemTemplateID','IntProperty Amount','EnumProperty Reason','StrProperty ItemAddDetails','BoolProperty ReturnValue'}
  elseif path:match('AddSolarisToAccount$')then fields={'Int64Property Quantity'}
  else fields={'IntProperty SlotIndex','IntProperty ProgressIncrease'}end
  for _,v in ipairs(fields)do local kind,key=v:match('(%S+) (%S+)');callback(p(kind..' '..path..':'..key))end
 end
 return o
end
local inv={IsValid=valid,IsInitialContentReceived=function()return mode~='loading'end}
pawn.m_BackpackInventoryComponent={IsValid=valid,GetInventory=function()return inv end}
function pawn:GetNumberOfItemsInBackpackInventory(t)assert(t.Name:ToString()=='MelangeSpice');return melange end
function pawn:RemoveItemAmountFromBackpackByTemplateId(t,units,reason,details)
 assert(t.Name:ToString()=='MelangeSpice'and units==17 and reason==31 and details:find('Landsraad Donations'))
 removals=removals+1
 if mode~='no_removal'then melange=melange-units end
 if mode=='partial'then melange=melange+1 end
 if mode=='call_error'then error('Injected failure after native item action')end
 return mode~='false_return'
end
local manager={IsValid=valid}
function manager:AddSolarisToAccount()error('Melange must not alter bank or refund with Solari')end
function manager:DebugLandsraadInsertTaskProgress(_,points)
 assert(removals==1 and melange==1026 and points==1020,'Contribution before exact payment receipt')
 grants=grants+1;if mode~='no_receipt'then personal=personal+points end
end
pc.CheatManager=manager
local app={session=function()return{ok=true,controller=pc,pawn=pawn}end}
function app:defer(_,callback)queue[#queue+1]=callback;return{}end
LDPersonalProgress={fullReceivedAt=os.time(),fullVersion=1}
local reads=0
function LDPersonalProgress:snapshot()
 reads=reads+1
 self.fullVersion=self.fullVersion+1
 return{[0]=mode=='delayed_receipt'and reads<35 and 1000 or personal}
end
local settings={solariPerContribution=1000,solariPerMelange=60000,maxContributionPerTransaction=6000,specializationXpEnabled=false}
local module=dofile(source..'/Scripts/donations.lua')
local backend=module.new(app,settings,directory)
function backend:balance()return bank end
function backend:board()return{term=mode=='cycle_change'and removals>0 and 7 or 6,competition=true,balance=bank,session={controller=pc,pawn=pawn},houses={{id='DA_HouseAlexin',index=0,completed=false}}}end
if mode=='insufficient'then melange=16 end
local function donate()return backend:donate('DA_HouseAlexin',1000,6,'melange')end
local ok=pcall(donate)
if mode=='insufficient'or mode=='loading'then
 assert(not ok and removals==0 and grants==0 and not backend.busy);return true
end
assert(ok and backend.busy and removals==1)
assert(not pcall(donate)and removals==1)
local steps=0
while #queue>0 do steps=steps+1;assert(steps<160);table.remove(queue,1)()end
assert(removals==1 and bank==100000)
if mode=='success'or mode=='delayed_receipt'then
 assert(not backend.busy and personal==2020 and melange==1026 and grants==1)
 assert(not module.new(app,settings,directory).busy)
else
 assert(backend.busy and module.new(app,settings,directory).busy,'Uncertain item payment must remain locked after restart')
 if mode~='no_receipt'then assert(grants==0)end
end
return true
