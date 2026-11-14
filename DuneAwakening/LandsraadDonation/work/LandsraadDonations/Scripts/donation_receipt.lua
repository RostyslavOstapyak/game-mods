-- Read-only display recovery. Never replays a payment or evaluates journal contents.
local M={}
local function tail(path)
 local file=io.open(path,'rb');if not file then return ''end
 local size=file:seek('end');file:seek('set',math.max(0,size-65536))
 local text=file:read('*a')or'';file:close();return text:gsub('\r','')
end
local function number(value)
 local n=tonumber(value);if n and n>=0 and n<=9007199254740991 and n%1==0 then return n end
end
function M.latest(directory)
 local checkpoint=tail(directory..'/transaction-state.log')
 local id,phase=checkpoint:match('([%d%-]+) ([%a_]+)\n$')
 if not id or phase~='complete'then return nil end
 local result={id=id,kind='solari',xp=0};local confirmed,xpConfirmed=false,false
 for line in tail(directory..'/transactions.log'):gmatch('[^\n]+')do
  local record,body=line:match('^%S+ ([%d%-]+) (.+)$')
  if record==id then
   local values={};for key,value in body:gmatch('([%w_]+)=([^%s]+)')do values[key]=value end
   if body:match('^prepared ')then
    result.house=values.house;result.units=number(values.cost);result.points=number(values.points)
    result.personalBefore=number(values.personal_before);result.bankBefore=number(values.balance)
   elseif body:match('^payment=')then result.kind=values.payment
   elseif body:match('^xp_planned ')then result.xp=number(values.amount)
   elseif body:match('^confirmed ')then
    confirmed=true;result.personalAfter=number(values.personal_after);result.bankAfter=number(values.balance)
   elseif body:match('^xp_confirmed ')then xpConfirmed=true end
  end
 end
 if not(confirmed and result.house and result.units and result.points and result.personalBefore and result.personalAfter
  and result.bankBefore and result.bankAfter and result.xp and(result.xp==0 or xpConfirmed))then return nil end
 if result.personalAfter~=result.personalBefore+result.points then return nil end
 return result
end
return M
