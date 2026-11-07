-- Extreme Angler: fishing pole swap, lure application and reminders.
local ADDON, ns = ...
local Gear = {}
ns.Gear = Gear

local SLOT_MH, SLOT_OH = 16, 17
local POLE_SLOTS = { 16, 28 } -- main hand; profession tool slot on some clients

local CLASS_WEAPON = (Enum and Enum.ItemClass and Enum.ItemClass.Weapon) or 2
local SUBCLASS_POLE = (Enum and Enum.ItemWeaponSubclass and Enum.ItemWeaponSubclass.Fishingpole) or 20

-- Lures, strongest first
local LURES = { 68049, 118391, 6533, 34861, 46006, 62673, 7307, 6532, 6811, 6530, 6529 }

local GetItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
local GetItemCount = (C_Item and C_Item.GetItemCount) or GetItemCount
local IsUsableItem = (C_Item and C_Item.IsUsableItem) or IsUsableItem
local EquipItemByName = (C_Item and C_Item.EquipItemByName) or EquipItemByName
local GetContainerNumSlots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
local GetContainerItemID = (C_Container and C_Container.GetContainerItemID) or GetContainerItemID

local lureTries = 0
local lastLureTry = 0
local lastEquipTry = 0

local function IsPole(itemID)
    if not itemID then return false end
    local _, _, _, _, _, classID, subClassID = GetItemInfoInstant(itemID)
    return classID == CLASS_WEAPON and subClassID == SUBCLASS_POLE
end

function Gear.EquippedPoleSlot()
    for _, slot in ipairs(POLE_SLOTS) do
        if IsPole(GetInventoryItemID("player", slot)) then return slot end
    end
end

function Gear.FindPoleInBags()
    for bag = 0, 5 do
        for slot = 1, (GetContainerNumSlots(bag) or 0) do
            local id = GetContainerItemID(bag, slot)
            if IsPole(id) then return id end
        end
    end
end

function Gear.HasLure(slot)
    if slot ~= SLOT_MH then return true end -- can't check lures on other slots
    local hasMH = GetWeaponEnchantInfo()
    return hasMH and true or false
end

function Gear.FindLure()
    for _, id in ipairs(LURES) do
        if (GetItemCount(id) or 0) > 0 and IsUsableItem(id) then return id end
    end
end

local function CastMacro()
    return "/cast " .. ns.FISHING_NAME
end

function Gear.SaveWeapons()
    if ns.db.savedGear then return end
    ns.db.savedGear = {
        mh = GetInventoryItemLink("player", SLOT_MH),
        oh = GetInventoryItemLink("player", SLOT_OH),
    }
end

function Gear.RestoreWeapons(manual)
    local saved = ns.db.savedGear
    if not saved then
        if manual then ns.Print("No saved weapons to re-equip.") end
        return
    end
    if InCombatLockdown() then
        Gear.pendingRestore = true
        return
    end
    if ns.fishing then return end
    ns.db.savedGear = nil
    if saved.mh then EquipItemByName(saved.mh, SLOT_MH) end
    if saved.oh then
        C_Timer.After(0.5, function()
            if not InCombatLockdown() then EquipItemByName(saved.oh, SLOT_OH) end
        end)
    end
    ns.Print("Your previous weapons have been re-equipped.")
end

-- Decides what the key does on this press (out of combat, every press)
function Gear.BuildMacro()
    local db = ns.db
    local now = GetTime()
    local slot = Gear.EquippedPoleSlot()

    if not slot then
        if db.poleSwap and now - lastEquipTry > 3 then
            local pole = Gear.FindPoleInBags()
            if pole then
                lastEquipTry = now
                Gear.SaveWeapons()
                ns.StartSession()
                ns.ScheduleEndSession()
                ns.Print("Equipping fishing pole. Press again to cast.")
                return "/equip item:" .. pole
            end
            ns.Warn("No fishing pole in your bags!", 10)
        end
        return CastMacro()
    end

    if Gear.HasLure(slot) then
        lureTries = 0
        return CastMacro()
    end

    -- No lure on the pole
    local lure = Gear.FindLure()
    if db.autoLure and lure and lureTries < 2 and now - lastLureTry > 6 then
        lureTries = lureTries + 1
        lastLureTry = now
        ns.Print("Applying lure. Press again to cast when it's done.")
        return "/use item:" .. lure .. "\n/use " .. slot
    end
    if db.lureWarn then
        if lure then
            ns.Warn("No lure on your pole! (you have one in your bags)", 60)
        else
            ns.Warn("You're out of lures!", 120)
        end
    end
    return CastMacro()
end

ns.Listen("SESSION_END", function()
    lureTries = 0
    Gear.RestoreWeapons()
end)

ns.On("PLAYER_REGEN_ENABLED", function()
    if Gear.pendingRestore then
        Gear.pendingRestore = nil
        C_Timer.After(1, function() Gear.RestoreWeapons() end)
    end
end)

-- If you logged out while fishing, re-equip your weapons on login
ns.Listen("LOGIN", function()
    if ns.db.savedGear then
        C_Timer.After(4, function() Gear.RestoreWeapons() end)
    end
end)
