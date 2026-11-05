local M={}
local DIR=debug.getinfo(1,'S').source:sub(2):gsub('\\','/'):match('^(.*)/[^/]+$')
local asset=dofile(DIR..'/loaded_asset.lua')
local function valid(o)return o and o:IsValid()end
function M.new(app)
 local self={metadata={}}
 function self:ensure()end
 function self:read()
  self:ensure();app._controller=nil;local s=app:session();assert(s.ok)
  local g=StaticFindObject('/Script/Engine.Default__GameplayStatics'):GetGameState(s.pawn)
  local state=g.m_LandsraadStateComponent
  local faction=s.controller.m_LandsraadCharacterComponent.m_CachedGuildFaction
  local factionName=faction.Name:ToString()
  local states,progress,allProgress,allGoals={},{},{},{}
  state.m_LandsraadTaskStatePerFaction:ForEach(function(k,v)
   local name=k:get().Name:ToString();allGoals[name]={}
   v:get().m_TaskStates:ForEach(function(_,t)local r=t:get();allGoals[name][r.m_BoardIndex]=r.m_GoalAmount;if name==factionName then states[r.m_BoardIndex]=r end end)
  end)
  state.m_LandsraadTaskProgressPerFaction:ForEach(function(k,v)
   local name=k:get().Name:ToString();allProgress[name]={}
   v:get().m_TaskProgresses:ForEach(function(_,t)local r=t:get();allProgress[name][r.m_BoardIndex]=r.m_ProgressAmount;if name==factionName then progress[r.m_BoardIndex]=r.m_ProgressAmount end end)
  end)
  local term=g.m_LandsraadReplicatedStateComponent.m_LandsraadState.m_CurrentTermId
  local personalValues=LDPersonalProgress and LDPersonalProgress:snapshot(s.controller,term)
  -- A full personal response can omit simulated enemy progress in solo play.
  -- Keep world progress until B01's native UI source is independently verified.
  local result={}
  state.m_LandsraadTasks:ForEach(function(_,v)
   local t=v:get();local index=t.m_BoardIndex;local id=t.m_HouseName:ToString()
   local meta=self.metadata[id]
   if not meta then
    local houseAsset=asset('/Game/Dune/Systems/Landsraad/Houses/'..id..'.'..id)
    assert(valid(houseAsset),'House asset unavailable')
    meta={name=houseAsset.m_PlayerFacingName:ToString(),iconPath=StaticFindObject('/Script/Engine.Default__KismetSystemLibrary'):Conv_SoftObjectReferenceToString(houseAsset.m_HouseIcon)}
    if type(meta.iconPath)~='string'then meta.iconPath=meta.iconPath:ToString()end
    assert(type(meta.iconPath)=='string','House icon path unavailable')
    self.metadata[id]=meta
   end
   local personal=personalValues and(personalValues[index]or 0)or nil
   local st=states[index];local goal=st and st.m_GoalAmount or 0
   local rewards={}
   if st then st.m_Rewards:ForEach(function(_,item)local r=item:get();rewards[#rewards+1]={threshold=r.m_Threshold,amount=r.m_Amount,template=r.m_ItemTemplateId.Name:ToString()}end)end
   result[#result+1]={id=id,index=index,name=meta.name,iconPath=meta.iconPath,personal=personal,progress=progress[index]or 0,goal=goal,rewards=rewards,completed=t.m_bCompleted,winner=t.m_WinningFaction.Name:ToString(),won=t.m_WinningFaction.Name:ToString()==factionName}
   local house=result[#result]
   house.progressSource='world-state'
   house.atreides=(allProgress.Atreides or{})[index]or 0
   house.harkonnen=(allProgress.Harkonnen or{})[index]or 0
   house.atreidesGoal=(allGoals.Atreides or{})[index]or goal
   house.harkonnenGoal=(allGoals.Harkonnen or{})[index]or goal
   if house.atreidesGoal<=0 then house.atreidesGoal=goal end
   if house.harkonnenGoal<=0 then house.harkonnenGoal=goal end
  end)
  table.sort(result,function(a,b)return a.index<b.index end)
  return result
 end
 function self:icon(h)
  return h.iconPath~=''and asset(h.iconPath)or nil
 end
 function self:item(reward)
  self.items=self.items or{}
  local id=reward.template
  local function resolve(item)
   -- Lua UObject wrappers do not keep Unreal objects alive. Cache plain paths only.
   return{name=item.name,icon=item.iconPath and asset(item.iconPath)or nil}
  end
  if self.items[id]then return resolve(self.items[id])end
  -- Composite rows expose FString paths on this runtime; tostring() prints a wrapper address.
  local composite=asset('/Game/Dune/Systems/Items/CDT_BaseItems.CDT_BaseItems')
  local direct=valid(composite)and composite:FindRow(id)
  if direct then
   local item={name=direct.StaticData.Name:ToString()}
   local library=StaticFindObject('/Script/Engine.Default__KismetSystemLibrary')
   for _,field in ipairs({'RenderedIcon','Icon','SimpleIcon'})do
    local ok,path=pcall(function()
     local value=library:Conv_SoftObjectReferenceToString(direct[field])
     return type(value)=='string'and value or value:ToString()
    end)
    if ok and path~=''and path~='None'then
     local loaded,texture=pcall(asset,path)
     if loaded and valid(texture)then item.iconPath=path;break end
    end
   end
   self.items[id]=item;return resolve(item)
  end
  if not self.itemTables then
   asset('/Game/Dune/Systems/Items/BaseItems/DT_BaseItems_Schematics.DT_BaseItems_Schematics')
   self.itemTables={}
   for _,dt in ipairs(FindAllOf('DataTable')or{})do
    if dt:GetRowStruct():GetFullName()=='ScriptStruct /Script/DuneSandbox.BaseItemTableRow'then self.itemTables[#self.itemTables+1]=dt:GetFullName():match('^[^ ]+ (.+)$')end
   end
  end
  for _,path in ipairs(self.itemTables)do
   local dt=asset(path)
   local row=valid(dt)and dt:FindRow(id)
   if row then
    local item={name=row.StaticData.Name:ToString()}
    local ok,path=pcall(function()return StaticFindObject('/Script/Engine.Default__KismetSystemLibrary'):Conv_SoftObjectReferenceToString(row.Icon)end)
    if ok and type(path)~='string'then path=path:ToString()end
    if ok and type(path)=='string'and path~=''then item.iconPath=path end
    self.items[id]=item;return resolve(item)
   end
  end
  return{name='Предмет'}
 end
 return self
end
return M
