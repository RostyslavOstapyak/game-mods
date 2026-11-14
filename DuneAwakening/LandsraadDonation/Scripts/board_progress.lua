-- Confirmed reflected schema: LandsraadTaskProgress contains a nested faction array.
-- Copy numbers/strings only; never retain response structs or UObject wrappers.
local M={}
function M.read(rows)
 local result={};local count=0
 rows:ForEach(function(_,value)
  count=count+1;assert(count<=25,'Unexpected Landsraad board size.')
  local row=value:get();local index=row.m_BoardIndex
  assert(type(index)=='number'and index%1==0 and index>=0 and index<25 and not result[index],'Invalid Landsraad board index.')
  local amounts={Atreides=0,Harkonnen=0};local seen={};local factionCount=0
  row.m_TaskProgressPerFaction:ForEach(function(_,entry)
   factionCount=factionCount+1;assert(factionCount<=16,'Unexpected Landsraad faction count.')
   local faction=entry:get();local name=faction.m_Faction.Name:ToString();local amount=faction.m_ProgressAmount
   assert(not seen[name],'Duplicate Landsraad faction progress.');seen[name]=true
   assert(type(amount)=='number'and amount==amount and amount%1==0 and amount>=0 and amount<=2147483647,'Invalid faction contribution.')
   amounts[name]=amount
  end)
  result[index]=amounts
 end)
 assert(count>0,'Empty Landsraad board progress response.')
 return result
end
return M
