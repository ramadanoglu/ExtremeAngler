-- Extreme Angler: stats card and bobber timer bar.
-- Built from the game's own textures (no libraries, no images shipped).
-- All rows/textures are created once and reused; updates are batched to one per frame.
local ADDON, ns = ...
local UI = {}
ns.UI = UI

local WHITE = "Interface\\Buttons\\WHITE8X8"
local FISH_ICON = "Interface\\Icons\\Trade_Fishing"
local GEAR_ICON = "Interface\\Icons\\Trade_Engineering"

local ACCENT_R, ACCENT_G, ACCENT_B = 0.25, 0.72, 1.00
local W = 240             -- panel width
local PAD = 10            -- inner padding
local CW = W - PAD * 2    -- content width
local MAX_ROWS = 6
local ROW_H = 26
local HEADER_H = 26

local floor, min, max = math.floor, math.min, math.max

-- ---------- Helpers ----------
local function SetFlatBackdrop(frame, alpha)
    frame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    frame:SetBackdropColor(0.05, 0.06, 0.08, alpha or 0.88)
    frame:SetBackdropBorderColor(1, 1, 1, 0.08)
end

local function Text(parent, font, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end

-- Fade in/out with AnimationGroups (handled by the client, no OnUpdate)
local function AddFader(frame)
    local fin = frame:CreateAnimationGroup()
    local a = fin:CreateAnimation("Alpha")
    a:SetFromAlpha(0); a:SetToAlpha(1); a:SetDuration(0.2)
    fin:SetToFinalAlpha(true)

    local fout = frame:CreateAnimationGroup()
    local b = fout:CreateAnimation("Alpha")
    b:SetFromAlpha(1); b:SetToAlpha(0); b:SetDuration(0.25)
    fout:SetToFinalAlpha(true)
    fout:SetScript("OnFinished", function()
        frame:Hide()
        frame:SetAlpha(1)
    end)

    function frame:FadeShow()
        if self:IsShown() and not fout:IsPlaying() then return end
        fout:Stop()
        self:SetAlpha(0)
        self:Show()
        fin:Play()
    end
    function frame:FadeHide()
        if not self:IsShown() or fout:IsPlaying() then return end
        fin:Stop()
        fout:Play()
    end
end

-- A flat bar made of two textures. width is fixed so no layout pass is needed.
local function NewBar(parent, width, height, r, g, b)
    local bar = {}
    bar.width = width
    bar.bg = parent:CreateTexture(nil, "ARTWORK")
    bar.bg:SetColorTexture(1, 1, 1, 0.07)
    bar.bg:SetSize(width, height)
    bar.fill = parent:CreateTexture(nil, "ARTWORK", nil, 1)
    bar.fill:SetColorTexture(r, g, b, 0.95)
    bar.fill:SetHeight(height)
    bar.fill:SetPoint("TOPLEFT", bar.bg, "TOPLEFT")
    function bar:SetPoint(...) self.bg:SetPoint(...) end
    function bar:SetValue(f)
        f = max(0, min(1, f or 0))
        if f <= 0 then
            self.fill:Hide()
        else
            self.fill:Show()
            self.fill:SetWidth(self.width * f)
        end
    end
    function bar:SetColor(r2, g2, b2) self.fill:SetColorTexture(r2, g2, b2, 0.95) end
    return bar
end

local function SavePosition(frame, key)
    local point, _, relPoint, x, y = frame:GetPoint()
    ns.db[key] = { point, relPoint, x, y }
end

local function LoadPosition(frame, key, default)
    local p = ns.db[key] or default
    frame:ClearAllPoints()
    frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
end

local function StartDrag(frame)
    if not ns.db.locked then
        frame.isMoving = true
        frame:StartMoving()
    end
end

local function StopDrag(frame, key)
    if not frame.isMoving then return end
    frame.isMoving = false
    frame:StopMovingOrSizing()
    SavePosition(frame, key)
end

local function MakeMovable(frame, key)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", StartDrag)
    frame:SetScript("OnDragStop", function(self) StopDrag(self, key) end)
end

-- Child frames that take the mouse (rows, buttons) forward drags to the panel
local function ForwardDrag(child, target, key)
    child:RegisterForDrag("LeftButton")
    child:SetScript("OnDragStart", function() StartDrag(target) end)
    child:SetScript("OnDragStop", function() StopDrag(target, key) end)
end

-- =====================================================================
-- Stats card
-- =====================================================================
local panel = CreateFrame("Frame", "ExtremeAnglerPanel", UIParent, "BackdropTemplate")
panel:SetSize(W, 100)
panel:SetFrameStrata("MEDIUM")
panel:Hide()
SetFlatBackdrop(panel)
MakeMovable(panel, "panelPos")
AddFader(panel)

-- Accent line on top
local accent = panel:CreateTexture(nil, "BORDER")
accent:SetColorTexture(ACCENT_R, ACCENT_G, ACCENT_B, 0.9)
accent:SetPoint("TOPLEFT", 1, -1)
accent:SetPoint("TOPRIGHT", -1, -1)
accent:SetHeight(2)

-- Header
local icon = panel:CreateTexture(nil, "ARTWORK")
icon:SetTexture(FISH_ICON)
icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
icon:SetSize(16, 16)
icon:SetPoint("TOPLEFT", PAD, -7)

local title = Text(panel, "GameFontNormal")
title:SetPoint("LEFT", icon, "RIGHT", 6, 0)
title:SetText("Extreme Angler")
title:SetTextColor(1, 1, 1)

local function IconButton(texture, size, tooltip, onClick)
    local b = CreateFrame("Button", nil, panel)
    b:SetSize(size, size)
    local t = b:CreateTexture(nil, "ARTWORK")
    t:SetAllPoints()
    if texture then t:SetTexture(texture); t:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    t:SetAlpha(0.6)
    b.tex = t
    b:SetScript("OnEnter", function(self)
        self.tex:SetAlpha(1)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(type(tooltip) == "function" and tooltip() or tooltip, 1, 1, 1)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(self)
        self.tex:SetAlpha(0.6)
        GameTooltip:Hide()
    end)
    b:SetScript("OnClick", onClick)
    ForwardDrag(b, panel, "panelPos")
    return b
end

local gearBtn = IconButton(GEAR_ICON, 14, "Settings", function() ns.OpenOptions() end)
gearBtn:SetPoint("TOPRIGHT", -PAD, -8)

local collapseBtn = IconButton(nil, 14, "Collapse / expand", function()
    ns.db.collapsed = not ns.db.collapsed
    UI.Request()
end)
collapseBtn:SetPoint("RIGHT", gearBtn, "LEFT", -6, 0)
-- Draw a minus / plus with two small textures
collapseBtn.h = collapseBtn:CreateTexture(nil, "ARTWORK")
collapseBtn.h:SetColorTexture(1, 1, 1, 0.8)
collapseBtn.h:SetSize(9, 2)
collapseBtn.h:SetPoint("CENTER")
collapseBtn.v = collapseBtn:CreateTexture(nil, "ARTWORK")
collapseBtn.v:SetColorTexture(1, 1, 1, 0.8)
collapseBtn.v:SetSize(2, 9)
collapseBtn.v:SetPoint("CENTER")
collapseBtn.tex = collapseBtn.h -- hover highlight target

-- Lock button: drawn from small textures (body + shackle); the shackle opens
-- and the icon turns blue while unlocked, so it's obvious the panel can move.
local lockBtn = IconButton(nil, 14, function()
    return ns.db.locked and "Locked - click to unlock and move" or "Unlocked - drag to move, click to lock"
end, function()
    ns.db.locked = not ns.db.locked
    ns.Fire("OPTIONS")
end)
lockBtn:SetPoint("RIGHT", collapseBtn, "LEFT", -6, 0)
do
    local function Piece(w, h)
        local t = lockBtn:CreateTexture(nil, "ARTWORK")
        t:SetColorTexture(1, 1, 1, 1)
        t:SetSize(w, h)
        return t
    end
    lockBtn.body = Piece(10, 7)
    lockBtn.body:SetPoint("BOTTOM", 0, 1)
    lockBtn.left = Piece(2, 5)
    lockBtn.right = Piece(2, 5)
    lockBtn.top = Piece(6, 2)
    lockBtn.tex = lockBtn.body
end

function lockBtn:Refresh()
    local locked = ns.db.locked
    local lift = locked and 0 or 2
    self.left:ClearAllPoints()
    self.left:SetPoint("BOTTOMLEFT", self.body, "TOPLEFT", 2, lift)
    self.top:ClearAllPoints()
    self.top:SetPoint("TOPLEFT", self.left, "TOPLEFT", 0, 0)
    self.right:ClearAllPoints()
    self.right:SetPoint("BOTTOMRIGHT", self.body, "TOPRIGHT", -2, lift)
    self.right:SetShown(locked) -- open shackle when unlocked
    local r, g, b, a = 1, 1, 1, 0.8
    if not locked then r, g, b, a = ACCENT_R, ACCENT_G, ACCENT_B, 1 end
    for _, t in ipairs({ self.body, self.left, self.right, self.top }) do
        t:SetVertexColor(r, g, b, a)
    end
end

-- One-line summary shown in the header when collapsed
-- (takes the title's place, so it never overlaps the name)
local summary = Text(panel, "GameFontHighlightSmall", "LEFT")
summary:SetPoint("LEFT", icon, "RIGHT", 6, 0)
summary:SetTextColor(0.8, 0.85, 0.9)

-- Body (hidden when collapsed)
local body = CreateFrame("Frame", nil, panel)
body:SetPoint("TOPLEFT", 0, -HEADER_H)
body:SetPoint("TOPRIGHT", 0, -HEADER_H)
body:SetHeight(10)

-- Skill
local skillLabel = Text(body)
skillLabel:SetPoint("TOPLEFT", PAD, -4)
skillLabel:SetText("Fishing")
local skillValue = Text(body, "GameFontHighlightSmall", "RIGHT")
skillValue:SetPoint("TOPRIGHT", -PAD, -4)
local skillBar = NewBar(body, CW, 6, ACCENT_R, ACCENT_G, ACCENT_B)
skillBar:SetPoint("TOPLEFT", PAD, -18)

-- Flash over the skill bar on skill up
local flash = body:CreateTexture(nil, "OVERLAY")
flash:SetColorTexture(1, 1, 1, 1)
flash:SetSize(CW, 6)
flash:SetPoint("TOPLEFT", PAD, -18)
flash:SetAlpha(0)
local flashAnim = flash:CreateAnimationGroup()
do
    local up = flashAnim:CreateAnimation("Alpha")
    up:SetFromAlpha(0); up:SetToAlpha(0.9); up:SetDuration(0.15); up:SetOrder(1)
    local down = flashAnim:CreateAnimation("Alpha")
    down:SetFromAlpha(0.9); down:SetToAlpha(0); down:SetDuration(0.6); down:SetOrder(2)
    flashAnim:SetToFinalAlpha(true)
end

-- Session
local sessionLabel = Text(body, "GameFontDisableSmall")
sessionLabel:SetPoint("TOPLEFT", PAD, -34)
sessionLabel:SetText("SESSION")
local sessionValue = Text(body, "GameFontHighlightSmall", "RIGHT")
sessionValue:SetPoint("TOPRIGHT", -PAD, -34)

local divider = body:CreateTexture(nil, "ARTWORK")
divider:SetColorTexture(1, 1, 1, 0.06)
divider:SetSize(CW, 1)
divider:SetPoint("TOPLEFT", PAD, -50)

-- Zone
local zoneLabel = Text(body, "GameFontNormalSmall")
zoneLabel:SetPoint("TOPLEFT", PAD, -58)
zoneLabel:SetWidth(CW - 60)
local zoneValue = Text(body, "GameFontDisableSmall", "RIGHT")
zoneValue:SetPoint("TOPRIGHT", -PAD, -58)

local emptyText = Text(body, "GameFontDisableSmall")
emptyText:SetPoint("TOPLEFT", PAD, -76)
emptyText:SetText("No catches here yet.")

local ROWS_TOP = 74
local rows = {}

local function RowOnEnter(self)
    if not self.itemID then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(self.itemID)
    GameTooltip:Show()
end

local function GetRow(i)
    local row = rows[i]
    if row then return row end
    row = CreateFrame("Frame", nil, body)
    row:SetSize(CW, ROW_H - 2)
    row:SetPoint("TOPLEFT", PAD, -(ROWS_TOP + (i - 1) * ROW_H))
    row:EnableMouse(true)
    row:SetScript("OnEnter", RowOnEnter)
    row:SetScript("OnLeave", GameTooltip_Hide)
    ForwardDrag(row, panel, "panelPos")

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(16, 16)
    row.icon:SetPoint("TOPLEFT", 0, -1)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.name = Text(row)
    row.name:SetPoint("TOPLEFT", 22, -2)
    row.name:SetWidth(CW - 22 - 36)

    row.pct = Text(row, "GameFontHighlightSmall", "RIGHT")
    row.pct:SetPoint("TOPRIGHT", 0, -2)

    row.bar = NewBar(row, CW - 22, 3, ACCENT_R, ACCENT_G, ACCENT_B)
    row.bar:SetPoint("TOPLEFT", 22, -16)

    rows[i] = row
    return row
end

-- ---------- Panel update ----------
local function Percent(part, whole)
    if not whole or whole <= 0 then return 0 end
    return part / whole
end

local function RefreshPanel()
    local db = ns.db
    local Stats = ns.Stats
    local s = Stats.session
    local rank, maxRank, mod = Stats.GetSkill()

    -- Header / collapsed state
    local collapsed = db.collapsed
    collapseBtn.v:SetShown(collapsed)
    lockBtn:Refresh()
    if collapsed then
        body:Hide()
        if rank then
            summary:SetFormattedText("%d/%d  |cff999999·|r  %d/%d", s.catches, s.casts, rank, maxRank)
        else
            summary:SetFormattedText("%d/%d", s.catches, s.casts)
        end
        title:Hide()
        summary:Show()
        panel:SetHeight(HEADER_H + 2)
        return
    end
    summary:Hide()
    title:Show()
    body:Show()

    -- Skill
    if rank then
        if mod and mod > 0 then
            skillValue:SetFormattedText("%d |cff4cff4c(+%d)|r / %d", rank, mod, maxRank)
        else
            skillValue:SetFormattedText("%d / %d", rank, maxRank)
        end
        skillBar:SetValue(Percent(rank, maxRank))
        if rank >= maxRank then skillBar:SetColor(1, 0.55, 0.1) else skillBar:SetColor(ACCENT_R, ACCENT_G, ACCENT_B) end
    else
        skillValue:SetText("|cff999999-|r")
        skillBar:SetValue(0)
    end

    -- Session
    sessionValue:SetFormattedText("%d casts  |cff999999·|r  %d fish", s.casts, s.catches)

    -- Zone table
    local zoneName = Stats.Zone()
    local zone = db.stats.zones[zoneName]
    zoneLabel:SetText(zoneName:upper())

    local shown = 0
    if zone and zone.catches > 0 then
        zoneValue:SetFormattedText("%d fish", zone.catches)
        emptyText:Hide()
        local top = Stats.Top(zone.items, MAX_ROWS)
        local best = top[1] and top[1].count or 1
        for i, e in ipairs(top) do
            local row = GetRow(i)
            local name, tex, r, g, b = Stats.ItemInfo(e.id)
            row.itemID = e.id
            row.icon:SetTexture(tex)
            row.name:SetText(name)
            row.name:SetTextColor(r, g, b)
            row.pct:SetFormattedText("%d%%", floor(Percent(e.count, zone.catches) * 100 + 0.5))
            row.bar:SetValue(Percent(e.count, best)) -- relative to the most common catch
            row.bar:SetColor(r * 0.5 + ACCENT_R * 0.5, g * 0.5 + ACCENT_G * 0.5, b * 0.5 + ACCENT_B * 0.5)
            row:Show()
            shown = i
        end
    else
        zoneValue:SetText("")
        emptyText:Show()
    end
    for i = shown + 1, #rows do rows[i]:Hide() end

    local bodyH = (shown > 0) and (ROWS_TOP + shown * ROW_H) or (ROWS_TOP + 16)
    body:SetHeight(bodyH)
    panel:SetHeight(HEADER_H + bodyH + 4)
end

-- =====================================================================
-- Timer bar
-- =====================================================================
local TW, TH = 220, 6
local timer = CreateFrame("Frame", "ExtremeAnglerTimer", UIParent, "BackdropTemplate")
timer:SetSize(TW + 16, 30)
timer:Hide()
SetFlatBackdrop(timer, 0.75)
MakeMovable(timer, "timerPos")
AddFader(timer)

local tLabel = Text(timer)
tLabel:SetPoint("TOPLEFT", 8, -5)
tLabel:SetText("Bobber")
tLabel:SetTextColor(0.8, 0.85, 0.9)
local tValue = Text(timer, "GameFontHighlightSmall", "RIGHT")
tValue:SetPoint("TOPRIGHT", -8, -5)

local tBar = NewBar(timer, TW, TH, 0.55, 0.65, 0.75)
tBar:SetPoint("TOPLEFT", 8, -19)

-- Highlighted window where fish usually bite
local biteZone = timer:CreateTexture(nil, "ARTWORK", nil, 2)
biteZone:SetColorTexture(0.3, 1, 0.4, 0.28)
biteZone:SetHeight(TH + 4)

local biteLo, biteHi = 4, 18
local lastTenth = -1

local function PlaceBiteZone(total)
    biteLo, biteHi = ns.Stats.BiteZone()
    local x1 = min(1, biteLo / total) * TW
    local x2 = min(1, biteHi / total) * TW
    biteZone:ClearAllPoints()
    biteZone:SetPoint("LEFT", tBar.bg, "LEFT", x1, 0)
    biteZone:SetWidth(max(2, x2 - x1))
end

local function TimerOnUpdate(self)
    if not ns.fishing then return end
    local now = GetTime()
    local total = ns.channelEnd - ns.channelStart
    local elapsed = now - ns.channelStart
    tBar:SetValue(elapsed / total)
    if elapsed < biteLo then
        tBar:SetColor(0.55, 0.65, 0.75)
    elseif elapsed <= biteHi then
        tBar:SetColor(0.3, 1, 0.45)
    else
        tBar:SetColor(1, 0.6, 0.2)
    end
    -- Only rebuild the text when the shown value changes
    local tenth = floor(max(0, ns.channelEnd - now) * 10)
    if tenth ~= lastTenth then
        lastTenth = tenth
        tValue:SetFormattedText("%.1fs", tenth / 10)
    end
end

local function RefreshTimer()
    local db = ns.db
    if not db.enabled or not db.showTimer then
        timer:SetScript("OnUpdate", nil)
        timer:FadeHide()
        return
    end
    if ns.fishing then
        lastTenth = -1
        PlaceBiteZone(max(1, ns.channelEnd - ns.channelStart))
        biteZone:Show()
        tLabel:SetText("Bobber")
        timer:SetScript("OnUpdate", TimerOnUpdate)
        timer:FadeShow()
    elseif not db.locked then
        -- Unlocked: show a preview so it can be dragged
        timer:SetScript("OnUpdate", nil)
        PlaceBiteZone(30)
        biteZone:Show()
        tBar:SetValue(0.45)
        tBar:SetColor(0.3, 1, 0.45)
        tLabel:SetText("Extreme Angler timer - drag me")
        tValue:SetText("")
        timer:FadeShow()
    else
        timer:SetScript("OnUpdate", nil)
        timer:FadeHide()
    end
end

-- =====================================================================
-- Update scheduling
-- =====================================================================
local pending = false

local function Refresh()
    pending = false
    local db = ns.db
    if not db then return end
    local show = db.enabled and db.showPanel and (not db.panelOnlyFishing or ns.sessionActive)
    if show then
        RefreshPanel()
        panel:FadeShow()
    else
        panel:FadeHide()
    end
end

-- Many events can arrive in the same frame; refresh once on the next frame
function UI.Request()
    if pending then return end
    pending = true
    C_Timer.After(0, Refresh)
end

ns.Listen("LOGIN", function()
    -- One-time reset: positions saved by 2.0.0 could be wrong (saved while locked)
    if (ns.db.layoutVersion or 0) < 2 then
        ns.db.panelPos, ns.db.timerPos = nil, nil
        ns.db.layoutVersion = 2
    end
    LoadPosition(panel, "panelPos", { "LEFT", "LEFT", 20, 0 })
    LoadPosition(timer, "timerPos", { "CENTER", "CENTER", 0, -180 })
    UI.Request()
    RefreshTimer()
end)

ns.Listen("STATS", UI.Request)
ns.Listen("SESSION_START", UI.Request)
ns.Listen("SESSION_END", UI.Request)
ns.Listen("OPTIONS", function() UI.Request(); RefreshTimer() end)
ns.Listen("FISH_START", RefreshTimer)
ns.Listen("FISH_STOP", RefreshTimer)
ns.Listen("SKILL_UP", function()
    if panel:IsShown() and not ns.db.collapsed then flashAnim:Stop(); flashAnim:Play() end
end)
ns.On("ZONE_CHANGED_NEW_AREA", UI.Request)
