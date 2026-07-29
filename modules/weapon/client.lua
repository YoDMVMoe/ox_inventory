if not lib then
    return
end

local Weapon = {}

-- RDR3 weapon support is intentionally unavailable until the native
-- RedM weapon module is implemented.

function Weapon.Equip()
    return nil
end

function Weapon.Disarm()
    return nil
end

function Weapon.ClearAll()
    return nil
end

return Weapon
