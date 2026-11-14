-- Approved policy: game base value times one configurable multiplier. No resale percentage.
local M={}
function M.unit(item,settings)
 if item.id=='MelangeSpice'then return settings.solariPerMelange end
 local base=item.baseValue
 if type(base)~='number'or base~=base or base<=0 or base==math.huge then return nil end
 local multiplier=settings.itemValueMultiplier or 1
 assert(type(multiplier)=='number'and multiplier==multiplier and multiplier>=.001 and multiplier<=1000000,'Invalid item value multiplier.')
 return base*multiplier
end
function M.points(item,settings,bonus)
 local unit=M.unit(item,settings);if not unit then return nil end
 assert(bonus==1 or bonus==2,'Invalid house request bonus.')
 return unit/settings.solariPerContribution*(item.id=='MelangeSpice'and 1 or bonus)
end
return M
