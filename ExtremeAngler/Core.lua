-- Extreme Angler: one-key fishing (core).
-- While no bobber is out, the key casts Fishing; while the bobber is out, the same key becomes "Interact With Target".
-- You always press the key yourself; the addon never acts on its own.

local ADDON, ns = ...

-- ---------- Helpers ----------
local FISHING_IDS = { 131474, 131490, 7620, 7731, 7732, 18248, 33095, 51294, 88868, 110410, 158743 }
local FISHING_SET = {}
for _, id in ipairs(FISHING_IDS) do FISHING_SET[id] = true end

local function IsSecret(v) return issecretvalue and issecretvalue(v) end

function ns.SpellName(id)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    if GetSpellInfo then return (GetSpellInfo(id)) end
end

ns.FISHING_NAME = ns.SpellName(131474) or ns.SpellName(7620) or "Fishing"

function ns.Print(msg)
    print("|cff33ccffExtreme Angler|r: " .. msg)
end

local warnTimes = {}
function ns.Warn(msg, throttle)
    local now = GetTime()
    if warnTimes[msg] and now - warnTimes[msg] < (throttle or 3) then return end
    warnTimes[msg] = now
    ns.Print(msg)
    if UIErrorsFrame then UIErrorsFrame:AddMessage(msg, 1, 0.82, 0) end
end

-- Internal messages between modules
local callbacks = {}
function ns.Listen(name, fn)
    callbacks[name] = callbacks[name] or {}
    table.insert(callbacks[name], fn)
end
function ns.Fire(name, ...)
    local list = callbacks[name]
    if list then for _, fn in ipairs(list) do fn(...) end end
end

-- Game events
local eventFrame = CreateFrame("Frame")
local events = {}
function ns.On(event, fn)
    if not events[event] then
        events[event] = {}
        eventFrame:RegisterEvent(event)
    end
    table.insert(events[event], fn)
end
eventFrame:SetScript("OnEvent", function(_, event, ...)
    for _, fn in ipairs(events[event]) do fn(...) end
end)

-- Sleep mode: when ExtremeAngler is turned off, stop listening to everything except
-- the few events needed to start up, clean up and wake again.
local ALWAYS_ON = { ADDON_LOADED = true, PLAYER_LOGIN = true, PLAYER_LOGOUT = true, PLAYER_REGEN_ENABLED = true }
function ns.SetEventsActive(active)
    for event in pairs(events) do
        if not ALWAYS_ON[event] then
            if active then eventFrame:RegisterEvent(event) else eventFrame:UnregisterEvent(event) end
        end
    end
end

-- ---------- Settings ----------
ns.defaults = {
    enabled = true,
    key = "<",
    restoreDelay = 20,
    autoLoot = true,
    poleSwap = true,
    autoLure = true,
    lureWarn = true,
    skillNotify = true,
    showPanel = true,
    panelOnlyFishing = false,
    showTimer = true,
    locked = true,
    collapsed = false,
    notifyNew = true,
    notifyRare = true,
    notifySummary = true,
    notifySound = true,
    notifySoundName = "smart",
    bites = {},
    sound = {
        enabled = true,
        master = true,
        maxSFX = true,
        muteMusic = true,
        muteAmbience = true,
        muteDialog = false,
    },
    stats = { casts = 0, catches = 0, items = {}, zones = {}, names = {} },
}

local function CopyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

-- ---------- Key binding ----------
local bindOwner = CreateFrame("Frame")
local pendingBind = nil
ns.mode = "cast"

local btn = CreateFrame("Button", "ExtremeAnglerCastButton", UIParent, "SecureActionButtonTemplate")
btn:RegisterForClicks("AnyUp", "AnyDown")
btn:SetAttribute("type", "macro")
btn:SetAttribute("macrotext", "/cast " .. ns.FISHING_NAME)
btn:SetScript("PreClick", function(self, _, down)
    if InCombatLockdown() or not ns.db then return end
    -- The key fires on both press and release; only prepare on the one that actually executes
    if (down and true or false) ~= (GetCVarBool("ActionButtonUseKeyDown") and true or false) then return end
    self:SetAttribute("macrotext", ns.Gear.BuildMacro())
end)

function ns.ApplyBinding(mode)
    mode = mode or ns.mode
    ns.mode = mode
    if InCombatLockdown() then pendingBind = mode; return end
    pendingBind = nil
    ClearOverrideBindings(bindOwner)
    if not ns.db.enabled or not ns.db.key or ns.db.key == "" then return end
    if mode == "interact" then
        SetOverrideBinding(bindOwner, true, ns.db.key, "INTERACTTARGET")
    else
        SetOverrideBindingClick(bindOwner, true, ns.db.key, "ExtremeAnglerCastButton")
    end
end

function ns.SetEnabled(enabled)
    ns.db.enabled = enabled and true or false
    if not ns.db.enabled then ns.EndSession() end
    ns.SetEventsActive(ns.db.enabled)
    ns.ApplyBinding("cast")
    ns.Fire("OPTIONS")
end

function ns.SetKey(key)
    ns.db.key = key
    ns.ApplyBinding()
    ns.Print("Fishing key: |cffffff00" .. key .. "|r")
    ns.Fire("OPTIONS")
end

-- ---------- Fishing session (sound, soft interact, auto loot) ----------
ns.sessionActive = false
local restoreTimer = nil

local function BuildSessionCVars()
    local db = ns.db
    local t = { SoftTargetInteract = "3" }
    if db.autoLoot then t.autoLootDefault = "1" end
    local s = db.sound
    if s.enabled then
        if s.master then t.Sound_EnableAllSound = "1"; t.Sound_MasterVolume = "1" end
        if s.maxSFX then t.Sound_EnableSFX = "1"; t.Sound_SFXVolume = "1" end
        if s.muteMusic then t.Sound_MusicVolume = "0" end
        if s.muteAmbience then t.Sound_AmbienceVolume = "0" end
        if s.muteDialog then t.Sound_DialogVolume = "0" end
    end
    return t
end

local function RestoreCVars()
    local saved = ns.db.savedCVars
    if saved then
        for cvar, old in pairs(saved) do SetCVar(cvar, old) end
    end
    ns.db.savedCVars = nil
end

function ns.StartSession()
    if restoreTimer then restoreTimer:Cancel(); restoreTimer = nil end
    if ns.sessionActive or InCombatLockdown() then return end
    local saved = {}
    for cvar, value in pairs(BuildSessionCVars()) do
        local old = GetCVar(cvar)
        if old ~= nil then
            saved[cvar] = old
            SetCVar(cvar, value)
        end
    end
    -- Saved persistently so a crash gets cleaned up on next login
    ns.db.savedCVars = saved
    ns.sessionActive = true
    ns.Fire("SESSION_START")
end

function ns.EndSession()
    if restoreTimer then restoreTimer:Cancel() end
    restoreTimer = nil
    if ns.fishing then return end
    if InCombatLockdown() then
        restoreTimer = C_Timer.NewTimer(5, ns.EndSession)
        return
    end
    RestoreCVars()
    ns.sessionActive = false
    ns.Fire("SESSION_END")
end

function ns.ScheduleEndSession()
    if restoreTimer then restoreTimer:Cancel() end
    restoreTimer = C_Timer.NewTimer(ns.db.restoreDelay or 20, ns.EndSession)
end

-- ---------- Events ----------
local function IsFishingSpell(spellID)
    if spellID and not IsSecret(spellID) and FISHING_SET[spellID] then return true end
    local name = UnitChannelInfo("player")
    if name == nil or IsSecret(name) then return false end
    return name == ns.FISHING_NAME
end

ns.On("ADDON_LOADED", function(name)
    if name ~= ADDON then return end
    ExtremeAnglerDB = ExtremeAnglerDB or {}
    -- Migration from 1.0: "sound" used to be a boolean
    if ExtremeAnglerDB.sound ~= nil and type(ExtremeAnglerDB.sound) ~= "table" then
        ExtremeAnglerDB.sound = { enabled = ExtremeAnglerDB.sound and true or false }
    end
    CopyDefaults(ns.defaults, ExtremeAnglerDB)
    ns.db = ExtremeAnglerDB
    ns.Fire("INIT")
end)

ns.On("PLAYER_LOGIN", function()
    if ns.db.savedCVars and not InCombatLockdown() then RestoreCVars() end
    ns.ApplyBinding("cast")
    if not ns.db.enabled then ns.SetEventsActive(false) end
    ns.Fire("LOGIN")
    ns.Print(("loaded. Fishing key: |cffffff00%s|r  (/ea options)"):format(ns.db.key))
    if not ns.db.welcomed then
        C_Timer.After(3, ns.ShowWelcome)
    end
end)

ns.On("UNIT_SPELLCAST_CHANNEL_START", function(unit, _, spellID)
    if unit ~= "player" or not ns.db.enabled or not IsFishingSpell(spellID) then return end
    ns.fishing = true
    ns.channelStart = GetTime()
    local _, _, _, _, endMS = UnitChannelInfo("player")
    if endMS ~= nil and not IsSecret(endMS) and type(endMS) == "number" then
        ns.channelEnd = endMS / 1000
    else
        ns.channelEnd = ns.channelStart + 30
    end
    if ns.channelEnd <= ns.channelStart then ns.channelEnd = ns.channelStart + 30 end
    ns.StartSession()
    ns.ApplyBinding("interact")
    ns.Fire("FISH_START")
end)

ns.On("UNIT_SPELLCAST_CHANNEL_STOP", function(unit)
    if unit ~= "player" or not ns.fishing then return end
    ns.fishing = false
    ns.ApplyBinding("cast")
    ns.ScheduleEndSession()
    ns.Fire("FISH_STOP")
end)

ns.On("PLAYER_REGEN_ENABLED", function()
    if pendingBind then ns.ApplyBinding(pendingBind) end
end)

ns.On("PLAYER_LOGOUT", function()
    if ns.db and ns.db.savedCVars then RestoreCVars() end
end)

-- ---------- First-run welcome ----------
StaticPopupDialogs["EXTREMEANGLER_WELCOME"] = {
    text = "|cff33ccffExtreme Angler|r is installed!\n\n"
        .. "Your fishing key: |cffffff00%s|r\n\n"
        .. "1. Press the key to cast.\n"
        .. "2. When you hear the splash, press the same key to catch.\n\n"
        .. "To change the key and other settings, type:\n|cffffff00/ea options|r",
    button1 = OKAY or "OK",
    button2 = "Open Settings",
    OnShow = function() ns.db.welcomed = true end,
    OnCancel = function(_, _, reason)
        if reason == "clicked" then ns.OpenOptions() end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function ns.ShowWelcome()
    if InCombatLockdown() then
        C_Timer.After(5, ns.ShowWelcome)
        return
    end
    ns.Print(("Your fishing key is |cffffff00%s|r. Type /ea options to change it."):format(ns.db.key))
    StaticPopup_Show("EXTREMEANGLER_WELCOME", ns.db.key)
end

-- ---------- Slash commands ----------
SLASH_EXTREMEANGLER1 = "/ea"
SLASH_EXTREMEANGLER2 = "/extremeangler"
SlashCmdList.EXTREMEANGLER = function(msg)
    local cmd, arg = (msg or ""):match("^(%S*)%s*(.-)$")
    cmd = cmd:lower()

    if cmd == "options" or cmd == "config" then
        ns.OpenOptions()
        return
    end
    if InCombatLockdown() then ns.Print("Settings can't be changed in combat."); return end

    if cmd == "key" then
        if arg == "" then ns.Print("Usage: /ea key <KEY>   (e.g. <, F, BUTTON3, SHIFT-F)"); return end
        ns.SetKey(arg:upper())
    elseif cmd == "sound" then
        ns.db.sound.enabled = not ns.db.sound.enabled
        ns.Print("Sound profile: " .. (ns.db.sound.enabled and "ON" or "OFF"))
        ns.Fire("OPTIONS")
    elseif cmd == "panel" then
        ns.db.showPanel = not ns.db.showPanel
        ns.Fire("OPTIONS")
    elseif cmd == "lock" or cmd == "unlock" then
        ns.db.locked = not ns.db.locked
        ns.Print(ns.db.locked and "Panel and timer locked."
            or "Panel and timer unlocked - drag them with the left mouse button, then type /ea lock.")
        ns.Fire("OPTIONS")
    elseif cmd == "weapon" then
        ns.Gear.RestoreWeapons(true)
    elseif cmd == "reset" then
        ns.Stats.Reset()
    elseif cmd == "test" then
        ns.TestToast()
    elseif cmd == "debug" then
        ns.db.debug = not ns.db.debug
        ns.Print("Debug output: " .. (ns.db.debug and "ON" or "OFF"))
    elseif cmd == "welcome" then
        ns.ShowWelcome()
    elseif cmd == "mem" or cmd == "memory" then
        local usage = 0
        if UpdateAddOnMemoryUsage then UpdateAddOnMemoryUsage() end
        local getUsage = (C_AddOns and C_AddOns.GetAddOnMemoryUsage) or GetAddOnMemoryUsage
        if getUsage then usage = getUsage(ADDON) or 0 end
        ns.Print(("Memory usage: |cffffff00%.1f KB|r"):format(usage))
    elseif cmd == "" or cmd == "toggle" then
        ns.SetEnabled(not ns.db.enabled)
        ns.Print(ns.db.enabled and "ON" or "OFF (your key is back to its normal binding)")
    else
        ns.Print("/ea  - toggle on/off")
        ns.Print("/ea options  - open settings")
        ns.Print("/ea key <KEY>  - change the fishing key (current: " .. ns.db.key .. ")")
        ns.Print("/ea panel  - show/hide the stats panel")
        ns.Print("/ea lock  - lock/unlock the panel and timer for moving")
        ns.Print("/ea sound  - toggle the sound profile")
        ns.Print("/ea weapon  - re-equip your previous weapons now")
        ns.Print("/ea reset  - reset statistics")
        ns.Print("/ea mem  - show memory usage")
        ns.Print("/ea test  - show a test notification")
        ns.Print("/ea welcome  - show the welcome message again")
    end
end
