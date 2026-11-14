local M={}
local DIR=debug.getinfo(1,'S').source:sub(2):gsub('\\','/'):match('^(.*)/[^/]+$')
local L=dofile(DIR..'/localization.lua')
local policy=dofile(DIR..'/item_requests.lua')
local specialization=dofile(DIR..'/specialization_xp.lua')
local tracks={[1]='crafting',[2]='gathering',[3]='exploration',[4]='combat',[5]='sabotage'}
function M.new(app,directory)
 local self={version=7,items={},byId={},ready=false,loading=false,processed=0,total=0}
 local function valid(o)return o and o:IsValid()end
 function self:ensure()
  if self.ready or self.loading or self.error then return end
  self.loading=true
  local path='/Game/Dune/Systems/Items/CDT_BaseItems.CDT_BaseItems'
  local ok,err=pcall(function()
   local dt=StaticFindObject(path)
   if not valid(dt)then dt=LoadAsset(path)end
   assert(valid(dt),'Item table unavailable.')
   local names={};for _,v in ipairs(dt:GetRowNames())do names[#names+1]=type(v)=='string'and v or v:ToString()end
   assert(#names<=20000);table.sort(names);self.total=#names
   local at=1
   local function batch()
    local worked,why=pcall(function()
     -- Reacquire loaded objects instead of retaining wrappers across frames or reloading assets.
     local tableObject=StaticFindObject(path)
     if not valid(tableObject)then tableObject=LoadAsset(path)end
     assert(valid(tableObject))
     local started=os.clock()
     for _=1,96 do
      local id=names[at];if not id then break end;at=at+1
      local row=tableObject:FindRow(id)
      if row and row.StaticData.bIsEnabled and not row.bIsDeprecated then
       local tags={};row.StaticData.ItemTags.GameplayTags:ForEach(function(_,v)tags[#tags+1]=v:get().TagName:ToString()end)
       local item={id=id,tags=tags,enabled=true,deprecated=false,name=row.StaticData.Name:ToString()}
       local readBase,base=pcall(function()return row.StaticData.BaseBuyFromVendorPrice end)
       if readBase and type(base)=='number'then item.baseValue=base end
       for _,category in pairs(tracks)do if policy.eligible(item,category)then
        self.items[#self.items+1]=item;self.byId[id]=item;break
       end end
      end
      self.processed=at-1
      if os.clock()-started>=.004 then break end
     end
     if at<=#names then assert(app:defer(16,batch))else
      self.store=dofile(DIR..'/request_store.lua').new(directory)
      self.ready=true;self.loading=false
      -- Freeze every house together, rather than waiting for each detail page.
      local board=LDBackend:board()
      for _,house in ipairs(board.houses)do assert(self:request(house.id,board.term))end
     end
    end)
    if not worked then self.error=tostring(why);self.loading=false;print('[LD_REQUESTS] '..self.error..'\n')end
   end
   assert(app:defer(1,batch))
  end)
  if not ok then self.error=tostring(err);self.loading=false end
 end
 function self:request(house,term)
  self:ensure()
  if self.error then return nil,L.t('msg.050')end
  if not self.ready then return nil,L.t('msg.051')..(self.total>0 and(math.floor(self.processed*100/self.total)..'%')or'…')end
  assert(type(term)=='number'and term%1==0 and term>=0,'Invalid Landsraad term.')
  local category=assert(tracks[specialization.resolve(house)],'Unknown specialization.')
  self.pools=self.pools or{}
  if not self.pools[category]then self.pools[category]=policy.requestPool(self.items,category)end
  -- Public house requests are installation-wide, independent of character inventory.
  -- Persist before showing; no inventory or payment action is performed here.
  local id,reason=self.store:resolve('local-solo-v1','term:'..term,house,self.pools[category])
  if not id then return nil,L.t('msg.052')..tostring(reason)end
  return self.byId[id]
 end
 function self:categoryItems(house,term)
  if not self.ready then return nil end
  local category=assert(tracks[specialization.resolve(house)])
  local out={}
  local request=self:request(house,term or LDBackend:board().term)
  for _,item in ipairs(self.items)do if policy.accepts(item,category,request and request.id)then out[#out+1]=item end end
  return out
 end
 return self
end
return M
