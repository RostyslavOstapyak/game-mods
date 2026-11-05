local F=require('../../WPS_Framework/Scripts/api')
local app=F.new{id='LandsraadDonations',version='0.2.0-beta.5'}
local dir=debug.getinfo(1,'S').source:sub(2):gsub('\\','/'):match('^(.*)/[^/]+$')
local function log(s)print('[LandsraadDonations] '..tostring(s)..'\n')end
local settings=dofile(dir..'/../settings.lua')
LDBackend=dofile(dir..'/donations.lua').new(app,settings,dir..'/..')
LDPersonalProgress=dofile(dir..'/personal_progress.lua').new(app)
LDPanel=dofile(dir..'/panel.lua').new(app,LDBackend)
local function start()
LDTerminal=dofile(dir..'/terminal.lua').new(app,function()return LDPanel end)
LDDevTicker={active=true}
function LDDevTicker:cancel()self.active=false;if self.pending then self.pending:cancel()end end
local ticker=LDDevTicker
local function tick()
 if not ticker.active then return end
 local ok,err=pcall(function()LDPanel:tick()end)
 if not ok then log(err);pcall(function()LDPanel:close()end)end
 ticker.pending=app:defer(LDPanel.handle and 16 or 250,tick)
end
ticker.pending=app:defer(1,tick)
log('Loaded. Use E at a built Landsraad Terminal; Escape closes the window.')
end
-- Runtime registration requires both the game thread and a ready Framework.
app:retry{interval_ms=500,max_attempts=120,probe=function()return app:ready()end,on_ready=start}

