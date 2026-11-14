local M={}
local mapping
local function valid(o)return o and o:IsValid()end
local function signature(class,name,fields)
 local path='/Script/DuneSandbox.'..class..':'..name
 local f=StaticFindObject(path);assert(valid(f),'Specialization interface unavailable: '..name)
 local actual={};f:ForEachProperty(function(p)actual[#actual+1]=p:GetFullName()end)
 assert(#actual==#fields,'Specialization interface changed: '..name)
 for i,field in ipairs(fields)do
  local kind,key=field:match('(%S+) (%S+)')
  assert(actual[i]==kind..' '..path..':'..key,'Specialization parameter changed: '..name)
 end
end
function M.resolve(house)
 if not mapping then
  local dt=LoadAsset('/Game/Dune/Systems/Landsraad/DT_LandsraadContractsDailyBonus.DT_LandsraadContractsDailyBonus')
  assert(valid(dt),'Landsraad bonus table unavailable.')
  local rows={};for _,name in ipairs(dt:GetRowNames())do rows[type(name)=='string'and name or name:ToString()]=true end
  local result,total,groups={ },0,0
  for _,block in ipairs(FindAllOf('LandsraadVotingBlockDataAsset')or{})do
   if valid(block)then
    groups=groups+1;assert(groups<=5,'Unexpected Landsraad voting blocks.')
    local tracks,seen={},{}
    local function visit(node,depth)
     if not valid(node)then return end
     local address=node:GetAddress();if seen[address]then return end;seen[address]=true
     total=total+1;assert(total<=2000 and depth<=16,'Landsraad contract graph exceeds limit.')
     if not node.m_bIsDebugMission then
      local bonus=node.m_LandsraadDailyBonusType.Name:ToString()
      if rows[bonus]then
       local reward=dt:FindRow(bonus)
       reward.m_ListenServerBonusRewardData.m_SpecializationXP:ForEach(function(_,v)
        local r=v:get();local track,amount=r.SpecializationTrack,r.Amount
        if amount>0 then
         assert(type(track)=='number'and track%1==0 and track>=1 and track<=5,'Unknown specialization track.')
         tracks[track]=true
        end
       end)
      end
     end
     node.m_ChildNodes:ForEach(function(_,v)visit(v:get(),depth+1)end)
    end
    block.m_Stories:ForEach(function(_,v)local story=v:get();if valid(story)then visit(story.m_JourneyStoryRoot,0)end end)
    local selected
    for track in pairs(tracks)do assert(not selected,'House specialization is ambiguous.');selected=track end
    assert(selected,'House specialization is unavailable.')
    block.m_HouseNames:ForEach(function(_,v)
     local name=v:get():ToString();assert(not result[name],'Duplicate Landsraad house specialization.');result[name]=selected
    end)
   end
  end
  assert(groups==5,'Landsraad voting blocks are not loaded.')
  local count=0;for _ in pairs(result)do count=count+1 end
  assert(count==25,'Incomplete Landsraad house specializations.')
  mapping=result -- Cache only strings and numbers, never game object wrappers.
 end
 return assert(mapping[house],'Unknown house specialization.')
end
function M.read(pc,track)
 signature('CharacterSpecializationComponent','GetTrackProgression',{'EnumProperty TrackType','StructProperty ReturnValue'})
 local c=pc.m_CharacterSpecializationComponent;assert(valid(c),'Specialization component unavailable.')
 local p=c:GetTrackProgression(track)
 local xp,level=p.m_XPAmount,p.m_Level
 assert(type(xp)=='number'and xp%1==0 and xp>=0 and xp<=2147483647,'Invalid specialization XP.')
 assert(type(level)=='number'and level==level and level>=0 and level<=100,'Invalid specialization level.')
 assert(p.m_TrackType==track or(p.m_TrackType==0 and xp==0 and level==0),'Specialization track mismatch.')
 return xp,level
end
function M.checkGrant()
 signature('DuneCheatManager','AddXPToSpecializationTrack',{'EnumProperty Track','IntProperty XPAmount'})
end
return M

