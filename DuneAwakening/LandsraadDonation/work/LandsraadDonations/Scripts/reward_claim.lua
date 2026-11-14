local M = {}
local prefix = '/Script/DuneSandbox.'
local get = 'LandsraadActionGetHouseReward'
local reply = get .. 'Response'
local redeem = 'LandsraadActionRedeemHouseReward'

local function valid(object)
    return object and object:IsValid()
end

local function amounts(array, house, strict)
    local result = {}
    array:ForEach(function(_, item)
        local row = item:get()
        if row.m_HouseName:ToString() ~= house then
            assert(not strict, 'Reward response includes another house')
        elseif row.m_Amount > 0 then
            local id = row.m_ItemTemplateId.Name:ToString()
            result[id] = (result[id] or 0) + row.m_Amount
        end
    end)
    return result
end

local function same(a, b)
    for id, count in pairs(a) do if b[id] ~= count then return false end end
    for id, count in pairs(b) do if a[id] ~= count then return false end end
    return true
end

function M.new(app, statusReader)
    local self = {}
    local pending, blocked
    local messages = {}
    local function finish(op, status)
        if pending ~= op then return end
        if op.token then op.token:cancel() end
        pending = nil
        messages[op.house] = status
        if op.sent and status ~= 'reward.confirmed' then blocked = true end
        print('[LD_TERMINAL_REWARD] ' .. op.house .. ' ' .. status .. '\n')
    end

    local function sessionFor(op)
        local s = app:session()
        assert(s.ok and s.controller:GetAddress() == op.controller
            and s.pawn:GetAddress() == op.pawn, 'Local character changed')
        return s
    end

    local function newAction(s, class, house)
        local handler = s.controller.m_ActionHandler
        assert(valid(handler), 'Missing player action handler')
        local action = StaticConstructObject(assert(app:find(prefix .. class)), handler, 0, 64)
        assert(valid(action), 'Missing reward action')
        action.m_Instigator = s.controller
        action.m_bIsListenAction = false
        action.m_bIsRequestWithCallback = true
        action.m_HouseName = FName(house, FNAME_Find)
        assert(action.m_HouseName:ToString() == house, 'Mismatched house')
        return handler, action
    end

    local function check(op)
        if pending ~= op then return end
        local ok, done = pcall(function()
            local s = sessionFor(op)
            local remaining = amounts(s.controller.m_LandsraadCharacterComponent.m_HouseRewards, op.house)
            local complete = true
            for id, count in pairs(op.before) do
                local inventory = s.pawn:GetNumberOfItemsInInventory({Name = FName(id, FNAME_Find)})
                local left = remaining[id] or 0
                local delta = inventory - op.inventory[id]
                if left ~= 0 or delta ~= count then complete = false end
                if not op.observed[id] or op.observed[id].left ~= left or op.observed[id].delta ~= delta then
                    op.observed[id] = {left = left, delta = delta}
                    print(('[LD_TERMINAL_REWARD] %s %s remaining=%d of %d inventory_delta=%d\n')
                        :format(op.house, id, left, count, delta))
                end
            end
            return complete
        end)
        if ok and done then finish(op, 'reward.confirmed')
        elseif not ok or os.time() >= op.deadline then finish(op, 'reward.unconfirmed')
        else app:defer(250, function() check(op) end) end
    end

    local function collect(op, address)
        if pending ~= op or op.sent then return end
        local s = sessionFor(op)
        for _, response in ipairs(FindAllOf(reply) or {}) do
            if valid(response) and response:GetAddress() == address then
                local owner = response.m_Instigator
                if valid(owner) and owner:GetAddress() ~= op.controller then return end
                local source = response.m_Rewards
                local offered = amounts(source, op.house, true)
                if not same(offered, op.before) then return end
                local current = amounts(s.controller.m_LandsraadCharacterComponent.m_HouseRewards, op.house)
                assert(same(current, offered), 'Reward balance changed')
                local handler, action = newAction(s, redeem, op.house)
                action.m_RewardsToRedeem = source
                assert(same(amounts(action.m_RewardsToRedeem, op.house, true), offered), 'Reward copy changed')
                op.inventory = {}
                for id in pairs(offered) do
                    op.inventory[id] = s.pawn:GetNumberOfItemsInInventory({Name = FName(id, FNAME_Find)})
                end
                op.observed = {}
                op.sent = true
                op.deadline = os.time() + 15
                handler:ServerPerformAction({m_ActionMessage = action})
                app:defer(250, function() check(op) end)
                return
            end
        end
    end

    function self:read(house)
        local ok, state = pcall(function()
            local s = app:session()
            if not s.ok then return nil end
            local component = s.controller.m_LandsraadCharacterComponent
            local remaining = amounts(component.m_HouseRewards, house.id)
            local status = statusReader:read(house)
            return {claimed = status and status.claimed or {}, canClaim = not pending and not blocked and next(remaining) ~= nil,
                message = pending and pending.house == house.id and 'reward.processing' or messages[house.id],
                tooltip = pending and 'reward.processing' or messages[house.id] or
                    (next(remaining) and 'reward.claim_all' or 'reward.unavailable')}
        end)
        return ok and state or nil
    end

    function self:claim(house)
        if pending or blocked then return 'reward.unconfirmed' end
        local op
        local ok, issue = pcall(function()
            local s = app:session()
            assert(s.ok, 'Local singleplayer required')
            local before = amounts(s.controller.m_LandsraadCharacterComponent.m_HouseRewards, house.id)
            if not next(before) then return end
            local handler, action = newAction(s, get, house.id)
            op = {house = house.id, controller = s.controller:GetAddress(), pawn = s.pawn:GetAddress(), before = before}
            pending = op
            op.token = app:notify(prefix .. reply, function(object)
                local address = object:GetAddress()
                app:defer(1, function()
                    local collected, problem = pcall(collect, op, address)
                    if not collected then
                        print('[LD_TERMINAL_REWARD] ' .. tostring(problem) .. '\n')
                        finish(op, 'reward.unconfirmed')
                    end
                end)
            end)
            app:defer(8000, function()
                if not op.sent then finish(op, 'reward.unconfirmed') end
            end)
            handler:ServerPerformAction({m_ActionMessage = action})
        end)
        if not ok then
            print('[LD_TERMINAL_REWARD] ' .. tostring(issue) .. '\n')
            if op then finish(op, 'reward.unconfirmed') end
            return 'reward.unconfirmed'
        end
        return op and 'reward.processing' or 'reward.unavailable'
    end

    return self
end

return M

