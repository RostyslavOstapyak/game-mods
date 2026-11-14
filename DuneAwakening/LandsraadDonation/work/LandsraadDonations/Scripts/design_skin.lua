-- Our texture skin. Live hidden Image widgets retain imported resources per page.
local M={}
local DIR=debug.getinfo(1,'S').source:sub(2):gsub('\\','/'):match('^(.*)/[^/]+$')
local asset=dofile(DIR..'/loaded_asset.lua')
local WHITE={r=1,G=1,B=1,A=1}
function M.new(ui)
 local self={textures={}}
 local render=StaticFindObject('/Script/Engine.Default__KismetRenderingLibrary')
 local keeper=ui:make('CanvasPanel');ui:put(ui.content,keeper,0,0,1,1);keeper:SetVisibility(1)
 function self:texture(name)
  if self.textures[name]then return self.textures[name]end
  local t=render:ImportFileAsTexture2D(ui.pc,DIR..'/../UI/'..name)
  assert(t and t:IsValid(),'UI texture unavailable: '..name)
  local holder=ui:make('Image');holder:SetBrushFromTexture(t,false);keeper:AddChildToCanvas(holder)
  self.textures[name]=t;return t
 end
 function self:image(parent,name,x,y,w,h)
  local img=ui:make('Image');img:SetBrushFromTexture(self:texture(name),false);img:SetColorAndOpacity(WHITE);img:SetVisibility(3)
  return ui:put(parent,img,x,y,w,h)
 end
 function self:font(t,pixels,editable)
  local f=editable and t.WidgetStyle.TextStyle.Font or t.Font;f.FontObject=asset('/Game/Dune/Fonts/Raleway-Regular_Font.Raleway-Regular_Font');f.TypefaceFontName=FName('Default');f.Size=math.max(8,math.floor(pixels*.75+.5))
  -- EditableTextBox has no reflected SetFont in this game. Its style is set
  -- before the widget is attached; TextBlock uses its reflected setter.
  if not editable then t:SetFont(f)end
 end
 return self
end
return M
