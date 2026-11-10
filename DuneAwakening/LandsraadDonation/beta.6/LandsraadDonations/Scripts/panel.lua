local M={}
local function valid(o)return o and o:IsValid()end
local function text(v)return type(v)=='string'and v or v:ToString()end
local function col(r,g,b,a)return{r=r,G=g,B=b,A=a or 1}end
-- Palette shared with the approved HTML design (sRGB -> Slate linear colour).
local function hex(value)
 local function channel(n)n=n/255;return n<=.04045 and n/12.92 or((n+.055)/1.055)^2.4 end
 return col(channel(tonumber(value:sub(1,2),16)),channel(tonumber(value:sub(3,4),16)),channel(tonumber(value:sub(5,6),16)))
end
local GOLD=hex('8393a2')
local CREAM=hex('eee6d4')
local GREEN=hex('83bda8')
local RED=hex('cf8580')
local DARK=hex('070e17')
local BLUE=hex('b3d5e5')
local SURFACE=hex('0b1825')
local LINE=hex('40505b')
local DIR=debug.getinfo(1,'S').source:sub(2):gsub('\\','/'):match('^(.*)/[^/]+$')
local L=dofile(DIR..'/localization.lua')
local display=dofile(DIR..'/display_numbers.lua')
local number=display.number
local specialization=dofile(DIR..'/specialization_xp.lua')
local badges=dofile(DIR..'/specialization_badges.lua')
local inputStyle=dofile(DIR..'/quantity_style.lua')
function M.new(app,donations,preferences)
 preferences=preferences or{}
 local self={buttons={},cards={},data=dofile(DIR..'/house_data.lua').new(app),desiredPoints=preferences.desiredPoints or{},
  paymentKind=preferences.paymentKind,itemsExpanded=preferences.itemsExpanded}
 local requests=LDItemRequests
 if not requests or requests.version~=7 then
  requests=dofile(DIR..'/request_catalog.lua').new(app,DIR..'/..');LDItemRequests=requests
 end
 function self:make(n)
  local w=StaticConstructObject(StaticFindObject('/Script/UMG.'..n),self.tree,0,0)
  assert(valid(w),'Cannot create '..n);return w
 end
 function self:put(parent,w,x,y,width,height)
  local slot=parent:AddChildToCanvas(w);slot:SetPosition({X=x,Y=y});slot:SetSize({X=width,Y=height});return w
 end
 function self:label(parent,value,x,y,w,h,size,color)
  local t=self:make('TextBlock');t:SetText(FText(value));t.Font.Size=size or 20;t:SetAutoWrapText(true)
  if self.skin then self.skin:font(t,size or 20)end
  t:SetColorAndOpacity({SpecifiedColor=color or CREAM,ColorUseRule=0});t:SetVisibility(3)
  return self:put(parent,t,x,y,w,h)
 end
 function self:line(parent,x,y,w)
  local b=self:make('Border');b:SetBrushColor(GOLD);return self:put(parent,b,x,y,w,1)
 end
 function self:fill(parent,x,y,w,h,color)
  local b=self:make('Border');b:SetBrushColor(color);b:SetVisibility(3);return self:put(parent,b,x,y,w,h)
 end
 function self:segment(parent,x1,y1,x2,y2,color)
  local dx,dy=x2-x1,y2-y1
  local b=self:fill(parent,x1,y1-1,math.sqrt(dx*dx+dy*dy),2,color)
  b:SetRenderTransformPivot({X=0,Y=.5});b:SetRenderTransformAngle(math.deg(math.atan(dy,dx)));return b
 end
 function self:cutPanel(parent,w,h,cut,body,outline)
  self:fill(parent,cut,0,w-cut*2,h,body)
  self:fill(parent,0,cut,w,h-cut*2,body)
  for row=1,cut-1 do
   self:fill(parent,cut-row,row,row,1,body);self:fill(parent,w-cut,row,row,1,body)
   self:fill(parent,cut-row,h-row-1,row,1,body);self:fill(parent,w-cut,h-row-1,row,1,body)
  end
  local points={{cut,1},{w-cut,1},{w-1,cut},{w-1,h-cut},{w-cut,h-1},{cut,h-1},{1,h-cut},{1,cut}}
  local edges={}
  for i,p in ipairs(points)do local q=points[i%#points+1];edges[#edges+1]=self:segment(parent,p[1],p[2],q[1],q[2],outline)end
  return edges
 end
 function self:updateCard(card,h)
  if card.art and self.skin then
   card.ownerTexture=h.completed and(h.winner=='Atreides'and'study-card-green.png'or'study-card-red.png')or'study-card.png'
   if not card.button:IsHovered()then card.art:SetBrushFromTexture(self.skin:texture(card.ownerTexture),false)end
  end
  local function fraction(value,goal)return goal and goal>0 and math.max(0,math.min(1,value/goal))or 0 end
  local left=89*fraction(h.atreides,h.atreidesGoal)
  local right=89*fraction(h.harkonnen,h.harkonnenGoal)
  card.left.Slot:SetPosition({X=103-left,Y=108});card.left.Slot:SetSize({X=left,Y=6})
  card.right.Slot:SetSize({X=right,Y=6})
  card.button:SetToolTipText(FText(badges.tooltip(card.specialization)..string.format(L.t('ui.001'),number(h.atreides),number(h.atreidesGoal),number(h.harkonnen),number(h.harkonnenGoal))))
 end
 function self:button(parent,title,x,y,w,h,callback,active,fontSize,primary)
  local plate=self:make('CanvasPanel');plate:SetVisibility(3);self:put(parent,plate,x,y,w,h)
  local edges,art,baseTexture,hoverTexture={}
  if(self.screen=='details'or self.screen=='items')and self.skin then
   baseTexture=(self.screen=='items'and w==28 and h==28)and'items-check-off.png'or(primary and'detail-primary.png'or(active and'detail-active.png'or'detail-control.png'))
   hoverTexture=(self.screen=='items'and w==28 and h==28)and'items-check-off.png'or(primary and'detail-primary-hover.png'or(active and'detail-active.png'or'detail-control-hover.png'))
   art=self.skin:image(plate,baseTexture,0,0,w,h)
   if active and not primary then self:fill(plate,1,8,2,h-16,BLUE)end
  else
   edges=self:cutPanel(plate,w,h,8,primary and BLUE or(active and hex('183449')or SURFACE),primary and BLUE or(active and BLUE or LINE))
   if active and not primary then self:fill(plate,12,h-5,w-24,3,BLUE)end
  end
  local b=self:make('Button');self:put(parent,b,x,y,w,h)
  for _,state in ipairs({'Normal','Hovered','Pressed','Disabled'})do b.WidgetStyle[state].DrawAs=0 end
  local t=self:make('TextBlock');t:SetText(FText(title));t.Font.Size=fontSize or 18;t:SetJustification(1);t:SetColorAndOpacity({SpecifiedColor=primary and hex('10202c')or CREAM,ColorUseRule=0})
  if(self.screen=='details'or self.screen=='items')and self.skin then self.skin:font(t,fontSize or 18)end
  local slot=b:AddChild(t);slot:SetPadding({Left=8,Top=0,Right=8,Bottom=0});slot:SetHorizontalAlignment(0);slot:SetVerticalAlignment(2)
  self.buttons[#self.buttons+1]={widget=b,plate=plate,callback=callback,onHover=function(hover)if art then art:SetBrushFromTexture(self.skin:texture(hover and hoverTexture or baseTexture),false)else for _,edge in ipairs(edges)do edge:SetBrushColor(hover and CREAM or(active and BLUE or GOLD))end end end};return b
 end
 function self:surface(x,y,w,h)
  if self.screen=='items'and self.skin then self.skin:image(self.content,w==770 and'items-inventory.png'or'items-basket.png',x,y,w,h);return end
  if(self.screen=='details'or self.screen=='items')and self.skin then
   self.skin:image(self.content,w==254 and'detail-sidebar.png'or(h==133 and'detail-statistics.png'or'detail-body.png'),x,y,w,h);return
  end
  self:fill(self.content,x,y,w,h,SURFACE)
  self:fill(self.content,x,y,w,1,LINE);self:fill(self.content,x,y+h-1,w,1,LINE)
  self:fill(self.content,x,y,1,h,LINE);self:fill(self.content,x+w-1,y,1,h,LINE)
 end
 function self:header()
  self:fill(self.content,22,16,2,35,BLUE)
  self:label(self.content,'Lansarad Donation',38,15,610,46,29,CREAM)
  local row=(self.screen=='details'or self.screen=='items')and 52 or 0
  self:label(self.content,L.t('ui.002'),665,29+row,125,24,13,GREEN)
  self:label(self.content,L.t('ui.003'),790,29+row,145,24,13,RED)
  self.helpToggle=self:button(self.content,L.t('ui.004'),945,17+row,150,36,function()
   if valid(self.helpPanel)then self.helpOpen=not self.helpOpen;self.helpPanel:SetVisibility(self.helpOpen and 0 or 1)end
  end,false,13)
 end
 function self:help()
  self.skin=self.skin or dofile(DIR..'/design_skin.lua').new(self)
  local overlay=self:make('CanvasPanel');self:put(self.content,overlay,527,(self.screen=='details'or self.screen=='items')and 112 or 66,568,532)
  overlay:SetVisibility(1);self.helpPanel=overlay;self.helpOpen=false
  self.skin:image(overlay,'study-help.png',0,0,568,532)
  local scroll=self:make('ScrollBox');self:put(overlay,scroll,28,24,512,484)
  local flow=self:make('VerticalBox');scroll:AddChild(flow)
  local function paragraph(value,size,ink,gap)
   local t=self:make('TextBlock');t:SetText(FText(value));self.skin:font(t,size)
   t.WrapTextAt=496;t:SetAutoWrapText(true);t:SetColorAndOpacity({SpecifiedColor=ink,ColorUseRule=0});t:SetVisibility(3)
   local slot=flow:AddChildToVerticalBox(t);slot:SetPadding({Left=0,Top=gap or 0,Right=0,Bottom=0})
  end
  paragraph(L.t('ui.005'),27,CREAM)
  paragraph(L.t('ui.006'),18,CREAM,22)
  paragraph(L.t('ui.007'),20,BLUE,22)
  paragraph(L.t('ui.008'),17,CREAM,14)
  paragraph(L.t('ui.009'),17,CREAM,20)
  paragraph(L.t('ui.010'),16,GOLD,20)
 end
 function self:rememberDesiredPoints()
  if self.screen=='details'and self.selected and valid(self.amount)then self.desiredPoints[self.selected.id]=text(self.amount:GetText())end
 end
 function self:clearContent()
  self:rememberDesiredPoints()
  self.itemsView=nil
  if self.itemScan then self.itemScan:cancel();self.itemScan=nil end
  -- Move focus off child buttons before removing the active page.
  if self.handle then StaticFindObject('/Script/UMG.Default__WidgetBlueprintLibrary'):SetInputMode_UIOnlyEx(self.pc,self.handle.widget,0,false)end
  for _,h in ipairs(self.cards)do h:close()end;self.cards={}
  self.helpPanel=nil;self.helpOpen=false;self.fundsWarning=nil;self.skin=nil;self.content:ClearChildren();self.buttons={};self.gridCards={};self.amount=nil;self.slider=nil;self.pending=nil
 end
 function self:refreshData()
  self.board=donations:board();self.houses=self.data:read();self.available={}
  self.currentBalance=self.board.balance
  for _,h in ipairs(self.board.houses)do self.available[h.id]=true end
 end
 function self:grid()
  self:refreshData();self:clearContent();self.screen='grid'
  requests:ensure()
  self.skin=dofile(DIR..'/design_skin.lua').new(self)
  self.skin:image(self.content,'study-backdrop.png',0,0,1120,806)
  self:header()
  for i,h in ipairs(self.houses)do
   local index=i-1;local x=20+(index%5)*218;local y=88+math.floor(index/5)*132
   local b=self:make('Button');self:put(self.content,b,x,y,208,118)
   for _,property in ipairs({'NormalPadding','PressedPadding'})do
    local padding=b.WidgetStyle[property];padding.Left=0;padding.Right=0;padding.Top=0;padding.Bottom=0
   end
   for _,state in ipairs({'Normal','Hovered','Pressed','Disabled'})do b.WidgetStyle[state].DrawAs=0 end
   local canvas=self:make('CanvasPanel');local slot=b:AddChild(canvas)
   slot:SetPadding({Left=0,Top=0,Right=0,Bottom=0});slot:SetHorizontalAlignment(0);slot:SetVerticalAlignment(0)
   canvas:SetClipping(1)
   local art=self.skin:image(canvas,'study-card.png',0,0,208,118)
   local icon=self.data:icon(h)
   if valid(icon)then local img=self:make('Image');img:SetBrushFromTexture(icon,false);img:SetColorAndOpacity(CREAM);img:SetVisibility(3);self:put(canvas,img,72,11,64,64)end
   local resolved,track=pcall(specialization.resolve,h.id)
   local badge=resolved and badges.get(track)or nil
   if badge then
    local ok,specializationIcon=pcall(badges.icon,h.id)
    if ok and valid(specializationIcon)then
     local img=self:make('Image');img:SetBrushFromTexture(specializationIcon,false);img:SetColorAndOpacity(CREAM);img:SetVisibility(3)
     self:put(canvas,img,12,9,35,35)
    else
     for _,line in ipairs(badge.lines)do self:segment(canvas,18+line[1],13+line[2],18+line[3],13+line[4],CREAM)end
    end
   end
   local name=self:label(canvas,h.name,10,80,188,26,16,CREAM);name:SetJustification(1);self.skin:font(name,20)
   self:fill(canvas,14,108,180,6,col(.025,.070,.11))
   local card={button=b,art=art,specialization=badge,left=self:fill(canvas,103,108,0,6,GREEN),right=self:fill(canvas,105,108,0,6,RED)}
   self:fill(canvas,103,106,2,10,CREAM);self.gridCards[h.id]=card;self:updateCard(card,h)
   b:SetIsEnabled(self.available[h.id]==true)
   self.buttons[#self.buttons+1]={widget=b,callback=function()self:details(h.id)end,onHover=function(hover)art:SetBrushFromTexture(self.skin:texture(hover and'study-card-hover.png'or(card.ownerTexture or'study-card.png')),false)end}
  end
  self.notice=self:label(self.content,'',24,757,820,30,13,GOLD)
  self:button(self.content,L.t('ui.012'),910,750,185,36,function()self:close()end,false,13)
  self:help()
  self.gridUpdatedAt=os.time()
 end
 function self:details(id)
  self:refreshData();local selected
  for _,h in ipairs(self.houses)do if h.id==id then selected=h end end
  assert(selected and self.available[id],L.t('ui.013'))
  self:clearContent();self.screen='details';self.selected=selected
  self.skin=dofile(DIR..'/design_skin.lua').new(self)
  self.skin:image(self.content,'study-backdrop.png',0,0,1120,806)
  self:header()
  self:button(self.content,L.t('ui.014'),24,69,170,34,function()self:grid()end,false,13)
  self:segment(self.content,48,80,41,86,BLUE)
  self:segment(self.content,41,86,48,92,BLUE)
  self:segment(self.content,41,86,57,86,BLUE)
  self:button(self.content,L.t('ui.012'),925,17,170,36,function()self:close()end,false,13)
  local definition=badges.get(specialization.resolve(id))
  self:surface(24,123,254,655)
  self:label(self.content,L.t('ui.015'),48,146,210,26,12,GOLD)
  local image=self:make('Image');image:SetBrushFromTexture(self.data:icon(selected),false);image:SetColorAndOpacity(CREAM);image:SetVisibility(3)
  self:put(self.content,image,101,198,100,100)
  local name=self:label(self.content,selected.name,44,320,214,45,29,CREAM);name:SetJustification(1)
  local spec=self:label(self.content,definition.name,44,371,214,28,16,GOLD);spec:SetJustification(1)
  self:fill(self.content,48,421,206,1,LINE)
  self:label(self.content,L.t('ui.016'),48,441,210,26,13,GOLD)
  self.progress=self:label(self.content,'',48,477,210,27,15,CREAM)
  self:label(self.content,L.t('ui.017'),48,513,100,22,12,GREEN)
  self:label(self.content,L.t('ui.018'),151,513,105,22,12,RED)
  self:fill(self.content,48,545,206,3,LINE)
  self.sideLeft=self:fill(self.content,151,545,0,3,GREEN)
  self.sideRight=self:fill(self.content,151,545,0,3,RED)
  self:label(self.content,L.t('ui.019'),48,567,210,28,13,GOLD)
  self.houseRequest=self:label(self.content,L.t('ui.020'),48,605,210,75,17,CREAM)
  self:label(self.content,L.t('ui.021'),48,701,210,55,14,GOLD)
  self:surface(300,123,795,133)
  self:label(self.content,L.t('ui.022'),324,143,240,25,13,GOLD)
  self.personal=self:label(self.content,'',324,180,245,46,29,CREAM)
  self:label(self.content,L.t('ui.023'),596,143,470,25,13,GOLD)
  self.rewardLabels={}
  local count=math.max(1,#selected.rewards);local spacing=math.min(94,470/count)
  for i,r in ipairs(selected.rewards)do
   local item=self.data:item(r);local x=596+(i-1)*spacing
   self.rewardLabels[i]=self:label(self.content,number(r.threshold),x,224,spacing,22,12,CREAM)
   if valid(item.icon)then local img=self:make('Image');img:SetBrushFromTexture(item.icon,false);img:SetVisibility(3);self:put(self.content,img,x,176,38,38);img:SetToolTipText(FText(number(r.amount)..' × '..item.name))end
  end
  self:surface(300,276,795,502)
  self:label(self.content,L.t('ui.024'),324,295,600,42,26,CREAM)
  self.paymentKind=self.paymentKind or'solari'
  self:button(self.content,L.t('ui.025'),324,352,363,55,function()self.paymentKind='solari';self:details(id)end,self.paymentKind=='solari',18)
  self:button(self.content,L.t('ui.026'),703,352,368,55,function()self.paymentKind='melange';self:details(id)end,self.paymentKind=='melange',18)
  self.skin:image(self.content,'detail-balance.png',324,416,747,46)
  self.stock=self:label(self.content,'',340,429,715,31,22,CREAM)
  self:label(self.content,L.t('ui.027'),324,474,520,28,17,CREAM)
  self:label(self.content,L.t('ui.028'),856,478,215,24,12,GOLD)
  self.amount=self:make('EditableTextBox');self.amount:SetText(FText(self.desiredPoints[id]or'1000'));self.amount.WidgetStyle.TextStyle.Font.Size=29
  inputStyle(self.amount);self.skin:font(self.amount,29,true);self:put(self.content,self.amount,324,512,240,58)
  self:label(self.content,L.t('ui.029'),582,529,240,30,15,GOLD)
  self.slider=self:make('Slider');self.slider:SetMinValue(0);self.slider:SetMaxValue(1);self.slider:SetSliderBarColor(LINE);self.slider:SetSliderHandleColor(BLUE)
  self.slider:SetStepSize(1/60);self:put(self.content,self.slider,324,586,747,25)
  self:label(self.content,L.t('ui.030'),324,628,340,26,13,GOLD)
  self:label(self.content,L.t('ui.031'),674,628,180,26,13,GOLD)
  self:label(self.content,L.t('ui.032'),874,628,200,26,13,GOLD)
  self.preview=self:label(self.content,'',324,658,340,40,25,CREAM);self.preview:SetAutoWrapText(false)
  self.quotePoints=self:label(self.content,'',674,658,180,40,25,BLUE)
  self.quoteXp=self:label(self.content,'',874,658,200,40,25,BLUE)
  local rate=self.paymentKind=='melange'and(donations.settings.solariPerMelange/donations.settings.solariPerContribution)or(1/donations.settings.solariPerContribution)
  self:label(self.content,L.t('ui.033')..tostring(rate)..L.t('ui.034')..(self.paymentKind=='melange'and L.t('ui.035')or L.t('ui.036')),324,700,420,20,11,GOLD)
  self.fundsWarning=self:label(self.content,'',755,700,316,21,13,RED);self.fundsWarning:SetAutoWrapText(false)
  self:button(self.content,L.t('ui.037'),324,723,330,42,function()self:itemsPage(id,1)end,true,16)
  self.review=self:button(self.content,L.t('ui.038'),675,723,396,42,function()
   local cost,points=donations:quote(text(self.amount:GetText()),self.paymentKind)
   local context=donations:context()
   local balance=self.paymentKind=='melange'and donations:melangeBalance(context.pawn)or donations:balance(context.controller)
   assert(cost<=balance,self.paymentKind=='melange'and L.t('ui.039')or L.t('ui.040'))
   if self.pending and self.pending.cost==cost and self.pending.points==points and self.pending.kind==self.paymentKind then
    local p=self.pending;self.pending=nil;donations:donate(selected.id,p.points,self.board.term,p.kind)
    self.review:GetChildAt(0):SetText(FText(L.t('ui.038')))
   else
    self.pending={cost=cost,points=points,kind=self.paymentKind};self.review:GetChildAt(0):SetText(FText(L.t('ui.041')))
    self.notice:SetText(FText(string.format(L.t('ui.042'),number(cost),self.paymentKind=='melange'and L.t('ui.043')or L.t('ui.036'),number(points))))
   end
  end,false,16,true)
  self.notice=self:label(self.content,'',300,784,795,24,12,GOLD)
  self:help()
  self.lastAmount=nil;self.lastSlider=nil;self:updateDetails()
 end
 function self:updateFundsWarning()
  if not valid(self.fundsWarning)or not valid(self.amount)then return end
  local ok,cost=pcall(function()return donations:quote(text(self.amount:GetText()),self.paymentKind)end)
  local balance=self.paymentKind=='melange'and(self.currentMelange or 0)or(self.currentBalance or 0)
  self.fundsWarning:SetText(FText(ok and balance<cost and L.t('ui.158')or''))
 end
 function self:updateDetails()
  local h=self.selected
  local ok,request,why=pcall(function()return requests:request(h.id,donations:board().term)end)
  self.houseRequest:SetText(FText(ok and(request and request.name or why)or L.t('ui.044')))
  for _,v in ipairs(self.data:read())do if v.id==h.id then h=v;self.selected=v end end
  self.personal:SetText(FText((h.personal and number(h.personal)or L.t('ui.045'))))
  self.progress:SetText(FText(number(h.progress)..' / '..number(h.goal)..(h.completed and L.t('ui.046')or'')))
  local a=h.atreidesGoal>0 and math.min(1,h.atreides/h.atreidesGoal)or 0
  local b=h.harkonnenGoal>0 and math.min(1,h.harkonnen/h.harkonnenGoal)or 0
  self.sideLeft.Slot:SetPosition({X=151-103*a,Y=545});self.sideLeft.Slot:SetSize({X=103*a,Y=3})
  self.sideRight.Slot:SetSize({X=103*b,Y=3})
  if self.paymentKind=='melange'then
   local ok,amount=pcall(function()return donations:melangeBalance()end)
   self.currentMelange=ok and amount or nil
   self.stock:SetText(FText(ok and(L.t('ui.047')..number(amount))or L.t('ui.048')))
  else self.stock:SetText(FText(L.t('ui.049')..number(self.currentBalance or 0)..L.t('ui.050')))end
  for i,r in ipairs(h.rewards)do if self.rewardLabels[i]then self.rewardLabels[i]:SetColorAndOpacity({SpecifiedColor=h.personal and h.personal>=r.threshold and BLUE or CREAM,ColorUseRule=0})end end
  self:updateFundsWarning()
 end
 function self:itemsPage(id,page,cached)
  if donations.busy and donations.currentPayment and donations.currentPayment.stage~='review'then
   if self.notice then self.notice:SetText(FText(L.t('ui.051')))end
   return -- Do not start a UI scan while the exact payment is using the inventory reader.
  end
  return dofile(DIR..'/items_view.lua').build(self,app,donations,requests,id,cached)
 end
 function self:specializationLevel(id)
  local track=specialization.resolve(id)
  local context=donations:context()
  local _,level=specialization.read(context.controller,track)
  return level
 end
 function self:close()
  self:rememberDesiredPoints()
  self.itemsView=nil
  self.loading=false
  if self.itemScan then self.itemScan:cancel();self.itemScan=nil end
  if not self.handle then return end
  pcall(function()
   app._controller=nil;local s=app:session()
   if not s.ok or s.controller:GetAddress()~=self.pcAddress then return end
   local pc=s.controller
   pc:SetIgnoreMoveInput(false);pc:SetIgnoreLookInput(false)
   if not pc:GetHUD():GetActiveWindow():IsValid()then pc.bShowMouseCursor=false;StaticFindObject('/Script/UMG.Default__WidgetBlueprintLibrary'):SetInputMode_GameOnly(pc,false)end
  end)
  for _,h in ipairs(self.cards)do h:close()end;self.cards={}
  self.handle:close();self.handle=nil;self.buttons={}
 end
 function self:build()
  local h,e=app:ui_create('/Script/DuneSandbox.DuneUserWidget',{z_order=950});assert(h,e and e.message);self.handle=h
  self.tree=h.widget.WidgetTree;h.widget:RemoveFromParent()
  local size=StaticFindObject('/Script/UMG.Default__WidgetLayoutLibrary'):GetViewportSize(self.pc)
  local dpi=StaticFindObject('/Script/UMG.Default__WidgetLayoutLibrary'):GetViewportScale(self.pc)
  assert(type(dpi)=='number'and dpi>0,'Viewport scale unavailable.')
  local width,height=size.X/dpi,size.Y/dpi
  local root=self:make('CanvasPanel');self.tree.RootWidget=root
  self:fill(root,0,0,width,height,DARK)
  -- Own bounded decorative geometry: no native menu widget or input lifecycle is reused.
  local ornament=hex('101b27')
  for i=-2,8 do self:segment(root,i*width/7,0,i*width/7-height*.53,height,ornament)end
  self:fill(root,18,18,width-36,1,hex('1a2631'));self:fill(root,18,height-19,width-36,1,hex('1a2631'))
  local factor=math.min(width*.94/1124,height*.94/810)
  local scale=self:make('ScaleBox');scale:SetStretch(2)
  self:put(root,scale,(width-1124*factor)/2,(height-810*factor)/2,1124*factor,810*factor)
  local sizing=self:make('SizeBox');sizing:SetWidthOverride(1124);sizing:SetHeightOverride(810);scale:AddChild(sizing)
  local frame=self:make('CanvasPanel');sizing:AddChild(frame)
  -- The canvas remains open; individual cards carry the borders.
  -- Page-specific separators only; no shared line crosses the donation receipt.
  self.content=self:make('CanvasPanel');self:put(frame,self.content,2,2,1120,806)
  h.widget:SetDesiredSizeInViewport({X=width,Y=height});h.widget:SetAlignmentInViewport({X=0,Y=0})
  h.widget:SetPositionInViewport({X=0,Y=0},false);h.widget:AddToViewport(950)
  self:grid()
  self.pc.bShowMouseCursor=true;self.pc:SetIgnoreMoveInput(true);self.pc:SetIgnoreLookInput(true)
  StaticFindObject('/Script/UMG.Default__WidgetBlueprintLibrary'):SetInputMode_UIOnlyEx(self.pc,h.widget,0,false)
  self.lastMessage=donations.message
  print('[LandsraadDonations] Two-screen panel opened.\n')
 end
 function self:open()
  if self.handle then return end
  if self.loading then return end
  self.pc=donations:context().controller
  self.pcAddress=self.pc:GetAddress();self.sessionCheckedAt=nil;self.sessionUnavailable=false
  assert(not self.pc.bShowMouseCursor,L.t('ui.052'))
  L.refresh()
  if self.languageTag~=L.tag then
   self.languageTag=L.tag;self.data.metadata={};self.data.items={}
   badges=dofile(DIR..'/specialization_badges.lua')
  end
  if requests.language~=L.tag then
   requests=dofile(DIR..'/request_catalog.lua').new(app,DIR..'/..');requests.language=L.tag;LDItemRequests=requests
  end
  self.data:ensure()
  self.loading=true;local attempts=0
  local function ready()
   if not self.loading then return end
   attempts=attempts+1
   local ok,houses=pcall(function()return self.data:read()end)
   if not ok then self.loading=false;error('Landsraad data: '..tostring(houses))end
   if #houses~=25 then if attempts<20 then app:defer(200,ready);return end;self.loading=false;error('Landsraad data did not load: '..#houses..' houses.')end
   self.loading=false
   local built,err=pcall(function()self:build()end);if not built then self:close();error(err)end
  end
  app:defer(250,ready)
 end
 function self:tick()
  if not self.handle then return end
  if self.sessionCheckedAt~=os.time()then
   self.sessionCheckedAt=os.time()
   app._controller=nil;local s=app:session()
   if not s.ok then self.sessionUnavailable=true;return end
   if s.controller:GetAddress()~=self.pcAddress then self:close();return end
   self.pc=s.controller;self.sessionUnavailable=false;self.currentBalance=donations:balance(s.controller)
   if self.pc:GetHUD():GetActiveWindow():IsValid()then self:close();return end
  end
  if self.sessionUnavailable then return end
  if donations.message~=self.lastMessage then self.lastMessage=donations.message;self.notice:SetText(FText(display.message(donations.message)))end
  if self.screen=='grid'and os.time()-(self.gridUpdatedAt or 0)>=1 then
   self.gridUpdatedAt=os.time();self:refreshData()
   for _,h in ipairs(self.houses)do local card=self.gridCards[h.id];if card then self:updateCard(card,h)end end
  end
  if self.screen=='details'and valid(self.amount)and valid(self.slider)then
   local amount=text(self.amount:GetText());local slider=self.slider:GetValue()
   local settings=donations.settings;local maximum=settings.maxContributionPerTransaction
   local minimum=1
   if self.lastSlider and math.abs(slider-self.lastSlider)>.00001 then
    local value=math.max(minimum,math.min(maximum,math.floor(slider*maximum/100+.5)*100))
    self.amount:SetText(FText(tostring(value)));amount=tostring(value)
   end
   if amount~=self.lastAmount then
    self.pending=nil;self.review:GetChildAt(0):SetText(FText(L.t('ui.038')))
    local ok,cost,points=pcall(function()return donations:quote(amount,self.paymentKind)end)
    local balance=self.paymentKind=='melange'and(self.currentMelange or 0)or(self.currentBalance or 0)
    local xp=points and math.floor(points*(settings.specializationXpPerPoint or 1))or 0
    local preview=ok and(number(cost)..(self.paymentKind=='melange'and L.t('ui.053')or L.t('ui.050')))or'—'
    self.preview:SetText(FText(preview));self:updateFundsWarning()
    self.quotePoints:SetText(FText(ok and('+'..number(points))or'—'))
    self.quoteXp:SetText(FText(ok and(settings.specializationXpEnabled and('+'..number(xp)..' XP')or L.t('ui.055'))or'—'))
    local n=tonumber(amount);if n then self.slider:SetValue(maximum==minimum and 0 or math.max(0,math.min(1,(n-minimum)/(maximum-minimum))))end
    self.lastAmount=amount
   end
   self.lastSlider=self.slider:GetValue()
   if not self.updatedAt or os.time()-self.updatedAt>=1 then self.updatedAt=os.time();self:updateDetails()end
  end
  if self.screen=='items'and self.itemsView and self.itemsView.tick then self.itemsView:tick()end
  for _,b in ipairs(self.buttons)do
   if self.helpOpen and b.widget~=self.helpToggle then b.down=false else
   if b.onHover then local hover=b.widget:IsHovered();if hover~=b.hover then b.hover=hover;b.onHover(hover)end end
   local pressed=b.widget:IsPressed()
   if b.down and not pressed and b.widget:IsHovered()then b.down=false;local ok,e=pcall(b.callback);if not ok then print('[LandsraadDonations] UI ERROR '..tostring(e)..'\n');if self.handle and valid(self.notice)then self.notice:SetText(FText(display.error(e)))end end;return end
   b.down=pressed
   end
  end
 end
 return self
end
return M






