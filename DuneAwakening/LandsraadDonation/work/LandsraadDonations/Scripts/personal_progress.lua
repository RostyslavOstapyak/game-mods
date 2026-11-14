local M={}
local PREFIX='/Script/DuneSandbox.'
local FULL='LandsraadActionListenBoardStateResponse'
local DELTA='LandsraadActionListenBoardStateProgressUpdatedResponse'
local DIR=debug.getinfo(1,'S').source:sub(2):gsub('\\','/'):match('^(.*)/[^/]+$')
local factionReader=dofile(DIR..'/board_progress.lua')
local function valid(o)return o and o:IsValid()end
function M.new(app,previous)
 local self=previous or{values={},epoch=0}
 function self:collect(className,address,epoch)
  if epoch~=self.epoch then return end
  app._controller=nil
  local s=app:session();if not s.ok or s.controller:GetAddress()~=self.owner then return end
  local g=StaticFindObject('/Script/Engine.Default__GameplayStatics'):GetGameState(s.pawn)
  if g.m_LandsraadReplicatedStateComponent.m_LandsraadState.m_CurrentTermId~=self.term then return end
  for _,o in ipairs(FindAllOf(className)or{})do
   if valid(o)and o:GetAddress()==address then
    local instigator=o.m_Instigator
    if not valid(instigator)or instigator:GetAddress()~=self.owner then return end
    if className==FULL then
     if o.m_LandsraadState.m_CurrentTermId~=self.term then return end
     local values={}
     o.m_PlayerContributions:ForEach(function(_,v)local r=v:get();values[r.m_BoardIndex]=r.m_PlayerProgress end)
     self.values=values;self.ready=true;self.fullVersion=(self.fullVersion or 0)+1;self.fullReceivedAt=os.time()
     local parsed,factions=pcall(function()return factionReader.read(o.m_TaskProgresses)end)
     self.factionValues=parsed and factions or nil
     if not parsed and not self.factionReadError then
      self.factionReadError=true;print('[LandsraadDonations] Board faction response unavailable: '..tostring(factions)..'\n')
     end
    elseif self.ready then
     o.m_PlayerContributionsToAddOrUpdate:ForEach(function(_,v)local r=v:get();self.values[r.m_BoardIndex]=r.m_PlayerProgress end)
    end
    self.receivedAt=os.time()
    return
   end
  end
 end
 function self:bind()
  if self.bound then return end
  self.bound=true
  for _,name in ipairs({FULL,DELTA})do
   app:notify(PREFIX..name,function(o)
    -- Keep identities only. Reacquire the response on the game thread after initialization.
    local address,epoch=o:GetAddress(),self.epoch
    app:defer(1,function()self:collect(name,address,epoch)end)
   end)
  end
 end
 function self:snapshot(pc,term)
  self:bind()
  local owner=pc:GetAddress()
  if owner~=self.owner or term~=self.term then
   self.owner=owner;self.term=term;self.values={};self.ready=false;self.requestedAt=nil;self.fullReceivedAt=nil;self.factionValues=nil;self.epoch=self.epoch+1
  end
  if not self.requestedAt or os.time()-self.requestedAt>=2 then
   local handler=pc.m_ActionHandler;assert(valid(handler),'Landsraad read interface unavailable.')
   local action=StaticConstructObject(StaticFindObject(PREFIX..'LandsraadActionListenBoardState'),handler,0,64)
   assert(valid(action),'Cannot create Landsraad read request.')
   action.m_Instigator=pc;action.m_bIsListenAction=false;action.m_bIsRequestWithCallback=true
   self.requestedAt=os.time()
   handler:ServerPerformAction({m_ActionMessage=action})
  end
  return self.ready and self.values or nil
 end
 return self
end
return M
