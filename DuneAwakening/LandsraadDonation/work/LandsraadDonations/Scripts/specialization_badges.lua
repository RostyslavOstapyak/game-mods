-- Plain UI metadata. Track numbers match the verified ESpecializationTrack enum.
-- Line art is our own, not a claim to reproduce the game's specialization icons.
local M={}
local DIR=debug.getinfo(1,'S').source:sub(2):gsub('\\','/'):match('^(.*)/[^/]+$')
local L=dofile(DIR..'/localization.lua')
local asset=dofile(DIR..'/loaded_asset.lua')
local houseIcons
function M.icon(house)
 if not houseIcons then
  local icons,count={},0
  local library=StaticFindObject('/Script/Engine.Default__KismetSystemLibrary')
  for _,block in ipairs(FindAllOf('LandsraadVotingBlockDataAsset')or{})do
   if block and block:IsValid()then
    count=count+1
    local value=library:Conv_SoftObjectReferenceToString(block.m_Icon)
    local path=type(value)=='string'and value or value:ToString()
    if path~=''and path~='None'then
     block.m_HouseNames:ForEach(function(_,v)icons[v:get():ToString()]=path end)
    end
   end
  end
  if count==5 then houseIcons=icons end
  if not icons[house]then return nil end
  return asset(icons[house])
 end
 return houseIcons[house]and asset(houseIcons[house])or nil
end
local definitions={
 [1]={name=L.t('ui.135'),accepts=L.t('ui.136'),
  lines={{4,3,15,3},{15,3,19,7},{19,7,9,7},{9,7,4,3},{11,7,11,21},{11,21,15,21},{15,21,15,7}}},
 [2]={name=L.t('ui.137'),accepts=L.t('ui.138'),
  lines={{2,8,7,4},{7,4,15,4},{15,4,22,8},{7,4,12,10},{12,10,17,4},{12,10,5,22},{5,22,3,20},{3,20,10,9}}},
 [3]={name=L.t('ui.139'),accepts=L.t('ui.140'),
  lines={{12,1,22,12},{22,12,12,23},{12,23,2,12},{2,12,12,1},{12,5,9,15},{9,15,15,9},{15,9,12,5},{12,0,12,3},{12,21,12,24},{0,12,3,12},{21,12,24,12}}},
 [4]={name=L.t('ui.141'),accepts=L.t('ui.142'),
  lines={{4,2,19,17},{19,17,22,22},{22,22,17,19},{17,19,2,4},{2,4,4,2},{2,15,9,22},{4,20,20,4},{15,2,22,9}}},
 [5]={name=L.t('ui.143'),accepts=L.t('ui.144'),
  lines={{12,1,8,12},{8,12,12,17},{12,17,16,12},{16,12,12,1},{6,18,18,18},{12,18,12,23},{9,23,15,23}}},
}
function M.get(track)return definitions[track]end
function M.tooltip(definition)
 if not definition then return L.t('ui.145')end
 return definition.name..L.t('ui.146')..definition.accepts..L.t('ui.147')
end
return M
