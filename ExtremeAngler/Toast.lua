-- Extreme Angler: notification cards (new catch, rare catch, skill up, session summary).
-- Up to 3 cards stack under an anchor. Cards are pooled and their whole life
-- (fade in, hold, fade out) is a single AnimationGroup: no timers, no OnUpdate.
local ADDON, ns = ...

local WHITE = "Interface\\Buttons\\WHITE8X8"
local FISH_ICON = "Interface\\Icons\\Trade_Fishing"
local TW, TH, GAP = 270, 46, 6
local MAX_ACTIVE = 3
local HOLD = 4

local ACCENT = { 0.25, 0.72, 1.00 }
local GREEN = { 0.30, 1.00, 0.45 }
local GOLD = { 1.00, 0.82, 0.20 }

-- Notification sounds are the game's own toast/reward sounds, played by
-- FileDataID (same approach Questie uses). "Smart" picks a sound per card type.
-- If a file is missing on this client, PlaySoundFile returns false and we fall
-- back to the classic achievement sound, then the level-up sound.
local SND = {
    loot      = 1138111, -- ui_loot_toast_lesser_item_won_01
    epic      = 642829,  -- ui_epicloot_toast_01
    skill     = 642845,  -- ui_tradeskill_levelup_01
    objective = 642843,  -- ui_quest_objectivecomplete_01
    bonus     = 876092,  -- ui_scenario_bonusobjective_success
    worldq    = 1489470, -- ui_worldquest_complete
    social    = 1542296, -- ui_71_social_queueing_notification
    achieve   = 569143,  -- achievmentsound1 (classic achievement)
}
local FALLBACKS = { SND.achieve, 569593 } -- 569593 = levelup

local SMART = { new = SND.loot, rare = SND.epic, skill = SND.skill, summary = SND.objective }

local SOUND_CHOICES = {
    { key = "smart",     label = "Smart (per card)" },
    { key = "loot",      label = "Loot toast" },
    { key = "epic",      label = "Epic loot" },
    { key = "skill",     label = "Skill level up" },
    { key = "objective", label = "Objective complete" },
    { key = "bonus",     label = "Bonus objective" },
    { key = "worldq",    label = "World quest" },
    { key = "social",    label = "Notification" },
    { key = "achieve",   label = "Achievement" },
}

function ns.ToastSounds() return SOUND_CHOICES end

local function Play(id)
    local ok, willPlay = pcall(PlaySoundFile, id, "SFX")
    return ok and willPlay
end

-- kind: "new", "rare", "skill", "summary" (used by the Smart choice)
function ns.PlayToastSound(kind, force)
    if not force and not ns.db.notifySound then return end
    local choice = ns.db.notifySoundName
    local id = SND[choice]
    if not id then id = SMART[kind] or SND.loot end -- "smart" or unknown/old value
    if Play(id) then return end
    for _, fb in ipairs(FALLBACKS) do
        if Play(fb) then return end
    end
end
local PlayToastSound = ns.PlayToastSound

-- ---------- Anchor (movable when unlocked) ----------
local anchor = CreateFrame("Frame", "ExtremeAnglerToastAnchor", UIParent, "BackdropTemplate")
anchor:SetSize(TW, TH)
anchor:SetFrameStrata("HIGH")
anchor:SetMovable(true)
anchor:SetClampedToScreen(true)
anchor:RegisterForDrag("LeftButton")
anchor:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
anchor:SetBackdropColor(0.05, 0.06, 0.08, 0.6)
anchor:SetBackdropBorderColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.6)
anchor.label = anchor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
anchor.label:SetPoint("CENTER")
anchor.label:SetText("Extreme Angler notifications - drag me")
anchor:SetScript("OnDragStart", function(self)
    if not ns.db.locked then self.isMoving = true; self:StartMoving() end
end)
anchor:SetScript("OnDragStop", function(self)
    if not self.isMoving then return end
    self.isMoving = false
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    ns.db.toastPos = { point, relPoint, x, y }
end)

local function RefreshAnchor()
    -- The anchor itself is only visible (and draggable) while unlocked
    local unlocked = not ns.db.locked
    anchor:EnableMouse(unlocked)
    anchor:SetBackdropColor(0.05, 0.06, 0.08, unlocked and 0.6 or 0)
    anchor:SetBackdropBorderColor(ACCENT[1], ACCENT[2], ACCENT[3], unlocked and 0.6 or 0)
    anchor.label:SetShown(unlocked)
end

-- ---------- Cards ----------
local pool, active = {}, {}

local function Layout()
    for i, card in ipairs(active) do
        card:ClearAllPoints()
        card:SetPoint("TOP", anchor, "TOP", 0, -(i - 1) * (TH + GAP))
    end
end

local function Release(card)
    card.anim:Stop()
    card:Hide()
    for i, c in ipairs(active) do
        if c == card then table.remove(active, i); break end
    end
    pool[#pool + 1] = card
    Layout()
end

local function CreateCard()
    local card = CreateFrame("Button", nil, anchor, "BackdropTemplate")
    card:SetSize(TW, TH)
    card:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    card:SetBackdropColor(0.05, 0.06, 0.08, 0.92)
    card:SetBackdropBorderColor(1, 1, 1, 0.08)

    card.strip = card:CreateTexture(nil, "BORDER")
    card.strip:SetPoint("TOPLEFT", 1, -1)
    card.strip:SetPoint("BOTTOMLEFT", 1, 1)
    card.strip:SetWidth(3)

    card.icon = card:CreateTexture(nil, "ARTWORK")
    card.icon:SetSize(30, 30)
    card.icon:SetPoint("LEFT", 12, 0)
    card.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    card.title = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    card.title:SetPoint("TOPLEFT", card.icon, "TOPRIGHT", 10, 0)
    card.title:SetPoint("RIGHT", -10, 0)
    card.title:SetJustifyH("LEFT")
    card.title:SetWordWrap(false)

    card.text = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    card.text:SetPoint("BOTTOMLEFT", card.icon, "BOTTOMRIGHT", 10, 1)
    card.text:SetPoint("RIGHT", -10, 0)
    card.text:SetJustifyH("LEFT")
    card.text:SetWordWrap(false)

    -- Slide down + fade in, hold, fade out
    local ag = card:CreateAnimationGroup()
    local slide = ag:CreateAnimation("Translation")
    slide:SetOffset(0, -8); slide:SetDuration(0.25); slide:SetOrder(1)
    local fin = ag:CreateAnimation("Alpha")
    fin:SetFromAlpha(0); fin:SetToAlpha(1); fin:SetDuration(0.25); fin:SetOrder(1)
    local hold = ag:CreateAnimation("Alpha")
    hold:SetFromAlpha(1); hold:SetToAlpha(1); hold:SetDuration(HOLD); hold:SetOrder(2)
    local fout = ag:CreateAnimation("Alpha")
    fout:SetFromAlpha(1); fout:SetToAlpha(0); fout:SetDuration(0.6); fout:SetOrder(3)
    ag:SetScript("OnFinished", function() Release(card) end)
    card.anim = ag

    card:SetScript("OnClick", function(self) Release(self) end) -- click to dismiss
    card:SetScript("OnEnter", function(self)
        if self.itemID then
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetItemByID(self.itemID)
            GameTooltip:Show()
        end
    end)
    card:SetScript("OnLeave", GameTooltip_Hide)
    return card
end

-- icon, title, text, color {r,g,b} for the strip/title, optional itemID for the tooltip
function ns.Toast(icon, title, text, color, itemID, kind)
    if not ns.db then return end
    if #active >= MAX_ACTIVE then Release(active[1]) end
    local card = table.remove(pool) or CreateCard()
    color = color or ACCENT
    card.strip:SetColorTexture(color[1], color[2], color[3], 1)
    card.title:SetText(title)
    card.title:SetTextColor(color[1], color[2], color[3])
    card.text:SetText(text or "")
    card.icon:SetTexture(icon or FISH_ICON)
    card.itemID = itemID
    table.insert(active, card)
    Layout()
    card:SetAlpha(1)
    card:Show()
    card.anim:Play()
    PlayToastSound(kind)
end

-- ---------- Triggers ----------
local sessionStart = nil -- { casts, catches, new } at the start of a fishing session

ns.Listen("CATCH", function(itemID, quantity, newInZone, newEver, quality)
    local db = ns.db
    local name, icon, r, g, b = ns.Stats.ItemInfo(itemID)
    local qtyText = (quantity and quantity > 1) and (" x" .. quantity) or ""
    local itemText = ("|cff%02x%02x%02x%s|r%s"):format(r * 255, g * 255, b * 255, name, qtyText)

    if newInZone and sessionStart then sessionStart.new = sessionStart.new + 1 end

    if db.notifyNew and newEver then
        ns.Toast(icon, "New catch!", itemText, GREEN, itemID, "new")
    elseif db.notifyNew and newInZone then
        ns.Toast(icon, "New in " .. ns.Stats.Zone(), itemText, GREEN, itemID, "new")
    elseif db.notifyRare and quality and quality >= 2 then
        ns.Toast(icon, "Rare catch!", itemText, { r, g, b }, itemID, "rare")
    end
end)

ns.Listen("SKILL_UP", function(rank, maxRank)
    if not ns.db.skillNotify then return end
    local text = ("Skill %d / %d"):format(rank, maxRank)
    if rank >= maxRank then text = text .. "  |cffff8c1a- train the next rank!|r" end
    ns.Toast(FISH_ICON, "Fishing skill up", text, ACCENT, nil, "skill")
end)

ns.Listen("SESSION_START", function()
    local s = ns.Stats.session
    sessionStart = { casts = s.casts, catches = s.catches, new = 0 }
end)

ns.Listen("SESSION_END", function()
    local start = sessionStart
    sessionStart = nil
    if not start or not ns.db.notifySummary then return end
    local s = ns.Stats.session
    local casts, catches = s.casts - start.casts, s.catches - start.catches
    if casts <= 0 then return end
    local text = ("%d casts  |cff999999·|r  %d fish  |cff999999·|r  %d%%"):format(
        casts, catches, math.floor(catches / casts * 100 + 0.5))
    if start.new > 0 then text = text .. ("  |cff999999·|r  |cff4cff73%d new|r"):format(start.new) end
    ns.Toast(FISH_ICON, "Fishing session over", text, GOLD, nil, "summary")
end)

function ns.TestToast()
    ns.Toast(134300, "New catch!", "|cff1eff00Example Fish|r x2", GREEN, nil, "new")
end

ns.Listen("LOGIN", function()
    local p = ns.db.toastPos or { "TOP", "TOP", 0, -160 }
    anchor:ClearAllPoints()
    anchor:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    RefreshAnchor()
end)
ns.Listen("OPTIONS", RefreshAnchor)
