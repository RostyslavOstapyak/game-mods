-- Read once per backend creation. A pending payment always keeps its quoted rate.
local directory=debug.getinfo(1,'S').source:sub(2):gsub('\\','/'):match('^(.*)/[^/]+$')
local price=1000
local xpPerPoint=1
local xpEnabled=true
local melangeValue=60000
local itemValueMultiplier=1
local file=io.open(directory..'/config.ini','r')
if file then
 local contents=file:read('*a');file:close()
 local section
 local seen={}
 for rawLine in (contents..'\n'):gmatch('([^\n]*)\n')do
  local line=rawLine:gsub('^\239\187\191','')
  local header=line:match('^%s*%[([^%]]+)%]%s*$')
  if header then section=header end
  local key,value=line:match('^%s*([%w_]+)%s*=%s*(.-)%s*$')
  if section=='donations'and key=='solari_per_point'then
   local n=tonumber(value)
   assert(not seen[key],'Duplicate solari_per_point in config.ini; donations disabled until corrected.')
   assert(n and n==n and n%1==0 and n>=1 and n<=1000000,'config.ini: solari_per_point must be a whole number from 1 to 1000000.')
   seen[key]=true;price=n
  elseif section=='donations'and key=='item_value_multiplier'then
   local n=tonumber(value)
   assert(not seen[key],'Duplicate item_value_multiplier in config.ini.')
   assert(n and n==n and n>=.001 and n<=1000000,'config.ini: item_value_multiplier must be from 0.001 to 1000000.')
   seen[key]=true;itemValueMultiplier=n
  elseif section=='donations'and key=='solari_per_melange'then
   local n=tonumber(value)
   assert(not seen[key],'Duplicate solari_per_melange in config.ini.')
   assert(n and n%1==0 and n>=1 and n<=1000000000,'config.ini: solari_per_melange must be a whole number from 1 to 1000000000.')
   seen[key]=true;melangeValue=n
  elseif section=='donations'and key=='specialization_xp_enabled'then
   assert(not seen[key],'Duplicate specialization_xp_enabled in config.ini.')
   local flag=value:lower()
   assert(flag=='true'or flag=='false','config.ini: specialization_xp_enabled must be true or false.')
   seen[key]=true;xpEnabled=flag=='true'
  elseif section=='donations'and key=='specialization_xp_per_point'then
   local n=tonumber(value)
   assert(not seen[key],'Duplicate specialization_xp_per_point in config.ini.')
   assert(n and n==n and n>=0 and n<=1000,'config.ini: specialization_xp_per_point must be a number from 0 to 1000.')
   seen[key]=true;xpPerPoint=n
  end
 end
end
return {
 solariPerContribution=price,
 solariPerMelange=melangeValue,
 itemValueMultiplier=itemValueMultiplier,
 specializationXpPerPoint=xpPerPoint,
 specializationXpEnabled=xpEnabled,
 minSolariDonation=price,
 maxSolariDonation=price*6000,
 maxContributionPerTransaction=6000,
}
