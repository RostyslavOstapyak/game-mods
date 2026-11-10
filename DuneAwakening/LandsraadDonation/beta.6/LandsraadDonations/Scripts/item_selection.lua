-- UI-independent batch selection. Quotes are informational; this module cannot spend items.
local M={}
function M.new()
 local self={selected={}}
 function self:set(row,quantity)
  assert(type(quantity)=='number'and quantity%1==0 and quantity>=0 and quantity<=row.count,'Invalid selected quantity.')
  if quantity==0 then self.selected[row.key]=nil;return end
  self.selected[row.key]={inventory=row.inventory,slot=row.slot,template=row.item.id,observedCount=row.count,quantity=quantity}
 end
 function self:toggle(row)
  self:set(row,self.selected[row.key]and 0 or row.count)
 end
 function self:selectAll(rows)
  for _,row in ipairs(rows)do self:set(row,row.count)end
 end
 function self:clear()self.selected={}end
 function self:summary(rows,unitValue,limit)
  local current={};for _,row in ipairs(rows)do current[row.key]=row end
  local result={lines=0,units=0,points=0,unpriced=0,changed=0}
  for key,choice in pairs(self.selected)do
   local row=current[key]
   if not row or row.slot~=choice.slot or row.inventory~=choice.inventory or row.item.id~=choice.template
    or row.count~=choice.observedCount then result.changed=result.changed+1
   else
    result.lines=result.lines+1;result.units=result.units+choice.quantity
    local price=unitValue(row)
    if type(price)~='number'or price~=price or price<0 or price==math.huge then result.unpriced=result.unpriced+1
    else result.points=result.points+price*choice.quantity end
   end
  end
  -- Round once for the whole batch, never for each low-value item.
  result.points=math.floor(result.points)
  result.overLimit=result.points>(limit or 6000)
  result.quoteReady=result.lines>0 and result.unpriced==0 and result.changed==0 and not result.overLimit and result.points>0
  return result
 end
 return self
end
return M
