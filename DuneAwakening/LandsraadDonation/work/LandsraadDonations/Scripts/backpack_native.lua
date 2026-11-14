-- Candidate native reader: no Stash session, writes, hooks, or cached UObject wrappers.
-- Read-only integration; payment remains disabled until native behavior is confirmed.
local M={version=1}
local DIR=debug.getinfo(1,'S').source:sub(2):gsub('\\','/'):match('^(.*)/[^/]+$')
local model=dofile(DIR..'/inventory_snapshot.lua')
local bridge=dofile(DIR..'/nbs_reader_client.lua')
function M.available()return type(NBS_PadScan)=='function'or bridge.available()end
function M.scan(app,backend,catalog,callback)
 local token={active=true,polls=0}
 function token:cancel()self.active=false;if self.pending then self.pending:cancel()end end
 local function context()
  local s=backend:context();local inv=s.pawn.m_BackpackInventoryComponent:GetInventory()
  assert(inv and inv:IsValid()and inv:IsInitialContentReceived(),'Backpack is loading.')
  local world=s.controller:GetWorld();assert(world and world:IsValid(),'World unavailable.')
  return {controller=s.controller:GetAddress(),pawn=s.pawn:GetAddress(),world=world:GetAddress(),inventory=inv:GetAddress()}
 end
 local origin,requestId
 local function finish(rows,err,snapshot)
  if not token.active then return end
  token.active=false;callback(rows,err,snapshot)
 end
 local function poll()
  if not token.active then return end
  local ok,result,detail=pcall(function()
   assert(M.available(),'NBS native inventory reader unavailable.')
   local current=context()
   if not origin then origin=current end
   for _,key in ipairs({'controller','pawn','world','inventory'})do assert(origin[key]==current[key],'Inventory context changed.')end
   token.polls=token.polls+1;assert(token.polls<=40,'Native inventory read timed out.')
   local payload,missing,state,why,checksum,checksumBusy
   if type(NBS_PadScan)=='function'then payload,missing,state,why=NBS_PadScan(current.inventory)
   else
    if not requestId then requestId=bridge.request(current)end
    payload,missing,checksum,checksumBusy=bridge.poll(requestId)
    if missing=='pending'then return nil,'pending'end
   end
   assert(state~='off','Native reader refused: '..tostring(why))
   if state=='scanning'then return nil,'pending'end
   assert(missing==0,'Native inventory read is incomplete: '..tostring(missing))
   local snapshot=model.parse(payload,current.inventory)
   snapshot.checksum=checksum;snapshot.checksumBusy=checksumBusy
   print('[LD_CHECKSUM] Snapshot checksum='..tostring(checksum)..' busy='..tostring(checksumBusy)..'\n')
   snapshot.controller=current.controller;snapshot.pawn=current.pawn;snapshot.world=current.world
   return snapshot
  end)
  if not ok then finish(nil,tostring(result));return end
  if detail=='pending'then token.pending=assert(app:defer(250,poll));return end
  finish(model.eligible(result,catalog),nil,result)
 end
 token.pending=assert(app:defer(1,poll));return token
end
return M
