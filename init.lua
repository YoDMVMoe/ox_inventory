local function addDeferral(message)
    message = message:gsub('%^%d', '')

    AddEventHandler('playerConnecting', function(_, _, deferrals)
        deferrals.defer()
        deferrals.done(message)
    end)
end

shared = {
    resource = GetCurrentResourceName(),

    -- Temporary internal constant.
    -- Dynamic framework selection has been removed.
    -- This property will disappear when client.lua is rewritten.
    framework = 'vorp',

    playerslots = GetConvarInt('inventory:slots', 50),
    playerweight = GetConvarInt('inventory:weight', 35000),

    police = json.decode(
        GetConvar('inventory:police', '["police", "sheriff"]')
    ) or {},

    -- Disabled until native RedM implementations are added.
    target = false,
    networkdumpsters = false,
    dropslots = 0,
    dropweight = 0,
}

do
    if type(shared.police) == 'string' then
        shared.police = {
            shared.police,
        }
    end

    local groups = table.create(
        0,
        #shared.police
    )

    for index = 1, #shared.police do
        groups[shared.police[index]] = 0
    end

    shared.police = groups
end

if IsDuplicityVersion() then
    server = {
        loghookrejection = GetConvarBool(
            'inventory:loghookrejection',
            true
        ),

        bulkstashsave = GetConvarBool(
            'inventory:bulkstashsave',
            true
        ),

        loglevel = GetConvarInt(
            'inventory:loglevel',
            1
        ),

        evidencegrade = GetConvarInt(
            'inventory:evidencegrade',
            2
        ),

        -- Disabled FiveM systems.
        randomprices = false,
        randomloot = false,
        trimplate = false,
        vehicleloot = {},
        dumpsterloot = {},

        validhosts = json.decode(
            GetConvar('inventory:validhosts', '{}')
        ) or {},

        accounts = {},
    }
else
    PlayerData = {}

    client = {
        player = lib.player:new(-1),

        imagepath = GetConvar(
            'inventory:imagepath',
            'nui://ox_inventory/web/images'
        ),

        itemnotify = GetConvarBool(
            'inventory:itemnotify',
            true
        ),

        disablesetupnotification = GetConvarBool(
            'inventory:disablesetupnotification',
            false
        ),

        -- RedM raw key input is handled directly in client.lua.
        keys = {
            'K',
        },

        -- Disabled until native RedM implementations are written.
        screenblur = false,
        autoreload = false,
        aimedfiring = false,
        giveplayerlist = false,
        weaponanims = false,
        weaponnotify = false,
        dropprops = false,
        dropmodel = 0,
        weaponmismatch = false,
        suppresspickups = false,
        disableweapons = true,
        enablestealcommand = false,
        enablekeys = {},
        ignoreweapons = {},

        shopmarker = false,
        evidencemarker = false,
        craftingmarker = false,
        dropmarker = false,
    }
end

function shared.print(...)
    print(string.strjoin(' ', ...))
end

function shared.info(...)
    lib.print.info(string.strjoin(' ', ...))
end

---@param variable string
---@param expected string
---@param received string
function TypeError(variable, expected, received)
    error(
        ("expected %s to have type '%s' (received %s)")
            :format(
                variable,
                expected,
                received
            )
    )
end

local function spamError(message)
    shared.ready = false

    CreateThread(function()
        while true do
            Wait(10000)

            CreateThread(function()
                error(message, 0)
            end)
        end
    end)

    addDeferral(message)
    error(message, 0)
end

---@param name string
---@return table
function data(name)
    local fileName = ('data/%s.lua'):format(name)
    local contents = LoadResourceFile(
        shared.resource,
        fileName
    )

    if not contents then
        warn(
            ('No data file found at %s')
                :format(fileName)
        )

        return {}
    end

    local chunk, loadError = load(
        contents,
        ('@@%s/%s'):format(
            shared.resource,
            fileName
        )
    )

    if not chunk then
        return spamError(loadError)
    end

    return chunk()
end

if not lib then
    return spamError(
        'ox_inventory requires ox_lib.'
    )
end

local success, dependencyError =
    lib.checkDependency(
        'oxmysql',
        '2.7.3'
    )

if success then
    success, dependencyError =
        lib.checkDependency(
            'ox_lib',
            '3.36.4'
        )
end

if not success then
    return spamError(dependencyError)
end

if not LoadResourceFile(
    shared.resource,
    'web/build/index.html'
) then
    return spamError(
        'The ox_inventory NUI build is missing.'
    )
end

if lib.context == 'server' then
    shared.ready = false
    return require 'server'
end

require 'client'
