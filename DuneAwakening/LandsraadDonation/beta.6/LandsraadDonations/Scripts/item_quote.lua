local M={}
function M.quote(requested,solariPerPoint,solariPerItem,maximum)
 local points=tonumber(requested)
 assert(points and points%1==0 and points>=1 and points<=maximum,'Вкажіть цілу кількість очок від 1 до '..maximum..'.')
 assert(solariPerPoint%1==0 and solariPerPoint>=1 and solariPerPoint<=1000000,'Invalid contribution price.')
 assert(solariPerItem%1==0 and solariPerItem>=1 and solariPerItem<=1000000000,'Invalid item value.')
 local units=math.floor((points*solariPerPoint+solariPerItem-1)/solariPerItem)
 local actual=math.floor(units*solariPerItem/solariPerPoint)
 assert(units>=1 and units<=2147483647,'Кількість меланжу перевищує ліміт гри.')
 assert(actual>=points and actual<=maximum,'Ціла одиниця меланжу за цим курсом перевищує ліміт внеску за операцію.')
 return units,actual
end
return M
