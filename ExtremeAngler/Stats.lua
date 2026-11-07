-- Extreme Angler: catch statistics, per-zone loot data and fishing skill tracking.
local ADDON, ns = ...
local Stats = {}
ns.Stats = Stats

-- Since login
Stats.session = { casts = 0, catches = 0, items = {} }

local lastRank = nil

local function Zone()
    local z = GetRealZoneText and GetRealZoneText()
    if not z or z == "" then z = GetZoneText() end
    if not z or z == "" then z = "Unknown" end
    return z
end
Stats.Zone = Zone

-- ---------- Skill ----------
local FISHING_SKILL_NAME = PROFESSIONS_FISHING or ns.FISHING_NAME

-- Returns rank, maxRank, modifier (lure/gear bonus) or nil
function Stats.GetSkill()
    if GetProfessions and GetProfessionInfo then
        local _, _, _, fishing = GetProfessions()
        if fishing then
            local _, _, rank, maxRank, _, _, _, modifier = GetProfessionInfo(fishing)
            if rank then return rank, maxRank, modifier or 0 end
        end
    end
    if GetNumSkillLines and GetSkillLineInfo then
        for i = 1, GetNumSkillLines() do
            local name, isHeader, _, rank, _, modifier, maxRank = GetSkillLineInfo(i)
            if not isHeader and (name == FISHING_SKILL_NAME or name == ns.FISHING_NAME) then
                return rank, maxRank, modifier or 0
            end
        end
    end
end

local function CheckSkill()
    local rank, maxRank = Stats.GetSkill()
    if not rank then return end
    if lastRank and rank > lastRank and ns.db.skillNotify then
        local msg = ("Fishing skill up: |cff00ff00%d|r / %d"):format(rank, maxRank)
        if rank >= maxRank then msg = msg .. "  |cffff8000(cap reached - train the next rank!)|r" end
        ns.Print(msg)
    end
    if lastRank and rank > lastRank then ns.Fire("SKILL_UP", rank, maxRank) end
    lastRank = rank
    ns.Fire("STATS")
end

ns.On("SKILL_LINES_CHANGED", CheckSkill)
ns.Listen("LOGIN", function() C_Timer.After(2, CheckSkill) end)

-- ---------- Casts ----------
ns.Listen("FISH_START", function()
    Stats.session.casts = Stats.session.casts + 1
    ns.db.stats.casts = ns.db.stats.casts + 1
    ns.Fire("STATS")
end)

-- ---------- Loot ----------
-- Catches are counted from the "You receive loot: ..." chat messages instead of the
-- loot window, so it works with any auto-loot addon (e.g. Leatrix Plus fast loot)
-- that empties the loot window before it opens.
-- Each cast gets a number; the first loot message during the cast or within 5 s
-- after it ends counts as the catch, every message adds its items.

local function IsSecret(v) return issecretvalue and issecretvalue(v) end

local function ToPattern(fmt)
    if not fmt then return nil end
    local p = fmt:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
    -- positional args like "%1$s" (the "$" is already escaped to "%$" above)
    p = p:gsub("%%%d%%%$s", "(.+)"):gsub("%%%d%%%$d", "(%%d+)")
    p = p:gsub("%%s", "(.+)"):gsub("%%d", "(%%d+)")
    return "^" .. p .. "$"
end

-- Multiple-quantity patterns first, otherwise "(.+)" would swallow the "x2"
local LOOT_PATTERNS = {}
for _, fmt in ipairs({ LOOT_ITEM_SELF_MULTIPLE, LOOT_ITEM_PUSHED_SELF_MULTIPLE, LOOT_ITEM_SELF, LOOT_ITEM_PUSHED_SELF }) do
    local p = ToPattern(fmt)
    if p then LOOT_PATTERNS[#LOOT_PATTERNS + 1] = p end
end
if #LOOT_PATTERNS == 0 then
    LOOT_PATTERNS = { "^You receive loot: (.+)x(%d+)%.$", "^You receive loot: (.+)%.$" }
end

local function ParseLoot(msg)
    for _, p in ipairs(LOOT_PATTERNS) do
        local link, qty = msg:match(p)
        if link then return link, tonumber(qty) or 1 end
    end
end

local GetItemQualityByID = C_Item and C_Item.GetItemQualityByID

local castId, countedCastId = 0, 0
local castStopTime = 0
local lastBite = nil -- seconds from cast to click, for the cast that just ended

ns.Listen("FISH_START", function() castId = castId + 1 end)
ns.Listen("FISH_STOP", function()
    castStopTime = GetTime()
    lastBite = ns.channelStart and (castStopTime - ns.channelStart) or nil
end)

-- ---------- Bite timing ----------
-- Remembers how many seconds after casting the last catches happened, so the
-- timer bar can highlight the window where fish usually bite.
local MAX_BITES = 40
local DEFAULT_LO, DEFAULT_HI = 4, 18
local sorted = {}

local function RecordBite(t)
    if not t or t <= 0.5 then return end
    local bites = ns.db.bites
    bites[#bites + 1] = math.floor(t * 10 + 0.5) / 10
    if #bites > MAX_BITES then table.remove(bites, 1) end
end

function Stats.BiteZone()
    local bites = ns.db.bites
    local n = #bites
    if n < 5 then return DEFAULT_LO, DEFAULT_HI end
    for i = 1, n do sorted[i] = bites[i] end
    for i = n + 1, #sorted do sorted[i] = nil end
    table.sort(sorted)
    local lo = sorted[math.max(1, math.floor(n * 0.15 + 0.5))]
    local hi = sorted[math.min(n, math.floor(n * 0.85 + 0.5))]
    return lo, math.max(hi, lo + 1)
end

-- Keeps a zone's item table small: drops the rarest entries beyond the limit
local MAX_ZONE_ITEMS = 15
local function PruneZone(items)
    local count = 0
    for _ in pairs(items) do count = count + 1 end
    while count > MAX_ZONE_ITEMS do
        local minId, minCount
        for id, c in pairs(items) do
            if not minCount or c < minCount then minId, minCount = id, c end
        end
        items[minId] = nil
        count = count - 1
    end
end

ns.On("CHAT_MSG_LOOT", function(msg)
    if not msg or IsSecret(msg) then return end
    local inWindow = ns.fishing or (GetTime() - castStopTime) < 5
    if not inWindow or castId == 0 then return end

    local link, quantity = ParseLoot(msg)
    local id = link and tonumber(link:match("item:(%d+)"))
    if ns.db.debug then
        ns.Print(("loot msg: id=%s qty=%s cast=%d counted=%d"):format(
            tostring(id), tostring(quantity), castId, countedCastId))
    end
    if not id then return end

    local st = ns.db.stats
    local zoneName = Zone()
    local zone = st.zones[zoneName]
    if not zone then
        zone = { catches = 0, items = {} }
        st.zones[zoneName] = zone
    end

    -- First message of this cast = one catch
    if countedCastId ~= castId then
        countedCastId = castId
        Stats.session.catches = Stats.session.catches + 1
        st.catches = st.catches + 1
        zone.catches = zone.catches + 1
        RecordBite(lastBite)
    end

    local name = link:match("%[(.-)%]")
    local quality = GetItemQualityByID and GetItemQualityByID(id)
    if quality == nil then
        local old = st.names[id]
        quality = old and old.q
    end
    local info = st.names[id]
    if not info then
        info = {}
        st.names[id] = info
    end
    info.n = name or info.n
    info.q = quality
    local newEver = st.items[id] == nil
    st.items[id] = (st.items[id] or 0) + quantity
    local isNew = zone.items[id] == nil
    zone.items[id] = (zone.items[id] or 0) + quantity
    if isNew then PruneZone(zone.items) end
    Stats.session.items[id] = (Stats.session.items[id] or 0) + quantity
    ns.Fire("CATCH", id, quantity, isNew, newEver, quality)
    ns.Fire("STATS")
end)

-- ---------- Helpers for the panel ----------
-- Reuses the same tables on every call to avoid garbage
local topPool, topList = {}, {}
local function ByCount(a, b) return a.count > b.count end

function Stats.Top(items, n)
    local i = 0
    for id, count in pairs(items) do
        i = i + 1
        local e = topPool[i]
        if not e then
            e = {}
            topPool[i] = e
        end
        e.id, e.count = id, count
        topList[i] = e
    end
    for j = i + 1, #topList do topList[j] = nil end
    table.sort(topList, ByCount)
    for j = n + 1, #topList do topList[j] = nil end
    return topList
end

local GetItemNameByID = C_Item and C_Item.GetItemNameByID
local GetItemIconByID = (C_Item and C_Item.GetItemIconByID) or GetItemIcon

-- Returns name, icon, r, g, b
function Stats.ItemInfo(id)
    local info = ns.db.stats.names[id]
    local name = (info and info.n) or (GetItemNameByID and GetItemNameByID(id)) or ("item:" .. id)
    local q = info and info.q
    local c = q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    local icon = GetItemIconByID and GetItemIconByID(id) or 134400
    if c then return name, icon, c.r, c.g, c.b end
    return name, icon, 1, 1, 1
end

function Stats.Reset()
    ns.db.stats = { casts = 0, catches = 0, items = {}, zones = {}, names = {} }
    ns.db.bites = {}
    Stats.session = { casts = 0, catches = 0, items = {} }
    ns.Print("Statistics reset.")
    ns.Fire("STATS")
end
