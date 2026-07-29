if not lib then
    return
end

---@param inventory table
---@param requiredGroup string | table<string, number | number[]>
---@return string?
---@return number?
function server.hasGroup(inventory, requiredGroup)
    local player = inventory and inventory.player

    if not player then
        return
    end

    local playerGroups = player.groups or {}

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

---@param player table
---@return table
function server.setPlayerData(player)
    return {
        source = player.source,
        name = player.name,
        groups = player.groups or {},
        sex = player.sex,
        dateofbirth = player.dateofbirth,
        maxWeight = player.maxWeight,
        slots = player.slots,
    }
end

local Inventory = require 'modules.inventory.server'

---@param playerSource number
function server.playerDropped(playerSource)
    local inventory = Inventory(playerSource)

    if not inventory or not inventory.player then
        return
    end

    inventory:closeInventory()
    Inventory.Remove(inventory)
end

require 'modules.bridge.vorp.server'
