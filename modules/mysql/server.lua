if not lib then return end

local Query = {
    SELECT_PLAYER = [[
        SELECT `inventory`
        FROM `characters`
        WHERE `charidentifier` = ?
        LIMIT 1
    ]],

    UPDATE_PLAYER = [[
        UPDATE `characters`
        SET `inventory` = ?
        WHERE `charidentifier` = ?
    ]],

    SELECT_STASH = [[
        SELECT `data`
        FROM `ox_inventory`
        WHERE `owner` = ?
          AND `name` = ?
        LIMIT 1
    ]],

    UPDATE_STASH = [[
        UPDATE `ox_inventory`
        SET `data` = ?
        WHERE `owner` = ?
          AND `name` = ?
    ]],

    UPSERT_STASH = [[
        INSERT INTO `ox_inventory`
            (`data`, `owner`, `name`)
        VALUES
            (?, ?, ?)
        ON DUPLICATE KEY UPDATE
            `data` = VALUES(`data`)
    ]],

    INSERT_STASH = [[
        INSERT INTO `ox_inventory`
            (`owner`, `name`)
        VALUES
            (?, ?)
    ]],
}

Citizen.CreateThreadNow(function()
    Wait(0)

    local tableExists = MySQL.scalar.await([[
        SELECT COUNT(*)
        FROM information_schema.TABLES
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'characters'
    ]])

    if tonumber(tableExists) ~= 1 then
        error(
            'ox_inventory VORP bridge could not find the characters table.',
            0
        )
    end

    local charIdentifierExists = MySQL.scalar.await([[
        SELECT COUNT(*)
        FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'characters'
          AND COLUMN_NAME = 'charidentifier'
    ]])

    if tonumber(charIdentifierExists) ~= 1 then
        error(
            'ox_inventory VORP bridge could not find characters.charidentifier.',
            0
        )
    end

    local inventoryColumnExists = MySQL.scalar.await([[
        SELECT COUNT(*)
        FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'characters'
          AND COLUMN_NAME = 'inventory'
    ]])

    if tonumber(inventoryColumnExists) ~= 1 then
        MySQL.query.await([[
            ALTER TABLE `characters`
            ADD COLUMN `inventory` LONGTEXT NULL
        ]])
    end

    local stashTableExists = MySQL.scalar.await([[
        SELECT COUNT(*)
        FROM information_schema.TABLES
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'ox_inventory'
    ]])

    if tonumber(stashTableExists) ~= 1 then
        MySQL.query.await([[
            CREATE TABLE `ox_inventory` (
                `owner` varchar(60) DEFAULT NULL,
                `name` varchar(100) NOT NULL,
                `data` longtext DEFAULT NULL,
                `lastupdated` timestamp NULL
                    DEFAULT current_timestamp()
                    ON UPDATE current_timestamp(),
                UNIQUE KEY `owner_name` (`owner`, `name`)
            )
            ENGINE=InnoDB
            DEFAULT CHARSET=utf8mb4
            COLLATE=utf8mb4_general_ci
        ]])
    end

    -- Do not overwrite valid existing inventory data.
    -- Only normalize NULL and empty values.
    MySQL.update.await([[
        UPDATE `characters`
        SET `inventory` = '[]'
        WHERE `inventory` IS NULL
           OR TRIM(`inventory`) = ''
    ]])

    local clearStashes = GetConvar(
        'inventory:clearstashes',
        '6 MONTH'
    )

    if clearStashes ~= '' then
        pcall(
            MySQL.query.await,
            ('DELETE FROM `ox_inventory` WHERE `lastupdated` < (NOW() - INTERVAL %s)')
                :format(clearStashes)
        )
    end

    shared.info(
        'VORP database adapter initialized with characters.charidentifier'
    )
end)

db = {}

---@param identifier string | number
---@return table
function db.loadPlayer(identifier)
    local inventoryJson = MySQL.prepare.await(
        Query.SELECT_PLAYER,
        { identifier }
    )

    if not inventoryJson or inventoryJson == '' then
        return {}
    end

    local success, inventory = pcall(
        json.decode,
        inventoryJson
    )

    if not success or type(inventory) ~= 'table' then
        warn(
            ('Character %s has invalid JSON in characters.inventory; loading an empty inventory.')
                :format(identifier)
        )

        return {}
    end

    return inventory
end

---@param owner string | number
---@param inventory string
function db.savePlayer(owner, inventory)
    return MySQL.prepare.await(
        Query.UPDATE_PLAYER,
        {
            inventory,
            owner,
        }
    )
end

---@param owner string | number | nil
---@param dbId string
---@param inventory string
function db.saveStash(owner, dbId, inventory)
    return MySQL.prepare.await(
        Query.UPSERT_STASH,
        {
            inventory,
            owner and tostring(owner) or '',
            dbId,
        }
    )
end

---@param owner string | number | nil
---@param name string
function db.loadStash(owner, name)
    return MySQL.prepare.await(
        Query.SELECT_STASH,
        {
            owner and tostring(owner) or '',
            name,
        }
    )
end

-- GTA gloveboxes are intentionally unsupported.
function db.saveGlovebox(_id, _inventory)
    return false
end

function db.loadGlovebox(_id)
    return nil
end

-- GTA trunks are intentionally unsupported.
function db.saveTrunk(_id, _inventory)
    return false
end

function db.loadTrunk(_id)
    return nil
end

---@param rows number | MySQLQuery | MySQLQuery[]
---@return number
local function countRows(rows)
    if type(rows) == 'number' then
        return rows
    end

    if type(rows) ~= 'table' then
        return 0
    end

    local count = 0

    for i = 1, #rows do
        if rows[i] == 1 then
            count += 1
        end
    end

    return count
end

local function safeQuery(...)
    local success, response = pcall(...)

    if not success then
        warn(response)
        return
    end

    return response
end

---@param players InventorySaveData[]
---@param trunks InventorySaveData[]
---@param gloveboxes InventorySaveData[]
---@param stashes (InventorySaveData | string | number)[]
---@param total number[]
function db.saveInventories(
    players,
    trunks,
    gloveboxes,
    stashes,
    total
)
    local startTime = os.nanotime()
    local pending = 0

    local saveMessage = 'Saved %d/%d %s (%.4f ms)'

    shared.info(
        ('Saving %s inventories to the database')
            :format(total[5])
    )

    if total[1] > 0 then
        pending += 1

        Citizen.CreateThreadNow(function()
            local response = safeQuery(
                MySQL.prepare.await,
                Query.UPDATE_PLAYER,
                players
            )

            pending -= 1

            if response then
                shared.info(
                    saveMessage:format(
                        countRows(response),
                        total[1],
                        'players',
                        (os.nanotime() - startTime) / 1e6
                    )
                )
            end
        end)
    end

    -- These should remain zero during the bootstrap phase.
    if total[2] > 0 then
        warn(
            ('Skipped %s GTA trunk inventories; RedM wagon storage is not implemented yet.')
                :format(total[2])
        )
    end

    if total[3] > 0 then
        warn(
            ('Skipped %s GTA glovebox inventories; RedM wagon storage is not implemented yet.')
                :format(total[3])
        )
    end

    if total[4] > 0 then
        pending += 1

        if server.bulkstashsave then
            local stashCount = total[4] / 3

            Citizen.CreateThreadNow(function()
                local query = Query.UPSERT_STASH:gsub(
                    '%(%?, %?, %?%)',
                    string.rep(
                        '(?, ?, ?)',
                        stashCount,
                        ', '
                    )
                )

                local response = safeQuery(
                    MySQL.query.await,
                    query,
                    stashes
                )

                pending -= 1

                if response then
                    local affectedRows =
                        tonumber(response.affectedRows) or 0

                    if stashCount == 1 then
                        if affectedRows == 2 then
                            affectedRows = 1
                        end
                    elseif response.info then
                        affectedRows -= tonumber(
                            response.info:match(
                                'Duplicates: (%d+)'
                            ),
                            10
                        ) or 0
                    end

                    shared.info(
                        saveMessage:format(
                            affectedRows,
                            stashCount,
                            'stashes',
                            (os.nanotime() - startTime) / 1e6
                        )
                    )
                end
            end)
        else
            Citizen.CreateThreadNow(function()
                local response = safeQuery(
                    MySQL.rawExecute.await,
                    Query.UPSERT_STASH,
                    stashes
                )

                pending -= 1

                if response then
                    local affectedRows = 0

                    if table.type(response) == 'hash' then
                        if response.affectedRows > 0 then
                            affectedRows = 1
                        end
                    else
                        for i = 1, #response do
                            if response[i].affectedRows > 0 then
                                affectedRows += 1
                            end
                        end
                    end

                    shared.info(
                        saveMessage:format(
                            affectedRows,
                            total[4],
                            'stashes',
                            (os.nanotime() - startTime) / 1e6
                        )
                    )
                end
            end)
        end
    end

    repeat
        Wait(0)
    until pending == 0
end

return db
