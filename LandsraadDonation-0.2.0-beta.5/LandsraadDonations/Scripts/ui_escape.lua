-- UE4SS key notification is not a Framework exclusive input claim.
-- UIOnly keeps Escape out of gameplay; this observer closes only our own panel.
local M={}
function M.attach(app,getPanel)
 local id='LandsraadDonationsEscapeObserver'
 local existing=rawget(_G,id)
 if existing then existing.app=app;existing.getPanel=getPanel;existing.active=true;return existing end
 local observer={app=app,getPanel=getPanel,active=true,pending=false}
 function observer:cancel()self.active=false end
 assert(type(RegisterKeyBind)=='function','UE4SS Escape notifications unavailable.')
 RegisterKeyBind(27,function()
  if not observer.active or observer.pending or observer.app.closed then return end
  observer.pending=true
  local ok,why=pcall(function()observer.app:defer(1,function()
   observer.pending=false
   if not observer.active or observer.app.closed then return end
   local panel=observer.getPanel()
   if panel and(panel.handle or panel.loading)then
    panel:close();print('[LandsraadDonations] Escape closed own panel.\n')
   end
  end)end)
  if not ok then observer.pending=false;print('[LandsraadDonations] Escape dispatch failed: '..tostring(why)..'\n')end
 end)
 rawset(_G,id,observer);return observer
end
return M
