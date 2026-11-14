-- Append-only local checkpoint, never executed as Lua. Uncertain operations fail closed.
local M={}
function M.new(directory)
 local self={path=directory..'/transaction-state.log',pending=nil}
 local file,readError,readCode=io.open(self.path,'r')
 if file then
  local contents=file:read('*a');file:close()
  local pending
  for line in contents:gmatch('([^\n]*)\n')do
   local id,phase=line:match('^([%d%-]+) ([%a_]+)\r?$')
   assert(id and(phase=='begin'or phase=='complete'or phase=='refunded'),'Invalid transaction checkpoint; manual review required.')
   if phase=='begin'then
    assert(not pending,'Multiple unfinished donations; manual review required.');pending=id
   else
    assert(pending==id,'Transaction checkpoint mismatch; manual review required.');pending=nil
   end
  end
  assert(contents==''or contents:sub(-1)=='\n','Incomplete transaction checkpoint; manual review required.')
  self.pending=pending
 else
  -- Distinguish a missing ledger from one which cannot be opened for reading.
  assert(readCode==2,readError or'Cannot read donation checkpoint.')
  local writable,why=io.open(self.path,'a');assert(writable,why);assert(writable:close())
 end
 function self:write(id,phase)
  assert(type(id)=='string'and id:match('^[%d%-]+$'),'Invalid transaction identifier.')
  if phase=='begin'then assert(not self.pending,'Previous donation needs review.')
  else assert((phase=='complete'or phase=='refunded')and self.pending==id,'Donation checkpoint mismatch.')end
  local f=assert(io.open(self.path,'a'),'Cannot persist donation checkpoint.')
  local ok,err=f:write(id..' '..phase..'\n')
  if ok then ok,err=f:flush()end
  local closed,closeError=f:close()
  assert(ok and closed,err or closeError or'Cannot persist donation checkpoint.')
  self.pending=phase=='begin'and id or nil
 end
 return self
end
return M
