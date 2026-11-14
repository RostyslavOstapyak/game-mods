local M = {}

function M.new(app)
    local self = {}

    function self:read(house)
        local ok, state = pcall(function()
            local session = app:session()
            if not session.ok then return nil end
            local component = session.controller.m_LandsraadCharacterComponent
            if not component:IsValid() then return nil end

            local remaining, received, occurrences = {}, {}, {}
            component.m_HouseRewards:ForEach(function(_, value)
                local row = value:get()
                if row.m_HouseName:ToString() == house.id then
                    local template = row.m_ItemTemplateId.Name:ToString()
                    remaining[template] = (remaining[template] or 0) + row.m_Amount
                end
            end)
            component.m_ReceivedHouseRewards:ForEach(function(_, value)
                local row = value:get()
                if row.m_HouseName:ToString() == house.id then
                    received[row.m_ItemTemplateId.Name:ToString()] = true
                end
            end)
            for _, reward in ipairs(house.rewards) do
                occurrences[reward.template] = (occurrences[reward.template] or 0) + 1
            end

            local claimed = {}
            for index, reward in ipairs(house.rewards) do
                local template = reward.template
                claimed[index] = house.personal ~= nil and house.personal >= reward.threshold
                    and occurrences[template] == 1 and received[template] == true
                    and remaining[template] == 0
            end
            return {claimed = claimed, canClaim = false}
        end)
        return ok and state or nil
    end

    return self
end

return M
