-- Read-only adapter: prefer exact backpack slots; aggregate fallback remains preview-only.
local M={}
local DIR=debug.getinfo(1,'S').source:sub(2):gsub('\\','/'):match('^(.*)/[^/]+$')
function M.scan(app,backend,items,callback)
 local token={active=true}
 function token:cancel()
  self.active=false;if self.child then self.child:cancel()end
 end
 local function finish(rows,err)
  if not token.active then return end
  token.active=false;callback(rows,err)
 end
 local function fallback(reason)
  if not token.active then return end
  print('[LD_INVENTORY] native unavailable: '..tostring(reason)..'; aggregate preview only.\n')
  token.child=dofile(DIR..'/backpack_items.lua').scan(app,backend,items,function(rows,err)
   if rows then rows.mode='aggregate';rows.readError=tostring(reason)end
   finish(rows,err)
  end)
 end
 local native=dofile(DIR..'/backpack_native.lua')
 if not native.available()then fallback('NBS_PadScan missing');return token end
 local catalog={};for _,item in ipairs(items)do catalog[item.id]=item end
 token.child=native.scan(app,backend,catalog,function(rows,err,snapshot)
  if not token.active then return end
  if not rows then fallback(err);return end
  rows.mode='instances';rows.snapshot=snapshot
  print('[LD_INVENTORY] native backpack read complete: '..snapshot.used..' occupied slots, '..#rows..' category entries. Equipment exclusion requires confirmation.\n')
  finish(rows)
 end)
 return token
end
return M
