local file = ...
local house = {id='DA_HouseAlexin'}
local function name(value) return {ToString=function() return value end} end
FName = name
local function forEach(rows)
    return {ForEach=function(_, callback)
        for i, row in ipairs(rows) do callback(i, {get=function() return row end}) end
    end}
end
local function setup(mode)
    local row = {m_HouseName=name(house.id), m_ItemTemplateId={Name=name('SolarisCoin')}, m_Amount=10000}
    local component = {m_HouseRewards=forEach({row})}
    local balance, sent, response = 0, 0, nil
    local tasks, notify = {}, nil
    local pc = {GetAddress=function() return 1 end, m_LandsraadCharacterComponent=component}
    local pawn = {GetAddress=function() return 2 end, GetNumberOfItemsInInventory=function() return balance end}
    local function valid(object) object.IsValid=function() return true end; return object end
    local app = {}
    function app:session() return {ok=true, controller=pc, pawn=pawn} end
    function app:find(value) return value end
    function app:notify(_, callback)
        notify = callback
        return {cancel=function() notify=nil end}
    end
    function app:defer(ms, callback)
        if ms < 8000 then tasks[#tasks+1]=callback end
    end
    StaticConstructObject = function(class) return valid({class=class}) end
    FindAllOf = function() return {response} end
    pc.m_ActionHandler = valid({ServerPerformAction=function(_, payload)
        local action = payload.m_ActionMessage
        if action.class:find('GetHouseReward', 1, true) then
            local offered = mode == 'mismatch' and {m_HouseName=name(house.id),
                m_ItemTemplateId=row.m_ItemTemplateId, m_Amount=1} or row
            response = valid({GetAddress=function() return 3 end, m_Rewards=forEach({offered})})
            notify(response)
        else
            sent = sent + 1
            assert(action.m_RewardsToRedeem == response.m_Rewards)
            component.m_HouseRewards = forEach({})
            if mode ~= 'no_inventory' then balance = 10000 end
        end
    end})
    local reward = dofile(file).new(app,{read=function() return {claimed={}} end})
    assert(reward:read(house).canClaim)
    assert(reward:claim(house) == 'reward.processing')
    assert(reward:claim(house) == 'reward.unconfirmed')
    while #tasks > 0 do
        table.remove(tasks,1)()
        if mode == 'no_inventory' and sent == 1 and #tasks > 0 then
            assert(reward:read(house).message == 'reward.processing')
            return
        end
    end
    assert(sent == (mode == 'mismatch' and 0 or 1))
    if mode == 'success' then
        assert(reward:read(house).message == 'reward.confirmed')
        assert(not reward:read(house).canClaim)
    end
end
for _, mode in ipairs({'success','mismatch','no_inventory'}) do setup(mode) end

