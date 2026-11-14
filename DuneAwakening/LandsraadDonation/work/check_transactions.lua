-- Offline fake world: never loads UE4SS, game, or installed mod.
local directory,source,mode=...
local bank,personal,debits,grants=100000,4000,0,0
local xpAmount,xpCalls=9100,0
local xpMode=mode:match('^xp_')~=nil
local changed=false
local queue={}
local pc={Role=3,GetAddress=function()return changed and 43 or 42 end}
local pawn={Role=3}
local function name(s)return{GetFullName=function()return s end}end
function StaticFindObject(path)
 local o={IsValid=function()return true end,IsSoloPlay=function()return true end}
 local command=path:match('DuneCheatManager:(.+)$')
 if command then
  function o:ForEachProperty(callback)
   local prefix='/Script/DuneSandbox.DuneCheatManager:'..command..':'
   if command=='AddSolarisToAccount'then callback(name('Int64Property '..prefix..'Quantity'))
   elseif command=='AddXPToSpecializationTrack'then callback(name('EnumProperty '..prefix..'Track'));callback(name('IntProperty '..prefix..'XPAmount'))
   else callback(name('IntProperty '..prefix..'SlotIndex'));callback(name('IntProperty '..prefix..'ProgressIncrease'))end
  end
 end
 if path:match('CharacterSpecializationComponent:GetTrackProgression$')then
  function o:ForEachProperty(callback)
   callback(name('EnumProperty '..path..':TrackType'));callback(name('StructProperty '..path..':ReturnValue'))
  end
 end
 return o
end
local manager={IsValid=function()return true end}
function manager:AddSolarisToAccount(amount)
 if amount>0 and mode=='refund_error'then error('Injected refund failure')end
 bank=bank+amount
 if amount<0 then debits=debits+1;if mode=='payment_error'then error('Injected payment error after debit')end end
end
function manager:DebugLandsraadInsertTaskProgress(index,points)
 grants=grants+1
 if mode~='no_receipt'then personal=personal+points end
 if mode=='extra_progress'then personal=personal+1 end
 if mode=='xp_external_change'then xpAmount=xpAmount+10 end
end
function manager:AddXPToSpecializationTrack(track,amount)
 assert(track==1 and amount==1000)
 xpCalls=xpCalls+1
 if mode~='xp_missing'then xpAmount=xpAmount+amount end
 if mode=='xp_extra'then xpAmount=xpAmount+1 end
 if mode=='xp_call_error'then error('Injected XP error after native action')end
end
pc.m_CharacterSpecializationComponent={IsValid=function()return true end,
 GetTrackProgression=function()return{m_TrackType=1,m_XPAmount=xpAmount,m_Level=mode=='xp_cap'and 100 or 38.5}end}
pc.CheatManager=manager
local app={session=function()return{ok=true,controller=pc,pawn=pawn}end}
function app:defer(ms,callback)
 if mode=='schedule_error'then return nil end
 queue[#queue+1]=callback;return{}
end
local version=1
LDPersonalProgress={fullReceivedAt=os.time(),fullVersion=version}
function LDPersonalProgress:snapshot()
 if mode~='stale_receipt'or grants==0 then version=version+1;self.fullVersion=version end
 return{[15]=personal}
end
local settings={solariPerContribution=1000,minSolariDonation=1000,maxSolariDonation=6000000,maxContributionPerTransaction=6000}
if xpMode then
 settings.specializationXpEnabled=true;settings.specializationXpPerPoint=1000
 local nativeDofile=dofile
 local nativeXP=nativeDofile(source..'/Scripts/specialization_xp.lua')
 nativeXP.resolve=function(house)assert(house=='DA_HouseMoritani');return 1 end
 dofile=function(path)
  if path==directory..'/Scripts/specialization_xp.lua'then return nativeXP end
  if path==directory..'/Scripts/xp_policy.lua'then return nativeDofile(source..'/Scripts/xp_policy.lua')end
  return nativeDofile(path)
 end
end
local module=dofile(source..'/Scripts/donations.lua')
local backend=module.new(app,settings,directory)
function backend:balance()return bank end
function backend:board()
 return{term=((mode=='cycle_change'or mode=='refund_error')and debits>0)and 7 or 6,competition=true,
  balance=bank,session={controller=pc,pawn=pawn},
  houses={{id='DA_HouseMoritani',index=15,name='Moritani',completed=true}}}
end
local function donate()return backend:donate('DA_HouseMoritani',1,6)end
if mode=='not_ready'then
 LDPersonalProgress.fullReceivedAt=nil
 assert(not pcall(donate)and debits==0 and grants==0 and not backend.busy)
 return true
end
if mode=='checkpoint_error'then
 local originalOpen=io.open
 io.open=function(path,access)
  if path:match('transaction%-state%.log$')and access=='a'then return nil,'Injected write failure' end
  return originalOpen(path,access)
 end
 assert(not pcall(donate)and debits==0 and grants==0 and backend.busy)
 io.open=originalOpen
 return true
end
local originalOpen=io.open
if mode=='complete_checkpoint_error'then
 io.open=function(path,access)
  if path:match('transaction%-state%.log$')and access=='a'and grants>0 then return nil,'Injected final checkpoint failure' end
  return originalOpen(path,access)
 end
end
donate()
assert(backend.busy,'In-flight operation must block another payment')
assert(not pcall(donate)and debits==1,'Duplicate debit')
if mode=='crash_after_debit'then
 local recovered=module.new(app,settings,directory)
 assert(recovered.busy and debits==1 and grants==0,'Restart must lock without replay/refund')
 return true
end
if mode=='owner_change'then changed=true end
if mode=='balance_change'then bank=bank+5 end
local steps=0
while #queue>0 do
 steps=steps+1;assert(steps<160,'Unbounded retry')
 table.remove(queue,1)()
end
io.open=originalOpen
if mode=='success'or mode=='xp_success'or mode=='xp_cap'then
 assert(not backend.busy and bank==99000 and personal==4001 and grants==1)
 assert(not module.new(app,settings,directory).busy,'Confirmed payment must stay complete after restart')
 if mode=='xp_success'then assert(xpAmount==10100 and xpCalls==1)end
 if mode=='xp_cap'then assert(xpAmount==9100 and xpCalls==0)end
elseif mode=='cycle_change'then
 assert(not backend.busy and bank==100000 and personal==4000 and grants==0,'Refund must be verified without contribution')
 assert(not module.new(app,settings,directory).busy)
else
 assert(backend.busy,'Uncertain outcome must stay locked')
 assert(module.new(app,settings,directory).busy,'Restart must not clear uncertain operation')
 assert(debits==1 and grants<=1,'No automatic retry of a native action')
 if xpMode then assert(xpCalls==(mode=='xp_external_change'and 0 or 1),'XP must never be retried')end
end
return true
