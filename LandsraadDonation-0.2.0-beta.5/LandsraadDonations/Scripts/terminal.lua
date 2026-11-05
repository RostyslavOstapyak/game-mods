local M={}
local DIR=debug.getinfo(1,'S').source:sub(2):gsub('\\','/'):match('^(.*)/[^/]+$')
local L=dofile(DIR..'/localization.lua')
local geometry=dofile(DIR..'/terminal_geometry.lua')
local CLASS='BP_LandsraadDonations_Terminal_C'
local function valid(o)return o and o:IsValid()end
function M.new(app,getPanel)
 local self={active=true}
 local input=dofile(DIR..'/context_input.lua').new(app)
 self.escape=dofile(DIR..'/ui_escape.lua').attach(app,getPanel)
 local scanElapsed=0
 function self:inputTick()
  app._controller=nil;local session=app:session()
  if not session.ok then input:reset();self:hide();return end
  local panel=getPanel()
  local interact=input:pressed(session.controller,'E')
  if panel and(panel.handle or panel.loading)then
   return
  end
  if interact then
   local target=self:target()
   if target then self:hide();getPanel():open()end
  end
 end
 function self:hide()
  if self.prompt then self.prompt:close();self.prompt=nil end
 end
 function self:target()
  local panel=getPanel();if panel and(panel.handle or panel.loading)then return nil end
  app._controller=nil;local s=app:session()
  if not s.ok or s.controller.bShowMouseCursor then return nil end
  local hud=s.controller:GetHUD()
  if not valid(hud)or valid(hud:GetActiveWindow())then return nil end
  local class=StaticFindObject('/NBS/Buildables/BP_LandsraadDonations_Terminal.'..CLASS)
  if not valid(class)then return nil end
  local camera=s.controller.PlayerCameraManager;if not valid(camera)then return nil end
  local pawnPosition=s.pawn:K2_GetActorLocation()
  local cameraPosition,rotation=camera:GetCameraLocation(),camera:GetCameraRotation()
  local world=s.pawn:GetWorld();if not valid(world)then return nil end
  local ownerWorld=world:GetAddress()
  local best,score
  local actors=FindAllOf(CLASS)or{};assert(#actors<=128,'Too many Landsraad terminals in the loaded world.')
  for _,actor in ipairs(actors)do
   if valid(actor)and actor:GetClass():GetFullName():match('^[^ ]+ (.+)$')=='/NBS/Buildables/BP_LandsraadDonations_Terminal.'..CLASS then
    local actorWorld=actor:GetWorld()
    if valid(actorWorld)and actorWorld:GetAddress()==ownerWorld then
     local value=geometry.score(pawnPosition,cameraPosition,rotation,actor:K2_GetActorLocation())
     if value and(not score or value>score)and s.controller:LineOfSightTo(actor,cameraPosition,false)then best,score=actor:GetAddress(),value end
    end
   end
  end
  return best,s.controller
 end
 function self:show(pc)
  if self.prompt then return end
  local handle,reason=app:ui_create('/Script/DuneSandbox.DuneUserWidget',{z_order=940})
  assert(handle,reason and reason.message);self.prompt=handle
  local tree=handle.widget.WidgetTree
  local label=StaticConstructObject(StaticFindObject('/Script/UMG.TextBlock'),tree,0,0)
  assert(valid(label),'Terminal prompt unavailable.')
  label:SetText(FText(L.t('ui.148')));label.Font.Size=20;label:SetJustification(1)
  label:SetColorAndOpacity({SpecifiedColor={r=.95,G=.83,B=.59,A=1},ColorUseRule=0});label:SetVisibility(3)
  handle.widget:RemoveFromParent();tree.RootWidget=label
  local layout=StaticFindObject('/Script/UMG.Default__WidgetLayoutLibrary');local size=layout:GetViewportSize(pc)
  handle.widget:SetDesiredSizeInViewport({X=400,Y=40});handle.widget:SetAlignmentInViewport({X=.5,Y=.5})
  handle.widget:SetPositionInViewport({X=size.X/2,Y=size.Y*.73},true);handle.widget:SetVisibility(3)
  handle.widget:AddToViewport(940)
 end
 function self:poll()
  if L.refresh()then self:hide()end
  local ok,address=pcall(function()
   local target,pc=self:target()
   if target then self:show(pc)else self:hide()end
   return target
  end)
  if not ok then self:hide()end
  if not ok and tostring(address)~=self.lastError then
   self.lastError=tostring(address);print('[LandsraadDonations] Terminal paused: '..self.lastError..'\n')
  end
 end
 function self:cancel()
  self.active=false
  if self.escape then self.escape:cancel()end
  if self.timer then self.timer:cancel()end
  if self.binding then self.binding:cancel()end
  self:hide()
 end
 local timer,reason=app:every{interval_ms=20,callback=function()
  if not self.active then return end
  local ok,err=pcall(function()self:inputTick()end)
  if not ok then
   self:hide()
   if tostring(err)~=self.inputError then self.inputError=tostring(err);print('[LandsraadDonations] Context input unavailable: '..self.inputError..'\n')end
  end
  scanElapsed=scanElapsed+20
  if scanElapsed>=500 then scanElapsed=0;self:poll()end
 end}
 assert(timer,reason and reason.message);self.timer=timer
 print('[LandsraadDonations] Context input ready: E/Escape read without exclusive bindings.\n')
 return self
end
return M
