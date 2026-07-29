if not lib then
    return
end

local Utils = {}

-- RedM item animations will be implemented using verified RDR3
-- dictionaries and native signatures.
function Utils.PlayAnim()
    return false
end

function Utils.PlayAnimAdvanced()
    return false
end

-- Entity targeting is not implemented during the personal-inventory phase.
function Utils.Raycast()
    return false
end

---@return number?
---@return number?
function Utils.GetClosestPlayer()
    local activePlayers = GetActivePlayers()
    local localPed = cache.ped
    local localCoords = GetEntityCoords(localPed)

    local closestPlayer
    local closestPed
    local closestDistance = 2.0

    for index = 1, #activePlayers do
        local playerId = activePlayers[index]

        if playerId ~= cache.playerId then
            local ped = GetPlayerPed(playerId)

            if ped ~= 0 then
                local distance =
                    #(localCoords - GetEntityCoords(ped))

                if distance < closestDistance then
                    closestDistance = distance
                    closestPlayer = playerId
                    closestPed = ped
                end
            end
        end
    end

    return closestPlayer, closestPed
end

---@param notification table
function Utils.Notify(notification)
    notification.description = notification.text
        or notification.description

    notification.text = nil

    lib.notify(notification)
end

RegisterNetEvent(
    'ox_inventory:notify',
    Utils.Notify
)

exports(
    'notify',
    Utils.Notify
)

local notificationsSuppressed = false

---@param state boolean
local function setNotificationsSuppressed(state)
    notificationsSuppressed = state == true
end

RegisterNetEvent(
    'ox_inventory:suppressItemNotifications',
    setNotificationsSuppressed
)

exports(
    'suppressItemNotifications',
    setNotificationsSuppressed
)

---@param notificationData table
function Utils.ItemNotify(notificationData)
    if notificationsSuppressed then
        return
    end

    if not client.itemnotify then
        return
    end

    SendNUIMessage({
        action = 'itemNotify',
        data = notificationData,
    })
end

RegisterNetEvent(
    'ox_inventory:itemNotify',
    Utils.ItemNotify
)

---@param entity number
function Utils.DeleteEntity(entity)
    if not entity or entity == 0 then
        return
    end

    if DoesEntityExist(entity) then
        SetEntityAsMissionEntity(
            entity,
            false,
            true
        )

        DeleteEntity(entity)
    end
end

Utils.DeleteObject = Utils.DeleteEntity

-- ox_inventory does not control the RDR3 weapon wheel yet.
function Utils.WeaponWheel()
    EnableWeaponWheel = true
end

exports('weaponWheel', function()
    Utils.WeaponWheel()
end)

-- RedM blips will be implemented separately.
function Utils.CreateBlip()
    return nil
end

-- ox_target zones are not part of this RedM-only fork.
function Utils.CreateBoxZone()
    return nil
end

-- World interaction prompts are not implemented yet.
function Utils.nearbyMarker()
end

-- GTA screen-blur natives are not used.
function Utils.blurIn()
end

function Utils.blurOut()
end

---@param serverId number
---@return string
local function defaultGetPlayerName(serverId)
    local playerId =
        GetPlayerFromServerId(serverId)

    local playerName =
        playerId ~= -1
        and GetPlayerName(playerId)
        or 'Unknown'

    return ('[%s] %s'):format(
        serverId,
        playerName
    )
end

local getPlayerName = defaultGetPlayerName

exports('setGetPlayerNameMethod', function(callback)
    if type(callback) == 'function' then
        getPlayerName = callback
        return
    end

    getPlayerName = defaultGetPlayerName
end)

---@param serverId number
---@return string
function Utils.getPlayerName(serverId)
    return getPlayerName(serverId)
end

return Utils
