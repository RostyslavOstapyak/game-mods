-- Non-exclusive controller input. Reading a key never claims or consumes it.
-- Each consumer must validate its own target before opening a window.
local M={}
function M.new(app)
 local reader={previous={},controller=nil,keys={}}
 function reader:reset()self.previous={};self.controller=nil end
 function reader:pressed(pc,name)
  if not pc or not pc:IsValid()then self:reset();return false end
  local address=pc:GetAddress()
  if address~=self.controller then self.previous={};self.controller=address end
  self.keys[name]=self.keys[name]or{KeyName=FName(name)}
  local down=pc:IsInputKeyDown(self.keys[name])==true
  local pressed=down and self.previous[name]==false
  -- A held key on a new controller is not a new interaction.
  self.previous[name]=down;return pressed
 end
 return reader
end
return M
