-- Our optional read-only host, invoked from the existing NBS Core Lua state.
-- No item writes, Stash sessions, hooks, private offsets, or foreign code copies.
return function(later,player,shared)
 local prefix='LandsraadDonations.InventoryBridge.1.'
 local requestKey,responseKey=prefix..'request',prefix..'response'
 local seen,pending=nil,nil
 local checksumReported=false
 local function valid(o)return o and o:IsValid()end
 local function reply(id,state,missing,data)
  shared:SetSharedVariable(responseKey,table.concat({id,state,tostring(missing),data or''},'\n'))
 end
 local function context(pcId,pawnId,worldId)
  local pc=player();assert(valid(pc)and tostring(pc:GetAddress())==pcId,'Controller changed.')
  local pawn=pc.Pawn;local world=pc:GetWorld()
  assert(valid(pawn)and valid(world)and tostring(pawn:GetAddress())==pawnId and tostring(world:GetAddress())==worldId,'Player/world changed.')
  assert(pc.Role==3 and pawn.Role==3,'Local authority required.')
  local gui=StaticFindObject('/Script/DuneSandbox.Default__GUIBlueprintLibrary')
  assert(valid(gui)and gui:IsSoloPlay(pawn),'Singleplayer required.')
  local inventory=pawn.m_BackpackInventoryComponent:GetInventory()
  assert(valid(inventory)and inventory:IsInitialContentReceived(),'Backpack not ready.')
  return inventory:GetAddress(),pawn.m_BackpackInventoryComponent:GetAddress()
 end
 local function checksum(inventory,component)
  if type(NBS_InventoryChecksum)~='function'then return nil,nil,'NBS_InventoryChecksum missing'end
  local ok,sum,busy=pcall(NBS_InventoryChecksum,inventory,component)
  if ok and type(sum)=='number'and sum%1==0 and sum>=0 and sum<=4294967295 and busy==0 then return sum,0 end
  return nil,nil,ok and('Unavailable/busy: '..tostring(sum)..' / '..tostring(busy))or tostring(sum)
 end
 local function tick()
  local ok,err=pcall(function()
   local request=shared:GetSharedVariable(requestKey)
   if type(request)=='string'and request~=seen then
    assert(#request<=256,'Reader request too large.')
    local id,pc,pawn,world=request:match('^(%d+%-%d+)\t(%d+)\t(%d+)\t(%d+)$')
    seen=request
    if id then pending={id=id,pc=pc,pawn=pawn,world=world,tries=0}end
   end
   if not pending then return end
   local p=pending;p.tries=p.tries+1;assert(p.tries<=40,'Reader timed out.')
   local inventory,component=context(p.pc,p.pawn,p.world)
   if not p.started then p.started=true;p.checksum=checksum(inventory,component)end
   assert(type(NBS_PadScan)=='function','NBS_PadScan missing in host.')
   local payload,missing,state,reason=NBS_PadScan(inventory)
   if state=='scanning'then return end
   if state=='off'then error(tostring(reason))end
   assert(missing==0 and type(payload)=='string'and #payload<=1048576,'Incomplete native response.')
   local sum,busy,checksumWhy=checksum(inventory,component)
   if p.checksum and sum then assert(sum==p.checksum,'Backpack changed while being read.')end
   if not p.checksum then sum=nil;busy=nil;checksumWhy=checksumWhy or'Checksum unavailable at read start'end
   shared:SetSharedVariable(prefix..'checksum',table.concat({p.id,tostring(sum or'-'),tostring(busy or'-')},'\t'))
   if not checksumReported then
    checksumReported=true
    print('[LD_CHECKSUM] Backpack read checksum '..(sum and('available: '..tostring(sum))or('unavailable: '..tostring(checksumWhy)))..' (read-only).\n')
   end
   reply(p.id,'ok',0,payload);pending=nil
  end)
  if not ok then
   if pending then reply(pending.id,'error',1,tostring(err):gsub('[\r\n]',' '):sub(1,400));pending=nil end
   print('[LD_READER_HOST] '..tostring(err)..'\n')
  end
  later(250,tick)
 end
 later(250,tick)
 shared:SetSharedVariable(prefix..'ready','1')
 shared:SetSharedVariable(prefix..'checksumVersion','1')
 print('[LD_READER_HOST] read-only host scheduled in NBS Core.\n')
end
