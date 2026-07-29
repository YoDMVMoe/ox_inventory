if not lib then
    return
end

local Items = require 'modules.items.client'

---@param key string
---@param value any
function client.setPlayerData(key, value)
    PlayerData[key] = value
    OnPlayerData(key, value)
end

---@param requiredGroup string | table<string, number | number[]>
---@return string?
---@return number?
function client.hasGroup(requiredGroup)
    if not PlayerData.loaded then
        return
    end

    local playerGroups = PlayerData.groups or {}

    if type(requiredGroup) == 'table' then
        for groupName, requiredGrade in pairs(requiredGroup) do
            local playerGrade = playerGroups[groupName]

            if playerGrade ~= nil then
                if type(requiredGrade) == 'table' then
                    if lib.table.contains(
                        requiredGrade,
                        playerGrade
                    ) then
                        return groupName, playerGrade
                    end
                elseif playerGrade >= (requiredGrade or 0) then
                    return groupName, playerGrade
                end
            end
        end

        return
    end

    local playerGrade = playerGroups[requiredGroup]

    if playerGrade ~= nil then
        return requiredGroup, playerGrade
    end
end

function client.onLogout()
    if not PlayerData.loaded then
        return
    end

    for _, item in pairs(Items) do
        item.count = 0
    end

    PlayerData.loaded = false
    PlayerData.inventory = {}
    PlayerData.weight = 0

    client.drops = {}

    if client.closeInventory then
        client.closeInventory()
    end

    if client.interval then
        ClearInterval(client.interval)
        client.interval = nil
    end

    if client.tick then
        ClearInterval(client.tick)
        client.tick = nil
    end
end

require 'modules.bridge.vorp.client'
