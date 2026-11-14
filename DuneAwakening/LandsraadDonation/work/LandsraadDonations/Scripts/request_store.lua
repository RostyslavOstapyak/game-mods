-- Append-only request choices. Never evaluated as Lua; corruption fails closed.
local M={}
local DIR=debug.getinfo(1,'S').source:sub(2):gsub('\\','/'):match('^(.*)/[^/]+$')
local policy=dofile(DIR..'/item_requests.lua')
local function token(s)
 return type(s)=='string'and #s>=1 and #s<=192 and s:match('^[%w_:%-]+$')
end
function M.new(directory)
 local self={path=directory..'/item-requests.tsv',choices={},count=0}
 local f,why,code=io.open(self.path,'rb')
 if f then
  local contents=f:read(1048577);f:close()
  assert(contents and #contents<=1048576 and contents:sub(-1)=='\n','Request manifest incomplete or too large.')
  assert(contents:sub(1,13)=='LDREQUESTS1\r\n'or contents:sub(1,12)=='LDREQUESTS1\n','Unknown request manifest.')
  local first=true
  for line in contents:gmatch('([^\n]+)\n')do
   line=line:gsub('\r$','')
   if first then first=false else
    local scope,iteration,house,item=line:match('^([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)$')
    assert(token(scope)and token(iteration)and token(house)and token(item),'Invalid request record.')
    local key=scope..'\t'..iteration..'\t'..house
    assert(not self.choices[key],'Duplicate request choice; review required.')
    self.count=self.count+1;assert(self.count<=5000,'Request manifest limit reached.')
    self.choices[key]=item
   end
  end
 else
  assert(code==2,why or'Cannot read request manifest.')
  local fresh=assert(io.open(self.path,'wb'));assert(fresh:write('LDREQUESTS1\n'));assert(fresh:flush());assert(fresh:close())
 end
 function self:resolve(scope,iteration,house,pool)
  assert(token(scope)and token(iteration)and token(house),'Stable scope, iteration and house required.')
  assert(type(pool)=='table'and #pool<=20000,'Invalid request pool.')
  local sorted,seen={},{}
  for _,id in ipairs(pool)do assert(token(id)and not seen[id],'Invalid or duplicate item.');seen[id]=true;sorted[#sorted+1]=id end
  table.sort(sorted)
  local key=scope..'\t'..iteration..'\t'..house
  local previous=self.choices[key]
  local chosen,reason=policy.choose(sorted,iteration,house,previous)
  if not chosen then return nil,reason end
  if previous then return chosen end
  assert(self.count<5000,'Request manifest limit reached.')
  local record=key..'\t'..chosen..'\n'
  local file=assert(io.open(self.path,'ab'));local ok,err=file:write(record)
  if ok then ok,err=file:flush()end
  local closed,closeError=file:close();assert(ok and closed,err or closeError or'Cannot persist request.')
  self.choices[key]=chosen;self.count=self.count+1
  return chosen
 end
 return self
end
return M
