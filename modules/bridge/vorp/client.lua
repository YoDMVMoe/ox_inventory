---@diagnostic disable-next-line: duplicate-set-field
function client.setPlayerStatus(values)
    if type(values) ~= 'table' then return end

    for statusName, value in pairs(values) do
        value = tonumber(value) or 0

        -- Many existing ox items use ESX-style values such as 200000.
        -- VORP metabolism normally uses a 0-1000 range.
        if math.abs(value) > 1000 then
            value = value / 1000
        end

        TriggerEvent(
            'vorpmetabolism:changeValue',
            statusName,
            value
        )
    end
end

RegisterNetEvent('ox_inventory:vorp:updateGroups', function(groups)
    if not PlayerData.loaded then return end

    client.setPlayerData('groups', groups or {})
end)

AddEventHandler('vorp_core:Client:OnPlayerDeath', function()
    if not PlayerData.loaded then return end

    client.setPlayerData('dead', true)
end)

RegisterNetEvent('vorp_core:Client:OnPlayerRevive', function()
    if not PlayerData.loaded then return end

    client.setPlayerData('dead', false)
end)

RegisterNetEvent('vorp_core:Client:OnPlayerRespawn', function()
    if not PlayerData.loaded then return end

    client.setPlayerData('dead', false)
end)
