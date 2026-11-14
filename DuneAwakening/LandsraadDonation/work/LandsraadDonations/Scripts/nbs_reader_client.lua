local M={}
local prefix='LandsraadDonations.InventoryBridge.1.'
local sequence=0
function M.available()return ModRef:GetSharedVariable(prefix..'ready')=='1'end
function M.request(context)
 sequence=sequence+1
 local id=tostring(os.time())..'-'..tostring(math.floor(os.clock()*1000)+sequence)
 ModRef:SetSharedVariable(prefix..'request',table.concat({id,tostring(context.controller),tostring(context.pawn),tostring(context.world)},'\t'))
 return id
end
function M.poll(id)
 local response=ModRef:GetSharedVariable(prefix..'response')
 if type(response)~='string'then return nil,'pending'end
 local identity,state,missing,payload=response:match('^([^\n]+)\n([^\n]+)\n([^\n]+)\n(.*)$')
 if identity~=id then return nil,'pending'end
 assert(state=='ok',payload or'Native reader host failed.')
 local sum,busy
 local metadata=ModRef:GetSharedVariable(prefix..'checksum')
 if type(metadata)=='string'then
  local checkId,checkSum,checkBusy=metadata:match('^([^\t]+)\t([^\t]+)\t([^\t]+)$')
  if checkId==id then
   local value=tonumber(checkSum)
   if value and value%1==0 and value>=0 and value<=4294967295 and checkBusy=='0'then sum=value;busy=0 end
  end
 end
 return payload,tonumber(missing),sum,busy
end
return M
