local Inventory = require 'modules.inventory.server'

local VORPCore = exports.vorp_core:GetCore()

---@param source number
---@return table?
local function getCharacter(source)
    source = tonumber(source)

    if not source then return end

    local user = VORPCore.getUser(source)

    if not user then return end

    local character = user.getUsedCharacter

    if type(character) ~= 'table' then return end
    if not character.charIdentifier then return end

    return character
end

---@param character table
---@return table<string, number>
local function buildGroups(character)
    local groups = {}

    if type(character.job) == 'string' and character.job ~= '' then
        groups[character.job] = tonumber(character.jobGrade) or 0
    end

    if type(character.group) == 'string' and character.group ~= '' then
        groups[character.group] = 0
    end

    if type(character.multiJobs) == 'table' then
        for jobName, jobData in pairs(character.multiJobs) do
            if type(jobName) == 'string' then
                local grade = 0

                if type(jobData) == 'table' then
                    grade = tonumber(jobData.grade) or 0
                end

                groups[jobName] = grade
            end
        end
    end

    return groups
end

---@param source number
---@param character table
---@return table
local function buildOxPlayer(source, character)
    local firstName = tostring(character.firstname or '')
    local lastName = tostring(character.lastname or '')
    local fullName = ('%s %s'):format(firstName, lastName)
        :gsub('^%s*(.-)%s*$', '%1')

    if fullName == '' then
        fullName = GetPlayerName(source) or ('Player %s'):format(source)
    end

    -- VORP stores invCapacity as kilograms.
    -- ox_inventory expects maxWeight in grams.
    local capacityKg = tonumber(character.invCapacity) or 35
    local maxWeight = math.floor(capacityKg * 1000 + 0.5)

    return {
        source = source,

        -- The selected VORP character is the inventory owner.
        -- Do not use the Steam identifier because one Steam account can have
        -- multiple VORP characters.
        identifier = tostring(character.charIdentifier),

        name = fullName,
        groups = buildGroups(character),
        sex = character.gender,
        dateofbirth = character.age and tostring(character.age) or nil,

        slots = shared.playerslots,
        maxWeight = maxWeight,
    }
end

---@param source number
---@param character table
local function loadCharacterInventory(source, character)
    source = tonumber(source)

    if not source or source <= 0 then return end
    if type(character) ~= 'table' then return end
    if not character.charIdentifier then return end

    local existingInventory = Inventory(source)

    if existingInventory then
        server.playerDropped(source)
    end

    server.setPlayerInventory(buildOxPlayer(source, character))
end

-- This event is fired by your supplied VORP Core after a character is selected.
AddEventHandler('vorp:SelectedCharacter', function(playerSource, character)
    playerSource = tonumber(playerSource)

    if not playerSource or playerSource <= 0 then return end

    if type(character) ~= 'table' then
        character = getCharacter(playerSource)
    end

    if not character then
        return warn(
            ('Unable to initialize ox_inventory for source %s: selected VORP character was unavailable.')
                :format(playerSource)
        )
    end

    loadCharacterInventory(playerSource, character)
end)

-- Save and remove the in-memory ox inventory when the player disconnects.
AddEventHandler('playerDropped', function()
    server.playerDropped(source)
end)

---@param playerSource number
local function updatePlayerGroups(playerSource)
    playerSource = tonumber(playerSource)

    if not playerSource then return end

    local inventory = Inventory(playerSource)
    local character = getCharacter(playerSource)

    if not inventory or not character then return end

    local groups = buildGroups(character)

    inventory.player.groups = groups

    TriggerClientEvent(
        'ox_inventory:vorp:updateGroups',
        playerSource,
        groups
    )
end

AddEventHandler('vorp:playerJobChange', function(playerSource)
    updatePlayerGroups(playerSource)
end)

AddEventHandler('vorp:playerJobGradeChange', function(playerSource)
    updatePlayerGroups(playerSource)
end)

AddEventHandler('vorp:playerGroupChange', function(playerSource)
    updatePlayerGroups(playerSource)
end)

-- Handles restarting ox_inventory while players are already connected.
SetTimeout(1500, function()
    local users = VORPCore.getUsers()

    if type(users) ~= 'table' then return end

    for _, userObject in pairs(users) do
        local user

        if type(userObject) == 'table'
            and type(userObject.GetUser) == 'function'
        then
            user = userObject.GetUser()
        end

        if type(user) == 'table'
            and user.source
            and type(user.getUsedCharacter) == 'table'
            and user.getUsedCharacter.charIdentifier
        then
            loadCharacterInventory(
                tonumber(user.source),
                user.getUsedCharacter
            )
        end
    end
end)

---@diagnostic disable-next-line: duplicate-set-field
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

---@diagnostic disable-next-line: duplicate-set-field
function server.syncInventory(_inventory)
    -- ox_inventory persists the item slots.
    -- vorp_core continues to own money, gold, role tokens, jobs,
    -- identity, health, stamina, and other character state.
end

---@diagnostic disable-next-line: duplicate-set-field
function server.UseItem(_source, _itemName, _itemData)
    -- Usable item behavior will be added after basic inventory movement
    -- and persistence are functioning.
    return false
end

---@diagnostic disable-next-line: duplicate-set-field
function server.hasLicense(_inventory, _licenseName)
    -- GTA/ESX licenses are not used by this VORP port.
    return false
end

---@diagnostic disable-next-line: duplicate-set-field
function server.buyLicense()
    return false, 'license_not_supported'
end

---@diagnostic disable-next-line: duplicate-set-field
function server.isPlayerBoss(playerId, requiredGroup, requiredGrade)
    local character = getCharacter(playerId)

    if not character then return false end

    if requiredGroup
        and character.job ~= requiredGroup
        and character.group ~= requiredGroup
    then
        return false
    end

    return (tonumber(character.jobGrade) or 0)
        >= (tonumber(requiredGrade) or 0)
end

-- Temporary Phase 2 test command.
-- This command can only be executed from the server console.
--
-- Usage:
-- oxvtest <serverId> <itemName> [count]
RegisterCommand('oxvtest', function(commandSource, args)
    if commandSource ~= 0 then
        return
    end

    local target = tonumber(args[1])
    local itemName = tostring(args[2] or ''):lower()
    local count = math.floor(tonumber(args[3]) or 1)

    if not target or target <= 0 or itemName == '' then
        print('Usage: oxvtest <serverId> <itemName> [count]')
        return
    end

    if count <= 0 then
        print('oxvtest: count must be at least 1.')
        return
    end

    local targetInventory = Inventory(target)

    if not targetInventory then
        print(
            ('oxvtest: source %s has not selected a VORP character.')
                :format(target)
        )

        return
    end

    local success, response = Inventory.AddItem(
        target,
        itemName,
        count
    )

    if not success then
        print(
            ('oxvtest: failed to add %sx %s to source %s: %s')
                :format(
                    count,
                    itemName,
                    target,
                    tostring(response)
                )
        )

        return
    end

    print(
        ('oxvtest: added %sx %s to source %s.')
            :format(count, itemName, target)
    )
end, false)
