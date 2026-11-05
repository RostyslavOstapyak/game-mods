-- First supported gear payment: one StaticCompactorTier6 on the character, exact fresh snapshot.
local M={}
local DIR=debug.getinfo(1,'S').source:sub(2):gsub('\\','/'):match('^(.*)/[^/]+$')
function M.new(backend,snapshot,rows)
 local probe=dofile(DIR..'/compactor_debit_probe.lua');probe.template='StaticCompactorTier6'
 local offer=probe.preflight(backend,snapshot,rows)
 local created=os.time()
 local payment={template=offer.template,units=1,name='універсальний компактор',kind='compactor',offer=offer}
 function payment.checkDebit()assert(os.time()-created<=5,'Item confirmation expired; refresh the inventory.')end
 function payment.read(pawn)
  assert(pawn:GetAddress()==offer.pawn,'Character changed.')
  return pawn:GetNumberOfItemsInInventory({Name=FName(offer.template,FNAME_Find)})
 end
 function payment.debit(pawn,units,id)
  payment.checkDebit();assert(units==1 and pawn:GetAddress()==offer.pawn,'Invalid item payment.')
  backend.itemPaymentOperationId=id
  local ok,err=pcall(probe.debit,backend,offer,id,snapshot,rows)
  backend.itemPaymentOperationId=nil
  assert(ok,err)
 end
 return payment
end
return M
