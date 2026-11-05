-- Our read-only model for the native NBS_PadScan wire format.
-- Preserve entity/database identifiers as decimal strings (no float rounding).
local M={version=1}
local function uint(value,label,max)
 assert(type(value)=='string'and value:match('^%d+$'),label..' is not an unsigned integer.')
 local n=tonumber(value);assert(n and n%1==0 and n>=0 and n<=(max or 2147483647),label..' is outside bounds.')
 return n
end
local function identity(value,label)
 assert(type(value)=='string'and #value<=20 and value:match('^%d+$'),label..' is unavailable.')
 value=value:gsub('^0+','');assert(value~='',label..' is zero.');return value
end
function M.parse(payload,address)
 assert(type(payload)=='string'and #payload<=2*1024*1024,'Inventory response unavailable or too large.')
 local wanted=string.format('%.0f',address)
 local rows,header,occupied,slotsSeen,identities={ },nil,0,{},{}
 local records=0
 for record in payload:gmatch('[^;]+')do
  records=records+1;assert(records<=8192,'Inventory response has too many records.')
  local f={};for part in(record..','):gmatch('(.-),')do f[#f+1]=part end
  assert(f[2]==wanted,'Inventory response belongs to a different inventory.')
  if f[1]=='I'then
   assert(not header,'Duplicate inventory header.')
   header={slots=uint(f[3],'Capacity',4096),used=uint(f[4],'Used slots',4096)}
   assert(header.used<=header.slots,'Used slots exceed capacity.')
  elseif f[1]=='S'then
   assert(header,'Item before inventory header.')
   local slot=uint(f[3],'Slot',4095)
   assert(slot<header.slots and not slotsSeen[slot],'Invalid or duplicate slot.')
   local entity,database=identity(f[4],'Entity id'),identity(f[5],'Database id')
   local key=entity..':'..database;assert(not identities[key],'Duplicate item identity.')
   local count=uint(f[6],'Stack count');assert(count>0,'Empty stack.')
   assert(type(f[9])=='string'and #f[9]<=192 and f[9]:match('^[%w_]+$'),'Item template unavailable.')
   slotsSeen[slot]=true;identities[key]=true;occupied=occupied+1
   rows[#rows+1]={key=key,entity=entity,database=database,slot=slot,template=f[9],count=count}
  elseif f[1]=='U'then error('Inventory contains unresolved items; refresh required.')
  else error('Unknown inventory response record.')end
 end
 assert(header and occupied==header.used,'Inventory snapshot is incomplete.')
 table.sort(rows,function(a,b)return a.slot<b.slot end)
 return {inventory=address,capacity=header.slots,used=header.used,rows=rows,kind='backpack'}
end
function M.eligible(snapshot,catalog)
 local out={}
 for _,entry in ipairs(snapshot.rows)do
  local item=catalog[entry.template]
  if item then
   out[#out+1]={key=entry.key,slot=entry.slot,entity=entry.entity,database=entry.database,
    inventory=snapshot.inventory,count=entry.count,item=item}
  end
 end
 return out
end
-- Selection survives sorting/filtering but never follows an item that moved slots or changed quantity.
function M.reconcile(previous,rows)
 local selected,dropped={},0
 local current={};for _,row in ipairs(rows)do current[row.key]=row end
 for key,choice in pairs(previous or{})do
  local row=current[key]
  if row and choice.inventory==row.inventory and choice.slot==row.slot and choice.template==row.item.id
   and choice.observedCount==row.count and type(choice.quantity)=='number'and choice.quantity%1==0
   and choice.quantity>0 and choice.quantity<=row.count then selected[key]=choice
  else dropped=dropped+1 end
 end
 return selected,dropped
end
return M
