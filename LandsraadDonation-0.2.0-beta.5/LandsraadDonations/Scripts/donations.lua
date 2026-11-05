local M={}
local DIR=debug.getinfo(1,'S').source:sub(2):gsub('\\','/'):match('^(.*)/[^/]+$')
local function valid(o)return o and o:IsValid()end
local function find(path)local o=StaticFindObject(path);assert(valid(o),'Missing game interface: '..path);return o end
local function signature(name,args)
 local path='/Script/DuneSandbox.DuneCheatManager:'..name
 local f=find(path);local actual={}
 f:ForEachProperty(function(p)actual[#actual+1]=p:GetFullName()end)
 assert(#actual==#args,'Changed game interface: '..name)
 for i,v in ipairs(args)do assert(actual[i]==v..' '..path..':'..(i==1 and(name=='AddSolarisToAccount'and'Quantity'or'SlotIndex')or'ProgressIncrease'),'Changed parameter: '..name)end
end
function M.new(app,settings,directory)
 local self={busy=false,message='Select a house and enter a donation.',settings=settings,supportsExactItems=true}
 local guardOK,guard=pcall(function()return dofile(directory..'/Scripts/transaction_guard.lua').new(directory)end)
 if not guardOK then
  self.busy=true
  self.message='Не вдалося прочитати журнал стану пожертв. Пожертви заблоковані до перевірки; меню доступне.'
  print('[LandsraadDonations] Checkpoint error: '..tostring(guard)..'\n')
 elseif guard.pending then
  self.busy=true
  self.message='Незавершена пожертва '..guard.pending..'. Нові пожертви заблоковані до перевірки журналу. Автоматичних списань чи повернень немає.'
 end
 if guardOK and not guard.pending then
  local receiptOK,receipt=pcall(function()return dofile(DIR..'/donation_receipt.lua').latest(directory)end)
  if receiptOK then self.lastReceipt=receipt end
 end
 function self:context()
  app._controller=nil -- Reacquire the current controller; Lua wrappers do not own actor lifetime.
  local s=app:session();assert(s.ok,'Load an on-foot singleplayer character first.')
  assert(s.controller.Role==3 and s.pawn.Role==3,'Local authority required.')
  assert(find('/Script/DuneSandbox.Default__GUIBlueprintLibrary'):IsSoloPlay(s.pawn),'Singleplayer required.')
  return s
 end
 function self:balance(pc)
  local b=pc.m_VirtualWalletBalances[1]
  assert(type(b)=='number'and b>=0 and b%1==0 and b<9007199254740991,'Bank balance unavailable.')
  return b
 end
 function self:board()
  local s=self:context();local g=find('/Script/Engine.Default__GameplayStatics'):GetGameState(s.pawn)
  assert(valid(g)and g:IsA(find('/Script/DuneSandbox.DuneGameState')),'Local world required.')
  local state=g.m_LandsraadStateComponent;assert(valid(state),'Landsraad is unavailable.')
  local current=g.m_LandsraadReplicatedStateComponent.m_LandsraadState
  local houses={}
  state.m_LandsraadTasks:ForEach(function(_,v)
   local t=v:get()
   do
    local id=t.m_HouseName:ToString()
    houses[#houses+1]={id=id,index=t.m_BoardIndex,name=id:gsub('^DA_House','House '),completed=t.m_bCompleted}
   end
  end)
  table.sort(houses,function(a,b)return a.index<b.index end)
  return {session=s,houses=houses,term=current.m_CurrentTermId,period=current.m_CurrentPeriod,competition=find('/Script/DuneSandbox.ELandsraadPeriod'):GetNameByValue(current.m_CurrentPeriod):ToString()=='ELandsraadPeriod::Competition',balance=self:balance(s.controller)}
 end
 function self:quote(amount,kind)
  if kind=='melange'then return dofile(DIR..'/item_quote.lua').quote(amount,settings.solariPerContribution,settings.solariPerMelange,settings.maxContributionPerTransaction)end
  assert(kind==nil or kind=='solari','Unknown donation payment.')
  local points=tonumber(amount)
  assert(points and points%1==0 and points>=1 and points<=settings.maxContributionPerTransaction,'Вкажіть цілу кількість очок від 1 до '..settings.maxContributionPerTransaction..'.')
  return points*settings.solariPerContribution,points
 end
 function self:journal(r)
  local file=assert(io.open(directory..'/transactions.log','a'),'Cannot write donation journal.')
  local ok,err=file:write(os.date('!%Y-%m-%dT%H:%M:%SZ')..' '..r..'\n')
  if ok then ok,err=file:flush()end
  local closed,closeError=file:close();assert(ok and closed,err or closeError or'Cannot persist donation journal.')
  print('[LandsraadDonations] '..r..'\n')
 end
 function self:melangeBalance(pawn)return dofile(DIR..'/melange_payment.lua').read(pawn or self:context().pawn)end
 function self:donateCompactor(house,term,snapshot,rows,key)
  assert(not self.busy,'Wait for the previous donation.')
  local catalog=assert(LDItemRequests,'Item catalog unavailable.')
  local request=assert(catalog:request(house,term),'House request unavailable.')
  local allowed=false
  for _,item in ipairs(assert(catalog:categoryItems(house)))do if item.id=='StaticCompactorTier6'then allowed=true end end
  assert(allowed,'This house does not accept compactors.')
  local selected
  for _,row in ipairs(rows)do if row.key==key then selected=row end end
  assert(selected and selected.item.id=='StaticCompactorTier6'and selected.count==1,'Select one supported compactor.')
  local value=assert(dofile(DIR..'/base_item_value.lua').points(selected.item,settings,request.id==selected.item.id and 2 or 1))
  local points=math.floor(value)
  assert(points>=1 and points<=settings.maxContributionPerTransaction,'Item contribution is outside the limit.')
  local payment=dofile(DIR..'/compactor_payment.lua').new(self,snapshot,rows)
  return self:donate(house,points,term,'compactor',payment)
 end
 function self:donateItems(house,term,snapshot,rows,selection)
  assert(not self.busy,'Wait for the previous donation.')
  local catalog=assert(LDItemRequests,'Item catalog unavailable.')
  local request=assert(catalog:request(house,term),'House request unavailable.')
  local allowed={};for _,item in ipairs(assert(catalog:categoryItems(house)))do allowed[item.id]=item end
  local total=0
  for _,row in ipairs(rows)do if selection[row.key]then
   local item=assert(allowed[row.item.id],'Дім не приймає цей предмет.')
   total=total+assert(dofile(DIR..'/base_item_value.lua').points(item,settings,request.id==item.id and 2 or 1))*selection[row.key]
  end end
  local points=math.floor(total)
  assert(points>=1 and points<=settings.maxContributionPerTransaction,'Внесок має бути від 1 до 6 000 очок.')
  local payment=dofile(DIR..'/gear_payment.lua').new(self,snapshot,rows,selection)
  return self:donate(house,points,term,'items',payment)
 end
 function self:donate(house,amount,term,kind,compactorPayment)
  assert(not self.busy,'Wait for the previous donation.')
  kind=kind or'solari'
  local cost,points=self:quote(amount,(kind=='compactor'or kind=='items')and'solari'or kind)
  if kind=='compactor'then cost=1;assert(compactorPayment and compactorPayment.template=='StaticCompactorTier6'and compactorPayment.units==1,'Invalid compactor payment.')end
  if kind=='items'then assert(compactorPayment and compactorPayment.template=='gear_batch','Invalid gear payment.');cost=compactorPayment.units end
  local b=self:board()
  assert(b.term==term,'Landsraad cycle changed. Refresh the house list.')
  assert(b.competition,'Donations are available during the Landsraad competition.')
  local selected
  for _,h in ipairs(b.houses)do if h.id==house then selected=h;break end end
  assert(selected,'This house is unavailable in the current term.')
  local itemPayment,itemBefore
  if kind=='melange'then
   itemPayment=dofile(DIR..'/melange_payment.lua');itemPayment.checkDebit()
   itemBefore=itemPayment.read(b.session.pawn);assert(itemBefore>=cost,'Недостатньо меланжу в рюкзаку.')
  elseif kind=='compactor'or kind=='items'then
   itemPayment=compactorPayment;itemPayment.checkDebit()
   itemBefore=itemPayment.read(b.session.pawn);assert(itemBefore==(kind=='items'and(itemPayment.beforeUnits or cost)or cost),'Item count changed.')
  else assert(b.balance>=cost,'Not enough Solari in the bank.')end
  local observer=assert(LDPersonalProgress,'Personal contribution reader unavailable.')
  local values=observer:snapshot(b.session.controller,b.term)
  assert(values and observer.fullReceivedAt and os.time()-observer.fullReceivedAt<=3,'Особистий внесок оновлюється. Зачекайте кілька секунд і повторіть підтвердження.')
  local before=values[selected.index]or 0
  assert(type(before)=='number'and before>=0 and before%1==0,'Personal contribution is invalid.')
  local beforeVersion=observer.fullVersion or 0
  signature('AddSolarisToAccount',{'Int64Property'})
  signature('DebugLandsraadInsertTaskProgress',{'IntProperty','IntProperty'})
  local xp,xpTrack,xpBefore,xpAmount,xpLevel
  if settings.specializationXpEnabled then
   xp=dofile(directory..'/Scripts/specialization_xp.lua')
   xpTrack=xp.resolve(house)
   xpBefore,xpLevel=xp.read(b.session.controller,xpTrack)
   xpAmount=dofile(directory..'/Scripts/xp_policy.lua').quote(points,settings.specializationXpPerPoint)
   if xpLevel>=100 then xpAmount=0 end
   assert(xpBefore+xpAmount<=2147483647,'Specialization XP exceeds the game limit.')
   if xpAmount>0 then xp.checkGrant()end
  end
  local owner=b.session.controller:GetAddress()
  local ownerPawn=itemPayment and b.session.pawn:GetAddress()or nil
  local function currentManager()
   local s=self:context();assert(s.controller:GetAddress()==owner,'Player changed during payment.')
   if ownerPawn then assert(s.pawn:GetAddress()==ownerPawn,'Character changed during item payment.')end
   local m=s.controller.CheatManager
   if not valid(m)then m=StaticConstructObject(find('/Script/DuneSandbox.DuneCheatManager'),s.controller,0,64)end
   assert(valid(m),'Game progression interface unavailable.')
   return m,s.controller,s.pawn
  end
  local m,_,payPawn=currentManager()
  local expectedBank=b.balance-(kind=='solari'and cost or 0)
  local function paid(pc,pawn)
   assert(self:balance(pc)==expectedBank,'Payment balance could not be verified.')
   if itemPayment then assert(itemPayment.read(pawn)==itemBefore-cost,'Melange removal could not be verified.')end
  end
  local id=tostring(os.time())..'-'..tostring(math.floor(os.clock()*1000))
  self:journal(id..' prepared house='..house..' term='..term..' cost='..cost..' points='..points..' balance='..b.balance..' personal_before='..before..' rate='..settings.solariPerContribution)
  if itemPayment then self:journal(id..' payment='..kind..' template='..itemPayment.template..' item_before='..itemBefore..' units='..cost..(kind=='melange'and(' solari_per_item='..settings.solariPerMelange)or(' entity='..itemPayment.offer.entity..' database='..itemPayment.offer.database..' slot='..itemPayment.offer.slot)))end
  if kind=='items'then for _,row in ipairs(itemPayment.identities)do
   self:journal(id..' selected_item template='..row.template..' entity='..row.entity..' database='..row.database..' slot='..row.slot..' units='..row.count)
  end end
  if xp then self:journal(id..' xp_planned track='..xpTrack..' before='..xpBefore..' amount='..xpAmount..' rate='..settings.specializationXpPerPoint..' level='..xpLevel)end
  self.busy=true;self.message='Processing donation...'
  self.currentPayment={id=id,house=house,kind=kind,units=cost,points=points,stage='debit',keys={},quantities={}}
  if kind=='items'then for _,row in ipairs(itemPayment.identities)do
   local key=row.entity..':'..row.database
   self.currentPayment.keys[key]=true;self.currentPayment.quantities[key]=row.count
  end end
  local checkpointOK,checkpointError=pcall(function()guard:write(id,'begin')end)
  if not checkpointOK then self.message='Не вдалося зберегти стан пожертви. Списання не виконано; потрібна перевірка журналу.';error(checkpointError)end
  local function review(err)
   if self.currentPayment then self.currentPayment.stage='review'end
   self.message='Результат пожертви потребує перевірки. Повторні пожертви заблоковані, зокрема після перезапуску.'
   pcall(function()self:journal(id..' review_required '..tostring(err))end)
  end
  local function later(delay,callback)
   local ok,result=pcall(function()return app:defer(delay,function()
    local ran,err=pcall(callback);if not ran then review(err)end
   end)end)
   if not ok or not result then review(ok and'Donation callback unavailable'or result)end
  end
  local ok,err=pcall(function()
   if itemPayment then itemPayment.debit(payPawn,cost,id)else m:AddSolarisToAccount(-cost)end
  end)
  if not ok then review(err);return end
  local function afterPayment()
    local manager,pc,pawn=currentManager()
    paid(pc,pawn)
    self.currentPayment.debited=true;self.currentPayment.stage='contribution'
    local current=self:board();local available=false
    for _,h in ipairs(current.houses)do if h.id==house and h.completed==selected.completed then available=true end end
    if current.term~=term or not current.competition or not available then
     assert(not itemPayment,'House or cycle changed after Melange payment; manual review required, no automatic item refund.')
     self:journal(id..' refund_requested house_or_cycle_changed');manager:AddSolarisToAccount(cost)
     self.message='House or cycle changed. Checking refund.'
     later(700,function()
      local _,currentPc=currentManager();assert(self:balance(currentPc)==b.balance,'Refund could not be verified.')
      self:journal(id..' refunded');guard:write(id,'refunded')
      self.message='Donation cancelled and Solari refunded.';self.busy=false
     end);return
    end
    self:journal(id..' paid; submitting_contribution')
    -- Require a later full snapshot; a cached value or delta is not a receipt.
    beforeVersion=observer.fullVersion or beforeVersion
    manager:DebugLandsraadInsertTaskProgress(selected.index,points)
    self:journal(id..' submitted')
    local paidLabel=itemPayment and'Предмети списано.'or'Соляріс списано.'
    self.message=paidLabel..' Очікуємо підтвердження внеску…'
    local waitingSince=os.time()
    local attempts=0
    local function confirm()
     attempts=attempts+1
     local fresh=self:board();assert(fresh.session.controller:GetAddress()==owner and fresh.term==term,'Player or Landsraad cycle changed before receipt.')
     local progress=observer:snapshot(fresh.session.controller,term)
     if progress and(observer.fullVersion or 0)>beforeVersion then
      local actual=progress[selected.index]or 0
      if actual==before+points then
       paid(fresh.session.controller,fresh.session.pawn)
       self:journal(id..' confirmed personal_after='..actual..' balance='..fresh.balance)
       local function complete()
        guard:write(id,'complete');self.busy=false;self.currentPayment.stage='complete'
        self.lastReceipt={id=id,house=house,kind=kind,units=cost,points=points,xp=xpAmount or 0,
         personalBefore=before,personalAfter=actual,bankBefore=b.balance,bankAfter=expectedBank,completedAt=os.time()}
        self.message=string.format('Пожертву підтверджено: %d %s → %d очок внеску.',cost,kind=='melange'and'меланжу'or kind=='compactor'and'компактор'or kind=='items'and'предметів'or'соляріс',points)
        if xp and xpAmount>0 then self.message=self.message..string.format(' Досвід спеціалізації: +%d.',xpAmount)end
       end
       if xp and xpAmount>0 then
        self.currentPayment.stage='xp'
        local manager,pc=currentManager()
        assert(xp.read(pc,xpTrack)==xpBefore,'Specialization XP changed before reward; review required.')
        self:journal(id..' xp_requested track='..xpTrack..' amount='..xpAmount)
        manager:AddXPToSpecializationTrack(xpTrack,xpAmount)
        self.message='Внесок підтверджено. Перевіряємо досвід спеціалізації…'
        local xpAttempts=0
        local function confirmXP()
         xpAttempts=xpAttempts+1
         local _,currentPc=currentManager();local after=xp.read(currentPc,xpTrack)
         if after==xpBefore+xpAmount then
          self:journal(id..' xp_confirmed track='..xpTrack..' after='..after);complete();return
         end
         assert(after<=xpBefore+xpAmount and xpAttempts<12,'Specialization XP receipt differs or timed out; no retry sent.')
         later(500,confirmXP)
        end
        later(500,confirmXP)
       else complete()end
       return
      end
      assert(actual<=before+points,'Contribution differs from the expected receipt.')
     end
     -- A local board response can arrive after the first 12 seconds.
     -- Keep payment locked while waiting; never resend the progression action.
     assert(attempts<120,'Timed out waiting for contribution confirmation; do not repeat payment.')
     if attempts%10==0 then self.message=paidLabel..' Очікуємо внесок ('..(os.time()-waitingSince)..' с). Повторно підтверджувати не потрібно.'end
     later(500,confirm)
    end
    later(500,confirm)
  end
  if itemPayment and itemPayment.awaitReceipt then
   local delivered=false
   local waiting,why=pcall(itemPayment.awaitReceipt,app,function(confirmed,reason)
    if delivered then return end;delivered=true
    if confirmed then later(1,afterPayment)else review(reason or'Exact item receipt unavailable.')end
   end)
   if not waiting then review(why)end
  else later(700,afterPayment)end
 end
 return self
end
return M

