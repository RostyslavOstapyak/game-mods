-- Data-only localization packs. No game language setters and no executable translation files.
if LDLocalization then return LDLocalization end
local M={tag=nil,code='en'}
local DIR=debug.getinfo(1,'S').source:sub(2):gsub('\\','/'):match('^(.*)/[^/]+$')..'/../Locales/'
local function decode(s)
 return(s:gsub('\\(.)',function(c)return({n='\n',r='\r',t='\t',['\\']='\\'})[c]or error('Unknown translation escape')end))
end
local function load(code)
 local f=io.open(DIR..code..'.tsv','rb');if not f then return nil end
 local bytes=f:read(262145);f:close();if #bytes>262144 then return nil end
 local ok,pack=pcall(function()
  assert(utf8.len(bytes));local out,count={},0
  for line in (bytes:gsub('^\239\187\191','')..'\n'):gmatch('([^\n]*)\n')do
   line=line:gsub('\r$','')
   if line~=''and line:sub(1,1)~='#'then
    local key,value=line:match('^([%w_.%-]+)\t(.*)$');assert(key and not out[key],'Invalid/duplicate translation key')
    out[key]=decode(value);count=count+1;assert(count<=4096)
   end
  end
  return out
 end)
 if not ok then print('[LandsraadDonations] Invalid language pack '..code..'; using English fallback\n');return nil end
 return pack
end
local source=load('source')or{}
local english=load('en')or{}
local active=english
function M.t(key,values)
 local text=active[key]or english[key]or source[key]or('['..key..']')
 if values then text=text:gsub('{([%w_]+)}',function(k)return values[k]~=nil and tostring(values[k])or('{'..k..'}')end)end
 return text
end
local function normalize(tag)
 if type(tag)~='string'then return'en'end
 tag=tag:lower():gsub('_','-')
 if #tag>35 or not tag:match('^[a-z][a-z0-9%-]*$')then return'en'end
 return tag
end
function M.refresh(reader)
 local ok,tag=pcall(function()
  if reader then return reader()end
  local library=StaticFindObject('/Script/Engine.Default__KismetInternationalizationLibrary')
  assert(library and library:IsValid())
  local value=library:GetCurrentLanguage()
  return type(value)=='string'and value or value:ToString()
 end)
 tag=normalize(ok and tag or(M.tag or'en'))
 if tag==M.tag then return false end
 local base=tag:match('^([a-z]+)')
 local pack
 if tag=='en'then pack=english else pack=load(tag)end
 local code=pack and tag or'en'
 if not pack and base~=tag then pack=load(base);if pack then code=base end end
 active=pack or english;M.tag=tag;M.code=code
 print('[LandsraadDonations] Language '..tag..' -> '..code..'\n')
 return true
end
-- Translate backend status/error text at the presentation boundary only.
-- Never changes journal data, numeric values, item IDs or native action arguments.
local fragments,templates={},{}
local function pattern(value)
 local parts,kinds={},{};local i=1
 while i<=#value do
  local pair=value:sub(i,i+1)
  if pair=='%d'or pair=='%s'then
   parts[#parts+1]=pair=='%d'and'(%d+)'or'(.-)';kinds[#kinds+1]=pair;i=i+2
  else parts[#parts+1]=value:sub(i,i):gsub('([%^%$%(%)%%%.%[%]%*%+%-%?])','%%%1');i=i+1 end
 end
 return table.concat(parts),kinds
end
for key,value in pairs(source)do
 if key:sub(1,4)=='msg.'or #value>=18 then
  if value:find('%%[ds]')then
   local p,k=pattern(value);templates[#templates+1]={key=key,pattern=p,kinds=k}
  elseif #value>=4 then fragments[#fragments+1]={key=key,value=value}end
 end
end
table.sort(templates,function(a,b)return #source[a.key]>#source[b.key]end)
table.sort(fragments,function(a,b)return #a.value>#b.value end)
local function plain(text)
 local out,at={},1
 while at<=#text do
  local first,last,rule
  for _,r in ipairs(fragments)do
   local a,b=text:find(r.value,at,true)
   if a and(not first or a<first or a==first and b>last)then first,last,rule=a,b,r end
  end
  if not first then out[#out+1]=text:sub(at);break end
  out[#out+1]=text:sub(at,first-1);out[#out+1]=M.t(rule.key);at=last+1
 end
 return table.concat(out)
end
function M.message(value)
 local text=tostring(value)
 for _,r in ipairs(templates)do
  text=text:gsub(r.pattern,function(...)
   local args={...}
   for i,kind in ipairs(r.kinds)do args[i]=kind=='%d'and tonumber(args[i])or plain(args[i])end
   local ok,translated=pcall(string.format,M.t(r.key),table.unpack(args))
   return ok and translated or string.format(source[r.key],table.unpack(args))
  end)
 end
 return plain(text)
end
LDLocalization=M
return M
