-- Extreme Angler: settings panel (Game Menu > Options > AddOns > ExtremeAngler).
local ADDON, ns = ...

local panel = CreateFrame("Frame")
panel.name = "Extreme Angler"
panel:Hide()

local controls = {}

local function Header(text, x, y)
    local fs = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetText(text)
    return fs
end

local function Check(x, y, label, tooltip, get, set, indent)
    local cb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    cb:SetSize(26, 26)
    cb:SetPoint("TOPLEFT", x + (indent and 20 or 0), y)
    local fs = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    fs:SetPoint("LEFT", cb, "RIGHT", 4, 1)
    fs:SetText(label)
    cb:SetScript("OnClick", function(self)
        if InCombatLockdown() then self:SetChecked(get()); return end
        set(self:GetChecked() and true or false)
        ns.Fire("OPTIONS")
    end)
    if tooltip then
        cb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(label, 1, 1, 1)
            GameTooltip:AddLine(tooltip, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", GameTooltip_Hide)
    end
    cb.Refresh = function() cb:SetChecked(get()) end
    controls[#controls + 1] = cb
    return cb
end

local function Button(text, width, x, y, onClick)
    local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    b:SetSize(width, 24)
    b:SetPoint("TOPLEFT", x, y)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end

local function Opt(key)
    return function() return ns.db[key] end, function(v) ns.db[key] = v end
end
local function SoundOpt(key)
    return function() return ns.db.sound[key] end, function(v) ns.db.sound[key] = v end
end

-- ---------- Layout ----------
-- Controls are created the first time the panel is opened, so Extreme Angler uses
-- no memory for them unless you actually open the settings.
local built = false
local StopCapture
local function Build()
    built = true
local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("Extreme Angler")

local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
sub:SetText("One key fishing: press to cast, press again on the splash to catch.")

local L, R = 16, 320
local y

-- Left column: general
y = -70
Header("General", L, y); y = y - 22
local g, s
g, s = Opt("enabled");     Check(L, y, "Enable Extreme Angler", "Turn the fishing key on or off. When off, Extreme Angler goes to sleep and stops listening to game events.", g, function(v)
    ns.SetEnabled(v)
end); y = y - 26
g, s = Opt("autoLoot");    Check(L, y, "Auto loot while fishing", "Turns on auto loot during a fishing session and restores your setting afterwards.", g, s); y = y - 26
g, s = Opt("poleSwap");    Check(L, y, "Equip fishing pole automatically", "If no pole is equipped, the key equips one from your bags. Your weapons are re-equipped when you stop fishing.", g, s); y = y - 26
g, s = Opt("autoLure");    Check(L, y, "Apply lures automatically", "If your pole has no lure, the key applies the best usable lure from your bags first.", g, s); y = y - 26
g, s = Opt("lureWarn");    Check(L, y, "Warn when lure is missing", "Shows a warning when your pole has no lure or you have run out.", g, s); y = y - 38

-- Left column: notifications
Header("Notifications", L, y); y = y - 22
g, s = Opt("skillNotify");   Check(L, y, "Fishing skill up", "A card and a chat message when your fishing skill increases.", g, s); y = y - 26
g, s = Opt("notifyNew");     Check(L, y, "New catches", "A card when you catch something for the first time, or for the first time in this zone.", g, s); y = y - 26
g, s = Opt("notifyRare");    Check(L, y, "Rare catches", "A card for uncommon (green) or better items.", g, s); y = y - 26
g, s = Opt("notifySummary"); Check(L, y, "Session summary", "A card with casts, catches and new finds when you stop fishing.", g, s); y = y - 26
g, s = Opt("notifySound");   Check(L, y, "Play a sound", "Play a short sound with each card.", g, s, true); y = y - 26

-- Sound picker: each click switches to the next sound and plays it as a preview
local soundBtn = Button("", 190, L + 48, y - 1, function(self)
    local list = ns.ToastSounds()
    if #list == 0 then return end
    local idx = 0
    for i, snd in ipairs(list) do if snd.key == ns.db.notifySoundName then idx = i end end
    local nextSound = list[idx % #list + 1]
    ns.db.notifySoundName = nextSound.key
    self:Refresh()
    ns.PlayToastSound("new", true)
end)
soundBtn.Refresh = function()
    local self = soundBtn
    local label = "None available"
    for _, snd in ipairs(ns.ToastSounds()) do
        label = label == "None available" and snd.label or label
        if snd.key == ns.db.notifySoundName then label = snd.label end
    end
    self:SetText("Sound: " .. label)
end
controls[#controls + 1] = soundBtn
y = y - 38

-- Key binding
Header("Fishing key", L, y); y = y - 24
local keyBtn = Button("", 180, L, y, nil)
keyBtn:RegisterForClicks("AnyUp")
local keyHint = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
keyHint:SetPoint("LEFT", keyBtn, "RIGHT", 8, 0)
keyHint:SetText("Click, then press a key")

local MOUSE_KEYS = { MiddleButton = "BUTTON3", Button4 = "BUTTON4", Button5 = "BUTTON5" }

function StopCapture()
    keyBtn.waiting = false
    keyBtn:EnableKeyboard(false)
    keyBtn:SetText(ns.db.key)
    keyHint:SetText("Click, then press a key")
end

local function Modifiers()
    local m = ""
    if IsAltKeyDown() then m = m .. "ALT-" end
    if IsControlKeyDown() then m = m .. "CTRL-" end
    if IsShiftKeyDown() then m = m .. "SHIFT-" end
    return m
end

keyBtn:SetScript("OnClick", function(self, button)
    if InCombatLockdown() then return end
    if self.waiting then
        local mk = MOUSE_KEYS[button]
        if mk then ns.SetKey(Modifiers() .. mk) end
        StopCapture()
        return
    end
    self.waiting = true
    self:EnableKeyboard(true)
    self:SetText("Press a key...")
    keyHint:SetText("ESC to cancel")
end)

keyBtn:SetScript("OnKeyDown", function(self, key)
    if not self.waiting then
        self:SetPropagateKeyboardInput(true)
        return
    end
    self:SetPropagateKeyboardInput(false)
    if key == "ESCAPE" then StopCapture(); return end
    if key:find("SHIFT") or key:find("CTRL") or key:find("ALT") then return end -- wait for the real key
    ns.SetKey(Modifiers() .. key)
    StopCapture()
end)
keyBtn:SetScript("OnHide", function(self) if self.waiting then StopCapture() end end)
y = y - 38

-- Right column: display
y = -70
Header("Display", R, y); y = y - 22
g, s = Opt("locked");           Check(R, y, "Lock panel, timer and cards", "Uncheck to drag the panel, the timer bar and the notification cards. You can also use the lock button on the panel.", g, s); y = y - 26
g, s = Opt("showPanel");        Check(R, y, "Show stats panel", "Session catches, skill and loot table for the current zone.", g, s); y = y - 26
g, s = Opt("panelOnlyFishing"); Check(R, y, "Only while fishing", "Hide the panel when you are not fishing.", g, s, true); y = y - 26
g, s = Opt("showTimer");        Check(R, y, "Show bobber timer", "A bar showing how long the bobber has left.", g, s); y = y - 38

-- Right column: sound
Header("Sound profile (while fishing)", R, y); y = y - 22
g, s = SoundOpt("enabled");      Check(R, y, "Enable sound profile", "Changes your sound settings while fishing so the splash is easy to hear, then restores them.", g, s); y = y - 26
g, s = SoundOpt("master");       Check(R, y, "Master volume to max", nil, g, s, true); y = y - 26
g, s = SoundOpt("maxSFX");       Check(R, y, "Effects volume to max", "The splash is an effect sound.", g, s, true); y = y - 26
g, s = SoundOpt("muteMusic");    Check(R, y, "Mute music", nil, g, s, true); y = y - 26
g, s = SoundOpt("muteAmbience"); Check(R, y, "Mute ambience", nil, g, s, true); y = y - 26
g, s = SoundOpt("muteDialog");   Check(R, y, "Mute dialog", nil, g, s, true); y = y - 26
y = y - 10

-- Statistics
Header("Statistics", R, y); y = y - 24
local resetBtn
resetBtn = Button("Reset statistics", 180, R, y, function(self)
    if self.confirm then
        self.confirm = nil
        self:SetText("Reset statistics")
        ns.Stats.Reset()
    else
        self.confirm = true
        self:SetText("Click again to confirm")
        C_Timer.After(3, function()
            if self.confirm then self.confirm = nil; self:SetText("Reset statistics") end
        end)
    end
end)
y = y - 30
Button("Re-equip my weapons", 180, R, y, function() ns.Gear.RestoreWeapons(true) end)
y = y - 30
Button("Show a test notification", 180, R, y, function() ns.TestToast() end)

local note = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
note:SetPoint("BOTTOMLEFT", 16, 16)
note:SetText("Changes to the sound profile apply from your next fishing session.  /ea help for commands.")

end

-- ---------- Refresh & registration ----------
panel:SetScript("OnShow", function()
    if not ns.db then return end
    if not built then Build() end
    for _, c in ipairs(controls) do c.Refresh() end
    StopCapture()
end)
ns.Listen("OPTIONS", function()
    if built and panel:IsShown() then for _, c in ipairs(controls) do c.Refresh() end end
end)

if Settings and Settings.RegisterCanvasLayoutCategory then
    local category = Settings.RegisterCanvasLayoutCategory(panel, "Extreme Angler")
    Settings.RegisterAddOnCategory(category)
    ns.settingsCategory = category
elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
end

function ns.OpenOptions()
    if ns.settingsCategory and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(ns.settingsCategory:GetID())
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(panel)
        InterfaceOptionsFrame_OpenToCategory(panel)
    end
end
