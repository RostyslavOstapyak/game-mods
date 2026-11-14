import pathlib,sys
from lupa.lua54 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
lua.globals().source=str(pathlib.Path('Scripts/house_data.lua')).replace('\\','/')
lua.execute('''
local function text(s)return{ToString=function()return s end}end
local function array(values)
 return{ForEach=function(_,callback)
  for i,value in ipairs(values)do callback(i,{get=function()return value end})end
 end}
end
local function faction(s)return{Name=text(s)}end
local function map(values)
 return{ForEach=function(_,callback)
  for name,value in pairs(values)do
   callback({get=function()return faction(name)end},{get=function()return value end})
  end
 end}
end
local world={m_LandsraadReplicatedStateComponent={m_LandsraadState={m_CurrentTermId=6}}}
local pc={m_LandsraadCharacterComponent={m_CachedGuildFaction=faction('Atreides')}}
local app={session=function()return{ok=true,controller=pc,pawn={}}end}
world.m_LandsraadStateComponent={
 m_LandsraadTasks=array({{m_BoardIndex=9,m_HouseName=text('Taligari'),m_bCompleted=false,m_WinningFaction=faction('None')}}),
 m_LandsraadTaskStatePerFaction=map({Atreides={m_TaskStates=array({{m_BoardIndex=9,m_GoalAmount=4000,m_Rewards=array({})}})},Harkonnen={m_TaskStates=array({{m_BoardIndex=9,m_GoalAmount=4000,m_Rewards=array({})}})}}),
 m_LandsraadTaskProgressPerFaction=map({Atreides={m_TaskProgresses=array({{m_BoardIndex=9,m_ProgressAmount=1000}})},Harkonnen={m_TaskProgresses=array({{m_BoardIndex=9,m_ProgressAmount=0}})}})
}
function StaticFindObject()return{GetGameState=function()return world end}end
LDPersonalProgress={ready=true,fullReceivedAt=os.time(),factionValues={[9]={Atreides=2000,Harkonnen=1500}},snapshot=function()return{[9]=1200}end}
local data=dofile(source).new(app)
data.metadata.Taligari={name='Taligari',iconPath=''}
local row=data:read()[1]
assert(row.atreides==1000 and row.harkonnen==0 and row.progress==1000 and row.personal==1200)
assert(row.progressSource=='world-state'and row.atreidesGoal==4000 and row.harkonnenGoal==4000)
world.m_LandsraadStateComponent.m_LandsraadTaskProgressPerFaction=map({Atreides={m_TaskProgresses=array({{m_BoardIndex=9,m_ProgressAmount=1000}})},Harkonnen={m_TaskProgresses=array({{m_BoardIndex=9,m_ProgressAmount=1500}})}})
LDPersonalProgress.factionValues={[9]={Atreides=1000,Harkonnen=0}}
row=data:read()[1]
assert(row.harkonnen==1500,'Incomplete personal response must not erase simulated enemy progress')
LDPersonalProgress.fullReceivedAt=os.time()-10
row=data:read()[1]
assert(row.atreides==1000 and row.harkonnen==1500 and row.progressSource=='world-state')
LDPersonalProgress.fullReceivedAt=os.time();LDPersonalProgress.factionValues=nil
row=data:read()[1]
assert(row.progress==1000 and row.progressSource=='world-state')
''')
print('PASS: world faction progress and goals retained, personal contribution independent; incomplete personal response cannot erase enemy progress.')
