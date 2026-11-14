-- Our item-page layout. Preview selection is intentionally separate from native payment identity.
local M={}
local DIR=debug.getinfo(1,'S').source:sub(2):gsub('\\','/'):match('^(.*)/[^/]+$')
local L=dofile(DIR..'/localization.lua')
local display=dofile(DIR..'/display_numbers.lua')
local values=dofile(DIR..'/base_item_value.lua')
local searchPolicy=dofile(DIR..'/item_search.lua')
local xpPolicy=dofile(DIR..'/xp_policy.lua')
local quantityStyle=dofile(DIR..'/quantity_style.lua')
local function color(r,g,b)return{r=r,G=g,B=b,A=1}end
local BLUE=color(.451,.665,.784)
local TEXT=color(.855,.791,.658)
local DIM=color(.227,.292,.361)
local function stringOf(v)return type(v)=='string'and v or v:ToString()end
function M.build(ui,app,backend,requests,id,cached)
 ui:refreshData()
 local house;for _,h in ipairs(ui.houses)do if h.id==id then house=h end end
 assert(house and ui.available[id],L.t('ui.056'))
 ui:clearContent();ui.screen='items';ui.selected=house
 local view={rows={},checks={},inputs={},selection={},marks={},rowArt={},query='',preview=true}
 ui.itemsView=view
 ui.skin=dofile(DIR..'/design_skin.lua').new(ui)
 ui.skin:image(ui.content,'study-backdrop.png',0,0,1120,806)
 ui:header()
 ui:button(ui.content,L.t('ui.057'),24,69,180,34,function()ui:details(id)end,false,13)
 ui:segment(ui.content,48,80,41,86,BLUE);ui:segment(ui.content,41,86,48,92,BLUE);ui:segment(ui.content,41,86,57,86,BLUE)
 ui:button(ui.content,L.t('ui.058'),745,17,160,36,function()ui:itemsPage(id,1)end,false,13)
 ui:button(ui.content,L.t('ui.012'),925,17,170,36,function()ui:close()end,false,13)
 ui:label(ui.content,L.t('ui.059')..house.name..L.t('ui.060'),24,120,1065,40,27,TEXT)
 local request,why=requests:request(id,ui.board.term)
 local requestLabel=ui:label(ui.content,request and(L.t('ui.061')..request.name..L.t('ui.062'))or why,24,168,1065,29,15,BLUE)
 ui:surface(24,211,770,516);ui:surface(816,211,279,516)
 ui:label(ui.content,L.t('ui.063'),838,234,235,25,13,DIM)
 ui:label(ui.content,L.t('ui.064'),838,273,235,40,27,TEXT)
 local warning=ui:label(ui.content,'',24,746,770,48,13,DIM)
 ui.notice=ui:label(ui.content,'',816,738,279,65,12,TEXT)
 local summary=ui:label(ui.content,'',838,337,235,86,16,TEXT)
 local quote=ui:label(ui.content,'',838,449,235,116,21,BLUE)
 ui:label(ui.content,L.t('ui.065'),838,575,235,73,13,DIM)
 local proceed=ui:button(ui.content,L.t('ui.066'),838,662,235,45,function()if view.submit then view:submit()end end,false,15,true)
 proceed:SetIsEnabled(false);proceed:SetRenderOpacity(.45)
 if not request then
  ui:help()
  ui.notice:SetText(FText(why or L.t('ui.067')))
  if not requests.ready and not requests.error then
   function view:tick()
    if requests.error then
     ui.notice:SetText(FText(L.t('ui.068')));self.tick=nil
    elseif requests.ready and ui.itemsView==self then
     self.tick=nil;ui:itemsPage(id,1)
    elseif ui.itemsView==self then
     local percent=requests.total>0 and math.floor(requests.processed*100/requests.total)or 0
     if self.catalogPercent~=percent then
      self.catalogPercent=percent
      ui.notice:SetText(FText(L.t('ui.069')..percent..L.t('ui.070')))
     end
    end
   end
  end
  return
 end
 if not cached then
  ui:help()
  ui.notice:SetText(FText(L.t('ui.071')))
  ui.itemScan=dofile(DIR..'/item_inventory.lua').scan(app,backend,assert(requests:categoryItems(id)),function(rows,err)
   if not ui.handle or ui.itemsView~=view then return end
   if not rows then ui.notice:SetText(FText(L.t('ui.072')..tostring(err)));return end
   ui:itemsPage(id,1,rows)
  end)
  return
 end
 local exact=cached.mode=='instances'
 for _,entry in ipairs(cached)do entry.key=entry.key or('type:'..entry.item.id)end
 local equipmentWarning=exact and L.t('ui.073')or L.t('ui.074')
 local exactSelection=exact and backend.supportsExactItems and cached.snapshot and cached.snapshot.checksum and cached.snapshot.checksumBusy==0
 equipmentWarning=exactSelection and L.t('ui.075')or exact and L.t('ui.076')or L.t('ui.077')
 warning:SetText(FText(L.t('ui.078')))
 local priceError=nil
 local levelKnown,level=false,nil
 if backend.settings.specializationXpEnabled then levelKnown,level=pcall(function()return ui:specializationLevel(id)end)end
 table.sort(cached,function(a,b)
  if(a.item.id==request.id)~=(b.item.id==request.id)then return a.item.id==request.id end
  return a.item.name<b.item.name
 end)
 view.rows=cached
 local hasStacks=false
 for _,entry in ipairs(cached)do if entry.count>1 then hasStacks=true;break end end
 local nameWidth=hasStacks and 345 or 395
 function view:update()
  self.changeVersion=(self.changeVersion or 0)+1
  self.pending=nil;self.candidate=nil
  local types,units,total,unknown,invalid,hidden=0,0,0,false,false,0
  for _,entry in ipairs(self.rows)do
   if self.selection[entry.key]then
    types=types+1
    if not searchPolicy.matches(entry.item.name,entry.item.id,self.query)then hidden=hidden+1 end
    local count=tonumber(stringOf(self.inputs[entry.key]:GetText()))
    if not count or count%1~=0 or count<1 or count>entry.count then invalid=true
    else
     units=units+count
     local price=values.points(entry.item,backend.settings,entry.item.id==request.id and 2 or 1)
     if not price then unknown=true else total=total+price*count end
    end
   end
   local check=self.checks[entry.key]
   if check then check:GetChildAt(0):SetText(FText(''))end
   local on=self.selection[entry.key]==true
   if self.marks[entry.key]then self.marks[entry.key]:SetVisibility(on and 3 or 1)end
   local art=self.rowArt[entry.key]
   if art and art.selected~=on then
    art.selected=on
    local name=art.special and(on and'items-row-special-selected.png'or'items-row-special.png')or(on and'items-row-selected.png'or'items-row.png')
    art.widget:SetBrushFromTexture(ui.skin:texture(name),false)
   end
  end
  total=math.floor(total)
  self.candidateSelection=nil
  if exact and types>0 and not invalid and not unknown and total>=1 and total<=6000 then
   local selected={}
   for _,entry in ipairs(self.rows)do if self.selection[entry.key]then selected[entry.key]=tonumber(stringOf(self.inputs[entry.key]:GetText()))end end
   local ok,why=pcall(function()dofile(DIR..'/gear_payment.lua').plan(self.rows,selected,exactSelection and cached.snapshot or nil)end)
   if ok then self.candidateSelection=selected;self.candidate=true
   else ui.notice:SetText(FText(display.error(why)))end
  end
  self.expectedPoints=total
  local enabled=self.candidate~=nil and not backend.busy and not self.submitting
  proceed:SetIsEnabled(enabled);proceed:SetRenderOpacity(enabled and 1 or .45)
  proceed:GetChildAt(0):SetText(FText(enabled and L.t('ui.038')or backend.busy and L.t('ui.079')or L.t('ui.066')))
  summary:SetText(FText(L.t('ui.080')..display.number(units)..L.t('ui.081')..display.number(types)..(hidden>0 and(L.t('ui.082')..display.number(hidden))or'')))
  local xpText=L.t('ui.083')
  if backend.settings.specializationXpEnabled then
   if levelKnown and level>=100 then xpText=L.t('ui.084')
   elseif not levelKnown then xpText=L.t('ui.085')
   elseif total>0 and total<=6000 then xpText='\nXP: +'..display.number(xpPolicy.quote(total,backend.settings.specializationXpPerPoint))
   else xpText='\nXP: —'end
  end
  quote:SetText(FText(invalid and L.t('ui.086')or unknown and L.t('ui.087')or(L.t('ui.088')..display.number(total)..(total>6000 and L.t('ui.089')or xpText))))
  local receipt=backend.lastReceipt
  if types==0 and not backend.busy and receipt and receipt.house==id and receipt.kind=='items'then
   summary:SetText(FText(L.t('ui.090')..display.number(receipt.units)..L.t('ui.091')..display.number(receipt.personalAfter)))
   quote:SetText(FText(L.t('ui.092')..display.number(receipt.points)..L.t('ui.093')..display.number(receipt.xp)..' XP'))
  end
 end
 function view:submit()
  assert(not self.submitting and not backend.busy,L.t('ui.094'))
  local selected=assert(self.candidateSelection,L.t('ui.095'))
  local expectedPoints=self.expectedPoints
  local confirm=self.pending and self.pending.version==self.changeVersion and self.pending.points==expectedPoints
  local version=self.changeVersion
  local owner=backend:context().controller:GetAddress()
  self.submitting=true;proceed:SetIsEnabled(false)
  local function readInventory()
  ui.notice:SetText(FText(L.t('ui.096')))
  local catalog={};for _,item in ipairs(assert(requests:categoryItems(id)))do catalog[item.id]=item end
  ui.itemScan=dofile(DIR..'/backpack_native.lua').scan(app,backend,catalog,function(rows,err,snapshot)
   if ui.itemsView~=self or not ui.handle then return end
   self.submitting=false
   local ok,why=pcall(function()
    assert(self.changeVersion==version,L.t('ui.097'))
    assert(rows,err)
    local fresh={};for _,row in ipairs(rows)do fresh[row.key]=row end
    for _,old in ipairs(self.rows)do if selected[old.key]then
     local current=assert(fresh[old.key],L.t('ui.098'))
     for _,field in ipairs({'entity','database','slot','inventory','count'})do assert(current[field]==old[field],L.t('ui.099'))end
     assert(current.item.id==old.item.id,L.t('ui.100'))
    end end
    local payment=dofile(DIR..'/gear_payment.lua').new(backend,snapshot,rows,selected)
    if confirm then
     self.pending=nil;self.submittedQuantities=selected
     backend:donateItems(id,ui.board.term,snapshot,rows,selected)
     proceed:SetIsEnabled(false);proceed:GetChildAt(0):SetText(FText(L.t('ui.079')))
    else
     self.pending={version=version,points=expectedPoints}
     ui.notice:SetText(FText(L.t('ui.101')..display.number(payment.units)..L.t('ui.102')..display.number(expectedPoints)..L.t('ui.103')))
     proceed:SetIsEnabled(true);proceed:SetRenderOpacity(1);proceed:GetChildAt(0):SetText(FText(L.t('ui.041')))
    end
   end)
   if not ok then self.pending=nil;ui.notice:SetText(FText(display.error(why)));proceed:SetIsEnabled(false)end
  end)
  end
  if not confirm then readInventory();return end
  ui.notice:SetText(FText(L.t('ui.104')))
  local attempts=0
  local function waitForProgress()
   if ui.itemsView~=self or not ui.handle then return end
   attempts=attempts+1
   local ok,ready=pcall(function()
    assert(self.changeVersion==version,L.t('ui.105'))
    local context=backend:context();assert(context.controller:GetAddress()==owner,L.t('ui.106'))
    assert(backend:board().term==ui.board.term,L.t('ui.107'))
    local observer=assert(LDPersonalProgress)
    local data=observer:snapshot(context.controller,ui.board.term)
    return data and observer.fullReceivedAt and os.time()-observer.fullReceivedAt<=3
   end)
   if not ok or attempts>=80 and not ready then
    self.submitting=false;self.pending=nil
    ui.notice:SetText(FText(ok and L.t('ui.108')or display.error(ready)))
    return
   end
   if ready then readInventory()else assert(app:defer(250,waitForProgress))end
  end
  waitForProgress()
 end
 local selectVisible=ui:button(ui.content,L.t('ui.109'),42,226,168,34,function()
  for _,entry in ipairs(cached)do if searchPolicy.matches(entry.item.name,entry.item.id,view.query)then view.selection[entry.key]=true end end;view:update()
 end,false,13)
 ui:button(ui.content,L.t('ui.110'),220,226,145,34,function()view.selection={};view:update()end,false,13)
 local search=ui:make('EditableTextBox');search:SetText(FText(''));search.WidgetStyle.TextStyle.Font.Size=16
 search:SetHintText(FText(L.t('ui.111')));quantityStyle(search);ui.skin:font(search,17,true);ui:put(ui.content,search,381,226,393,34);view.search=search
 ui:label(ui.content,L.t('ui.112'),110,279,430,25,13,DIM)
 ui:label(ui.content,L.t('ui.113'),576,279,100,25,13,DIM)
 ui:label(ui.content,L.t('ui.114'),681,279,110,25,13,DIM)
 local scroll=ui:make('ScrollBox');scroll:SetClipping(1);ui:put(ui.content,scroll,35,316,750,398)
 local list=ui:make('VerticalBox');scroll:AddChild(list)
 function view:layout()end
 view.scroll=scroll;view.rowWidgets={}
 for _,entry in ipairs(cached)do
  local row=ui:make('CanvasPanel')
  local size=ui:make('SizeBox');size:SetHeightOverride(87);size:AddChild(row)
  list:AddChildToVerticalBox(size)
  local special=entry.item.id==request.id
  local art=ui.skin:image(row,special and'items-row-special.png'or'items-row.png',0,0,740,83)
  view.rowArt[entry.key]={widget=art,special=special,selected=false}
  local check=ui:button(row,'',6,26,28,28,function()
   view.selection[entry.key]=not view.selection[entry.key];view:update()
  end)
  view.checks[entry.key]=check
  local mark=ui.skin:image(row,'items-check-fill.png',6,26,28,28);mark:SetVisibility(1);view.marks[entry.key]=mark
  ui.skin:image(row,'items-icon-frame.png',44,9,64,64)
  local found,item=pcall(function()return ui.data:item({template=entry.item.id})end)
  if found and item.icon and item.icon:IsValid()then
   local img=ui:make('Image');img:SetBrushFromTexture(item.icon,false);img:SetVisibility(3);ui:put(row,img,47,12,58,58)
  else ui:label(row,'?',61,20,34,40,25,DIM)end
  ui:label(row,entry.item.name,118,13,nameWidth,40,16,special and BLUE or TEXT)
  local tier='—';for _,tag in ipairs(entry.item.tags)do tier=tag:match('^LootTier%.(%d+)$')or tier end
  local price=values.points(entry.item,backend.settings,special and 2 or 1)
  local detail=ui:label(row,L.t('ui.115')..tier..(special and L.t('ui.116')or L.t('ui.117'))..(not price and L.t('ui.118')or''),118,59,nameWidth,21,12,special and BLUE or DIM)
  local input,availableLabel
  if entry.count==1 then
   input=ui:label(row,'1',540,25,65,33,18,TEXT);input:SetJustification(1)
   -- Single instances keep a visible quantity of one.
  else
   input=ui:make('EditableTextBox');input:SetText(FText(tostring(entry.count)));input.WidgetStyle.TextStyle.Font.Size=17
   quantityStyle(input);ui.skin:font(input,18,true);ui:put(row,input,530,15,65,40)
   availableLabel=ui:label(row,'/ '..display.number(entry.count),531,59,110,22,12,DIM)
  end
  view.inputs[entry.key]=input
  ui:label(row,price and(price%1==0 and display.number(price)or string.format('%.2f',price))or'—',650,26,85,36,21,BLUE)
  view.rowWidgets[#view.rowWidgets+1]={widget=size,name=entry.item.name,id=entry.item.id,key=entry.key,count=entry.count,price=price,special=special,
   input=input,availableLabel=availableLabel,detail=detail,tier=tier}
 end
 if #cached==0 then
  local empty=ui:make('CanvasPanel');local size=ui:make('SizeBox');size:SetHeightOverride(150);size:AddChild(empty);list:AddChildToVerticalBox(size)
  ui:label(empty,L.t('ui.119'),20,12,700,50,18,DIM)
  ui:label(empty,L.t('ui.120'),20,67,700,62,14,DIM)
 end
 local orderNames={L.t('ui.121'),L.t('ui.122'),L.t('ui.113'),L.t('ui.123')}
 local orderModes=hasStacks and{1,2,3,4}or{1,2,4}
 view.order=1;view.orderIndex=1
 local orderButton
 function view:sort()
  table.sort(self.rowWidgets,function(a,b)
   if self.order==1 and a.special~=b.special then return a.special end
   if self.order==3 and a.count~=b.count then return a.count>b.count end
   if self.order==4 and (a.price or -1)~=(b.price or -1)then return(a.price or -1)>(b.price or -1)end
   local left,right=searchPolicy.fold(a.name),searchPolicy.fold(b.name)
   if left~=right then return left<right end
   return a.key<b.key
  end)
  -- Reparent synchronously, preserving each row's inputs and checkbox state.
  if #self.rowWidgets>0 then
   list:ClearChildren()
   for _,r in ipairs(self.rowWidgets)do list:AddChildToVerticalBox(r.widget)end
   self.scroll:ScrollToStart()
  end
  orderButton:GetChildAt(0):SetText(FText(L.t('ui.124')..orderNames[self.order]))
 end
 orderButton=ui:button(ui.content,L.t('ui.125'),270,69,330,34,function()
  view.orderIndex=view.orderIndex%#orderModes+1;view.order=orderModes[view.orderIndex];view:sort()
 end)
 function view:tick()
  if backend.busy then self.wasBusy=true
  elseif self.wasBusy then self.wasBusy=nil;ui:itemsPage(id,1);return end
  local payment=backend.currentPayment
  if backend.busy and payment and payment.house==id and payment.kind=='items'and payment.debited then
   for _,row in ipairs(self.rowWidgets)do
    if payment.keys[row.key]then
     local transferred=(payment.quantities and payment.quantities[row.key])or(self.submittedQuantities and self.submittedQuantities[row.key])or row.count
     local remaining=row.count-transferred
     if remaining<=0 then row.widget:SetVisibility(1)
     else
      -- A partial stack is still present. Keep its row and show its verified remainder.
      row.widget:SetVisibility(0);row.input:SetIsEnabled(false)
      row.input:SetText(FText(tostring(remaining)))
      if row.availableLabel then row.availableLabel:SetText(FText('/ '..display.number(remaining)))end
      row.detail:SetText(FText(L.t('ui.115')..row.tier..L.t('ui.126')..display.number(transferred)..L.t('ui.127')..display.number(remaining)))
      local check=self.checks[row.key];if check then check:SetIsEnabled(false);check:GetChildAt(0):SetText(FText(''))end
      if self.marks[row.key]then self.marks[row.key]:SetVisibility(1)end
     end
    end
   end
   summary:SetText(FText(L.t('ui.128')..display.number(payment.units)..L.t('ui.129')))
   quote:SetText(FText(payment.stage=='review'and L.t('ui.130')or payment.stage=='xp'and(L.t('ui.131')..display.number(payment.points)..L.t('ui.132'))or(L.t('ui.133')..display.number(payment.points)..L.t('ui.134'))))
   return -- Keep consumed rows hidden and stop editing a selection already sent for payment.
  end
  local now=os.clock();if self.nextPoll and now<self.nextPoll then return end;self.nextPoll=now+.15
  local query=stringOf(self.search:GetText())
  if query~=self.query then
   self.query=query
   for _,r in ipairs(self.rowWidgets)do r.widget:SetVisibility(searchPolicy.matches(r.name,r.id,query)and 0 or 1)end
   self.scroll:ScrollToStart()
   self:update()
  end
  local changed=false
  for id,input in pairs(self.inputs)do
   local value=stringOf(input:GetText());self.previousInputs=self.previousInputs or{}
   if self.previousInputs[id]~=value then self.previousInputs[id]=value;changed=true end
  end
  if changed then self:update()end
 end
 ui:help()
 view:layout()
 view:update()
end
return M
