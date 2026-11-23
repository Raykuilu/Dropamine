-- Dropamine 3.8.1 — mode « Endgame » (niveau max) : chasse aux objets et collection.
--   /drop chasse                  : liste des objets recherchés
--   /drop chasse ajouter [objet] [taux %]   (Maj+clic sur un objet pour insérer son lien)
--   /drop chasse retirer <n> · reset <n>
--   /drop mode auto|route|endgame : endgame force l'affichage « niveau 60 » (pour tester)
-- Rien ne tourne en continu : un seul événement (LOOT_OPENED), tout sous pcall,
-- valeurs secrètes écartées avant toute comparaison.
local ADDON, ns = ...
local Tr = ns.L or setmetatable({}, { __index = function(_, k) return k end })
local H = {}
ns.Hunt = H

local function N(v) return (ns.N and ns.N(v)) or tonumber(v) or 0 end
local function Plain(v) return v ~= nil and not (ns.IsSecret and ns.IsSecret(v)) end

------------------------------------------------------------------------------
-- Mode : auto (selon le niveau) | route | endgame (simulation)
------------------------------------------------------------------------------
function H.ModeSetting()
  local v = ns.db and ns.db.ui and ns.db.ui.progMode
  if v == "route" or v == "endgame" then return v end
  return "auto"
end
function H.Endgame()
  local m = H.ModeSetting()
  if m == "endgame" then return true end
  if m == "route" then return false end
  local lvl = N(ns.GetPlayerLevel and ns.GetPlayerLevel()) or 0
  local cap = N(ns.GetLevelCap and ns.GetLevelCap()) or 60
  return lvl > 0 and cap > 0 and lvl >= cap
end
function H.SetMode(v)
  if v ~= "auto" and v ~= "route" and v ~= "endgame" then return false end
  if ns.SetOpt then ns.SetOpt("progMode", v) end
  local PU = ns.ProgressUI
  if PU and PU.OnModeChanged then pcall(PU.OnModeChanged) end
  return true
end

------------------------------------------------------------------------------
-- Source de données : l'addon « Dungeon Journal » (lecture seule, facultatif).
-- Aucune table embarquée : l'index boss → objets est construit à la demande.
------------------------------------------------------------------------------
local function Fold(s)
  if ns.Fold then return ns.Fold(tostring(s or "")) end
  return tostring(s or ""):lower()
end
local function DJ()
  local t = _G.ForeverDungeonJournal_NS
  local db = t and t.DB
  return type(db) == "table" and db or nil
end
function H.HasSource() return DJ() ~= nil end

-- Cases de l'équipement : id, libellé, groupe d'emplacement
H.TILES = {
  { "head", "Tête", "Head" }, { "neck", "Cou", "Neck" }, { "shoulder", "Épaules", "Shoulder" },
  { "back", "Dos", "Back" }, { "chest", "Torse", "Chest" }, { "wrist", "Poignets", "Wrist" },
  { "hands", "Mains", "Hands" }, { "waist", "Taille", "Waist" }, { "legs", "Jambes", "Legs" },
  { "feet", "Pieds", "Feet" }, { "finger1", "Doigt", "Finger" }, { "finger2", "Doigt", "Finger" },
  { "trinket1", "Bijou", "Trinket" }, { "trinket2", "Bijou", "Trinket" }, { "weapon", "Arme", "Weapon" },
  { "offhand", "Main g.", "Offhand" }, { "ranged", "Distance", "Ranged" },
}
-- Libellé affiché d'une case (3.8.2) : pas via Tr[], « Taille » y vaut déjà « Size » (taille du panneau).
local TILE_EN = { head = "Head", neck = "Neck", shoulder = "Shoulder", back = "Back", chest = "Chest", wrist = "Wrist",
  hands = "Hands", waist = "Waist", legs = "Legs", feet = "Feet", finger1 = "Finger", finger2 = "Finger",
  trinket1 = "Trinket", trinket2 = "Trinket", weapon = "Weapon", offhand = "Off-hand", ranged = "Ranged" }
function H.TileLabel(t)
  if not t then return "" end
  if ns.LangCode and ns.LangCode() == "en" then return TILE_EN[t[1]] or t[3] or t[2] end
  return t[2]
end
local GROUP = {
  Head = "Head", Neck = "Neck", Shoulder = "Shoulder", Back = "Back", Chest = "Chest", Wrist = "Wrist", Hands = "Hands",
  Waist = "Waist", Legs = "Legs", Feet = "Feet", Finger = "Finger", Trinket = "Trinket",
  ["One-Hand"] = "Weapon", ["Two-Hand"] = "Weapon", ["Main Hand"] = "Weapon",
  ["Off Hand"] = "Offhand", ["Held In Off-hand"] = "Offhand", ["Held In Off-Hand"] = "Offhand",
  Ranged = "Ranged", Thrown = "Ranged", Relic = "Ranged",
}
local ARMOR_OF = {
  WARRIOR = "Plate", PALADIN = "Plate", HUNTER = "Mail", SHAMAN = "Mail", ROGUE = "Leather", DRUID = "Leather",
  PRIEST = "Cloth", MAGE = "Cloth", WARLOCK = "Cloth",
}
local idx
local function BuildIndex()
  if idx then return idx end
  local db = DJ()
  if not db then return nil end
  idx = { byId = {}, list = {} }
  for dname, d in pairs(db) do
    if type(d) == "table" and type(d.bosses) == "table" then
      local lvl = tonumber(tostring(d.level or ""):match("(%d+)%s*$")) or 0
      for _, b in ipairs(d.bosses) do
        if type(b) == "table" and type(b.loot) == "table" then
          for _, it in ipairs(b.loot) do
            local id, nm, slot, q = it[1], it[2], it[3], tonumber(it[4]) or 1
            local grp = GROUP[tostring(slot or ""):match("^([^,]+)") or ""]
            if type(id) == "number" and type(nm) == "string" and grp then
              local e = idx.byId[id]
              if not e then
                e = { id = id, name = nm, fold = Fold(nm), slot = slot, group = grp, q = q, src = {},
                  armor = tostring(slot):match(",%s*(%a+)%s*$") }
                idx.byId[id] = e
                idx.list[#idx.list + 1] = e
              end
              e.src[#e.src + 1] = { dungeon = dname, boss = b.name, level = lvl }
            elseif type(id) == "number" and not idx.byId[id] and type(nm) == "string" then
              -- objets hors équipement (matériaux, quêtes…) : utiles pour repérer la mort d'un boss
              idx.byId[id] = { id = id, name = nm, group = nil, q = q, src = { { dungeon = dname, boss = b.name, level = lvl } } }
            end
          end
        end
      end
    end
  end
  return idx
end
function H.SourceOf(id)
  local ix = BuildIndex()
  local e = ix and ix.byId[id]
  return e and e.src and e.src[1] or nil, e
end
local function FDJ() return _G.ForeverDungeonJournal_NS end
function H.LocDungeon(n)
  local f = FDJ()
  if f and f.LocalizeDungeonName and type(n) == "string" then
    local ok, r = pcall(f.LocalizeDungeonName, n)
    if ok and type(r) == "string" and r ~= "" then return r end
  end
  return n
end
function H.LocBoss(n)
  local f = FDJ()
  if f and f.LocalizeBossName and type(n) == "string" then
    local ok, r = pcall(f.LocalizeBossName, n)
    if ok and type(r) == "string" and r ~= "" then return r end
  end
  return n
end
local asked, nameCache, scanTip = {}, {}, nil
-- nom localisé lu dans le vrai tooltip de l'objet (même source que le Journal des donjons)
local function TipName(id)
  if nameCache[id] then return nameCache[id] end
  if not _G.CreateFrame then return nil end
  if not scanTip then
    scanTip = _G.CreateFrame("GameTooltip", "DropamineHuntNameScan", _G.UIParent, "GameTooltipTemplate")
  end
  local ok = pcall(function()
    scanTip:SetOwner(_G.UIParent, "ANCHOR_NONE")
    scanTip:ClearLines()
    scanTip:SetHyperlink("item:" .. tostring(id))
  end)
  local fs = ok and _G["DropamineHuntNameScanTextLeft1"]
  local t = fs and fs.GetText and fs:GetText()
  scanTip:Hide()
  if ns.IsSecret and ns.IsSecret(t) then return nil end
  if type(t) == "string" and t ~= "" and t ~= _G.RETRIEVING_ITEM_INFO and t ~= _G.UNKNOWN and t ~= _G.UNKNOWNOBJECT then
    nameCache[id] = t
    return t
  end
  return nil
end
function H.DisplayName(id, fallback)
  local tn = id and TipName(id)
  if tn then return tn end
  if id and type(_G.GetItemInfo) == "function" then
    local ok, n = pcall(_G.GetItemInfo, id)
    if ok and type(n) == "string" then return n end
    local CI = _G.C_Item
    if CI and CI.GetItemNameByID then
      local ok3, n3 = pcall(CI.GetItemNameByID, id)
      if ok3 and type(n3) == "string" and n3 ~= "" then return n3 end
    end
    -- le client Forever ne remplit pas toujours GetItemInfo : le tooltip de l'objet donne le nom localisé
    local TI = _G.C_TooltipInfo
    if TI and TI.GetItemByID then
      local ok2, data = pcall(TI.GetItemByID, id)
      local line = ok2 and type(data) == "table" and type(data.lines) == "table" and data.lines[1]
      if type(line) == "table" then
        if line.leftText == nil and _G.TooltipUtil and _G.TooltipUtil.SurfaceArgs then pcall(_G.TooltipUtil.SurfaceArgs, line) end
        local t = line.leftText
        if not (ns.IsSecret and ns.IsSecret(t)) and type(t) == "string" and t ~= "" and t ~= _G.RETRIEVING_ITEM_INFO then return t end
      end
    end
    -- pas encore en cache : on le demande au serveur, le nom localisé arrivera avec GET_ITEM_INFO_RECEIVED
    if not asked[id] then
      asked[id] = true
      local req = _G.C_Item and _G.C_Item.RequestLoadItemDataByID
      if req then pcall(req, id)
      elseif _G.Item and _G.Item.CreateFromItemID then
        pcall(function() _G.Item:CreateFromItemID(id):ContinueOnItemLoad(function() asked[id] = nil end) end)
      end
    end
    local g = _G.C_Item and _G.C_Item.GetItemNameByID
    if g then local ok2, n2 = pcall(g, id) if ok2 and type(n2) == "string" then return n2 end end
  end
  return fallback
end
do
  local pending
  ns.On("GET_ITEM_INFO_RECEIVED", function()
    if pending or not (_G.C_Timer and _G.C_Timer.After) then return end
    pending = true
    _G.C_Timer.After(0.5, function()
      pending = false
      if ns.ProgressUI and ns.ProgressUI.frame and ns.ProgressUI.frame:IsShown() then
        pcall(ns.ProgressUI.Refresh)
      end
    end)
  end)
end
function H.Icon(id)
  if id then
    local f = (_G.C_Item and _G.C_Item.GetItemIconByID) or _G.GetItemIcon
    if type(f) == "function" then
      local ok, tex = pcall(f, id)
      if ok and tex then return tex end
    end
  end
  return "Interface\\Icons\\INV_Misc_QuestionMark"
end
function H.PlayerArmor()
  local ok, _, cf = pcall(_G.UnitClass, "player")
  return ok and Plain(cf) and ARMOR_OF[cf] or nil
end

-- Candidats d'une case (ou recherche libre) : plus hauts donjons d'abord.
function H.Candidates(group, text, onlyMine, limit)
  local ix = BuildIndex()
  if not ix then return {}, false end
  local t = Fold(text or "")
  local mine = onlyMine and H.PlayerArmor() or nil
  local out = {}
  for _, e in ipairs(ix.list) do
    if (e.q or 1) >= 2 and (not group or e.group == group) then
      local ok = true
      if mine and e.armor and e.group ~= "Back" and e.armor ~= mine then ok = false end
      if ok and #t >= 2 then
        ok = e.fold:find(t, 1, true) ~= nil
        if not ok then
          local ln = H.DisplayName(e.id, nil)
          ok = ln ~= nil and Fold(ln):find(t, 1, true) ~= nil
        end
      end
      if ok then out[#out + 1] = e end
    end
  end
  table.sort(out, function(a, b)
    local la, lb = a.src[1].level or 0, b.src[1].level or 0
    if la ~= lb then return la > lb end
    if (a.q or 1) ~= (b.q or 1) then return (a.q or 1) > (b.q or 1) end
    return a.name < b.name
  end)
  local total = #out
  if limit and #out > limit then for i = #out, limit + 1, -1 do out[i] = nil end end
  return out, total
end

------------------------------------------------------------------------------
-- Données : objets recherchés (par personnage)
------------------------------------------------------------------------------
local MAX_ITEMS = 20
local function Store()
  local c = ns.CharDB and ns.CharDB()
  if type(c) ~= "table" then return nil end
  c.hunt = type(c.hunt) == "table" and c.hunt or {}
  c.hunt.items = type(c.hunt.items) == "table" and c.hunt.items or {}
  c.hunt.kills = type(c.hunt.kills) == "table" and c.hunt.kills or {}
  c.hunt.log = type(c.hunt.log) == "table" and c.hunt.log or {}
  return c.hunt
end
local function Attempts(s, it)
  if it.bossKey then return math.max(0, N(s.kills[it.bossKey]) - N(it.baseKills)) end
  return N(it.attempts)
end

function H.List()
  local s = Store()
  local out = {}
  if not s then return out end
  for i, it in ipairs(s.items) do
    out[#out + 1] = { i = i, id = it.id, name = H.DisplayName(it.id, it.name) or ("#" .. tostring(it.id)), rate = it.rate,
      attempts = Attempts(s, it), drops = N(it.drops), last = it.last, tile = it.tile, group = it.group,
      dungeon = H.LocDungeon(it.dungeon), boss = H.LocBoss(it.boss) }
  end
  return out
end
-- Range les objets sans case sur une case libre de leur emplacement ; si l'emplacement est plein,
-- le meilleur (qualité puis niveau de la source) garde la case, les autres restent dans la liste.
local function Rank(it)
  local _, e = H.SourceOf(it.id)
  local lvl = (e and e.src and e.src[1] and e.src[1].level) or 0
  return ((e and e.q) or 1) * 1000 + lvl
end
function H.AutoTile()
  local s = Store()
  if not s then return end
  local used = {}
  for _, it in ipairs(s.items) do if it.tile then used[it.tile] = it end end
  for _, it in ipairs(s.items) do
    if not it.tile and it.id then
      if not it.group then local _, e = H.SourceOf(it.id) it.group = e and e.group or nil end
      if it.group then
        local free, weakest
        for _, t in ipairs(H.TILES) do
          if t[3] == it.group then
            local o = used[t[1]]
            if not o then free = free or t[1]
            elseif not weakest or Rank(o) < Rank(used[weakest]) then weakest = t[1] end
          end
        end
        if free then it.tile = free used[free] = it
        elseif weakest and Rank(it) > Rank(used[weakest]) then
          used[weakest].tile = nil
          it.tile = weakest used[weakest] = it
        end
      end
    end
  end
end
function H.ByTile()
  pcall(H.AutoTile)
  local out = {}
  for _, it in ipairs(H.List()) do if it.tile then out[it.tile] = it end end
  return out
end

-- Chance cumulée d'en avoir eu au moins un : 1 − (1 − p)^n (si le taux est connu).
function H.Chance(it)
  local p = it and tonumber(it.rate)
  if not p or p <= 0 then return nil end
  if p >= 100 then return 1 end
  return 1 - (1 - p / 100) ^ (it.attempts or 0)
end

-- text : lien, ID, ou nom ; opts.tile : case de l'équipement
function H.Add(text, rate, opts)
  local s = Store()
  if not s then return nil, "db" end
  opts = opts or {}
  text = tostring(text or "")
  local id = tonumber(text:match("item:(%d+)")) or tonumber(text:match("^%s*(%d+)%s*$"))
  local name = text:match("%[(.-)%]")
  if not id then
    name = name or text:gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then return nil, "id" end
  end
  local src, e
  if id then
    src, e = H.SourceOf(id)
    if not name then name = (e and e.name) or H.DisplayName(id, nil) end
    if opts.src then src = opts.src end
  end
  if opts.tile then
    for i = #s.items, 1, -1 do if s.items[i].tile == opts.tile then table.remove(s.items, i) end end
  end
  for _, it in ipairs(s.items) do
    if (id and it.id == id) or (not id and it.id == nil and Fold(it.name) == Fold(name)) then return it, "dup" end
  end
  if #s.items >= MAX_ITEMS then return nil, "full" end
  local r = tonumber(rate)
  local it = { id = id, name = name, rate = (r and r > 0 and r <= 100) and r or nil, attempts = 0, drops = 0,
    added = (type(time) == "function" and time()) or 0, tile = opts.tile, group = e and e.group or nil }
  if src and e and #e.src == 1 or (src and opts.src) then
    it.dungeon, it.boss = src.dungeon, src.boss
    it.bossKey = src.dungeon .. "|" .. tostring(src.boss)
    it.baseKills = N(s.kills[it.bossKey])
  elseif src then
    it.dungeon, it.boss = src.dungeon, src.boss   -- plusieurs sources : affichage seul, tentatives par butin
  end
  s.items[#s.items + 1] = it
  return it
end
function H.Remove(i)
  local s = Store()
  if s and s.items[i] then table.remove(s.items, i) return true end
  return false
end
function H.ResetOne(i)
  local s = Store()
  local it = s and s.items[i]
  if it then
    it.attempts, it.drops, it.last = 0, 0, nil
    if it.bossKey then it.baseKills = N(s.kills[it.bossKey]) end
    return true
  end
  return false
end

------------------------------------------------------------------------------
-- Détection : fenêtre de butin + messages de chat (butin automatique)
------------------------------------------------------------------------------
H.lastLoot = {}
local function Quality(link)
  local ok, _, _, q = pcall(_G.GetItemInfo, link)
  return ok and tonumber(q) or 1
end
-- Favoris du Dungeon Journal (par personnage) -> objets à chasser
function H.Favourites()
  local db = _G.ForeverDungeonJournalCharacterDB
  local t = type(db) == "table" and db.favouriteItems
  local out = {}
  if type(t) ~= "table" then return out end
  for _, f in pairs(t) do
    if type(f) == "table" and tonumber(f.id) then out[#out + 1] = f end
  end
  table.sort(out, function(a, b) return (a.added or 0) < (b.added or 0) end)
  return out
end
function H.ImportFavourites()
  local added, dup, full = 0, 0, false
  for _, f in ipairs(H.Favourites()) do
    local it, why = H.Add("item:" .. tostring(f.id))
    if it and why == "dup" then dup = dup + 1
    elseif it then added = added + 1
    elseif why == "full" then full = true break end
  end
  return added, dup, full
end

function H.AddLast()
  local best
  for _, it in ipairs(H.lastLoot) do
    if not best or (it.q or 1) > (best.q or 1) then best = it end
  end
  if not best then return nil, "none" end
  return H.Add(best.link)
end

local function Matches(it, id, linkName)
  if it.id then return id ~= nil and it.id == id end
  return linkName ~= nil and Fold(linkName) == Fold(it.name)
end
-- Clic sur la notification : ouvre la fiche de l'objet (comme un lien dans le chat, avec comparaison).
-- Les toasts sont recyclés : le lien expire après 12 s pour qu'un clic ne rouvre jamais un ancien objet.
local function MakeClickable(f, id, nm)
  if not (f and f.EnableMouse and id) then return end
  -- 3.8.2 : le clic est traité par le gestionnaire commun des toasts (UI:WireDropMouse), reposé à chaque
  -- affichage ; un SetScript ici était écrasé dès que le cadre était recyclé (ça ne marchait qu'une fois).
  f._itemClick = { id = id, nm = nm, till = ((_G.GetTime and _G.GetTime()) or 0) + 12 }
  pcall(f.EnableMouse, f, true)
end
H.MakeClickable = MakeClickable
local function Found(s, it)
  local stamp = (type(time) == "function" and time()) or 0
  if it.last and stamp - it.last <= 2 then return end
  it.drops = N(it.drops) + 1
  it.last = stamp
  local P = ns.Progress
  if P and P.C then
    pcall(function()
      local R = P.C().records
      R.huntFound = (N(R.huntFound) or 0) + 1
      local tries = N(Attempts(s, it)) or 0
      if tries > (N(R.huntTries) or 0) then R.huntTries = tries end
      P.CheckAchievements("hunt")
    end)
  end
  if P and P.Toast and ns.Opt("huntAlert") then
    local okT, tf = pcall(P.Toast, Tr["Objet recherché trouvé : "] .. tostring(H.DisplayName(it.id, it.name) or it.id),
      string.format(Tr["Après %d tentatives"], Attempts(s, it)), { kind = "achievement", variant = "gold", titleColor = H.QualityRGB(it.id) },
      "hunt-" .. tostring(it.id or it.name), true, it.id and H.Icon(it.id) or nil)
    if okT then MakeClickable(tf, it.id, it.name) end
  end
end
local function Refresh()
  local PU = ns.ProgressUI
  if PU and PU.RequestRefresh then pcall(PU.RequestRefresh) end
end

local function OnLoot()
  local s = Store()
  if not s then return end
  local okF, fishing = pcall(function() return _G.IsFishingLoot and _G.IsFishingLoot() end)
  if okF and Plain(fishing) and fishing then return end
  local okN, n = pcall(_G.GetNumLootItems or function() return 0 end)
  n = (okN and Plain(n)) and N(n) or 0
  local found = {}
  H.lastLoot = {}
  for slot = 1, n do
    local okL, link = pcall(_G.GetLootSlotLink, slot)
    if okL and Plain(link) and type(link) == "string" then
      local id = tonumber(link:match("item:(%d+)"))
      if id then
        if s.log and idx and idx.byId[id] then s.log[id] = true end
        found[#found + 1] = { id = id, name = link:match("%[(.-)%]") }
        H.lastLoot[#H.lastLoot + 1] = { id = id, link = link, q = Quality(link) }
      end
    end
  end
  for _, it in ipairs(s.items) do
    if not it.bossKey then it.attempts = N(it.attempts) + 1 end
    for _, f in ipairs(found) do
      if Matches(it, f.id, f.name) then Found(s, it) break end
    end
  end
  if #s.items > 0 then Refresh() end
end

local selfPatterns
local function SelfPatterns()
  if selfPatterns then return selfPatterns end
  selfPatterns = {}
  for _, g in ipairs({ "LOOT_ITEM_SELF", "LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_PUSHED_SELF", "LOOT_ITEM_PUSHED_SELF_MULTIPLE" }) do
    local f = _G[g]
    if type(f) == "string" then
      local pat = f:gsub("([%^%$%(%)%.%[%]%*%+%-%?])", "%%%1")
      pat = pat:gsub("%%s", "(.+)")
      pat = pat:gsub("%%d", "%%d+")
      selfPatterns[#selfPatterns + 1] = "^" .. pat .. "$"
    end
  end
  return selfPatterns
end
local killAt = {}
-- couleur du lien -> rang (3 rare, 4 épique, 5 légendaire, 6 artefact)
local RARE_COLOR = { ["0070dd"] = { 3, "Rare" }, a335ee = { 4, "Épique" }, ff8000 = { 5, "Légendaire" }, e6cc80 = { 6, "Artefact" } }
local rareAt = {}
-- 3.8.2 : alertes de butin par qualité cochée (Options, liste à cases : rare, épique, légendaire ; pas d'inhabituel,
-- trop fréquent et souvent pas encore en cache), enregistrées en chiffres : « 45 » = épique + légendaire.
-- Reprise des anciens réglages : alerte décochée → aucune ; « à partir de rare » → rare, épique, légendaire.
H.LOOT_QUALITIES = { 3, 4, 5 }
function H.LootQualString()
  local ui = ns.db and ns.db.ui
  if not ui then return "45" end
  local v = ui.lootQual
  if type(v) ~= "string" then
    if ui.rareAlert == false then v = "" elseif ui.rareMin == "rare" then v = "345" else v = "45" end
    ui.lootQual = v
  end
  return v
end
function H.SetLootQualString(v)
  v = tostring(v or "")
  local out = ""
  for _, q in ipairs(H.LOOT_QUALITIES) do if v:find(tostring(q), 1, true) then out = out .. q end end
  local ui = ns.db and ns.db.ui
  if ui then ui.lootQual = out end
  return out
end
function H.LootQualityOn(q)
  if not q then return false end
  if q > 5 then q = 5 end  -- artefact : suit le légendaire
  return H.LootQualString():find(tostring(q), 1, true) ~= nil
end
-- Objet d'exemple réel d'une qualité (bouton Tester) : Thunderfury pour légendaire, sinon une arme
-- de cette qualité du Journal des donjons (le plus haut donjon, puis le plus petit id : toujours le même).
local SAMPLE_FIXED = { [5] = 19019 }
function H.SampleItem(q)
  if SAMPLE_FIXED[q] then return SAMPLE_FIXED[q] end
  local ix = BuildIndex()
  local best, bestLvl
  for _, e in ipairs(ix and ix.list or {}) do
    if e.q == q and e.group == "Weapon" then
      local lvl = (e.src and e.src[1] and e.src[1].level) or 0
      if not best or lvl > bestLvl or (lvl == bestLvl and e.id < best.id) then best, bestLvl = e, lvl end
    end
  end
  return best and best.id or nil, best and best.name or nil
end
function H.LootQualityTop()
  local s, top = H.LootQualString(), nil
  for _, q in ipairs(H.LOOT_QUALITIES) do if s:find(tostring(q), 1, true) then top = q end end
  return top
end
-- toast d'alerte : force = test (ignore le seuil et le délai)
local RARE_RGB = { [3] = { 0, 0.44, 0.87 }, [4] = { 0.64, 0.21, 0.93 }, [5] = { 1, 0.5, 0 }, [6] = { 0.9, 0.8, 0.5 } }
-- 3.8.2 : couleur de qualité d'un objet (titre des toasts de chasse et de butin), nil si inconnue
local QUALITY_RGB = { [0] = { 0.62, 0.62, 0.62 }, [1] = { 1, 1, 1 }, [2] = { 0.12, 1, 0 } }
function H.QualityOf(id)
  if not id then return nil end
  local okQ, _, _, q = pcall(_G.GetItemInfo, id)
  q = okQ and tonumber(q)
  if not q and _G.C_Item and _G.C_Item.GetItemQualityByID then
    local ok2, q2 = pcall(_G.C_Item.GetItemQualityByID, id)
    q = ok2 and tonumber(q2)
  end
  if not q then
    local _, e = H.SourceOf(id)
    q = e and tonumber(e.q)
  end
  return q
end
function H.QualityRGB(id, q)
  q = q or H.QualityOf(id)
  if not q then return nil end
  local C = _G.ITEM_QUALITY_COLORS and _G.ITEM_QUALITY_COLORS[q]
  if C and C.r then return { C.r, C.g, C.b } end
  return RARE_RGB[q] or QUALITY_RGB[q]
end
local RARE_TITLE = { [3] = "Butin rare : ", [4] = "Butin épique : ", [5] = "Butin légendaire : ", [6] = "Butin d'artefact : " }
function H.RareAlert(id, nm, force, tier, retried)
  local now = (type(time) == "function" and time()) or 0
  if not retried then
    if not force and now - (rareAt[id] or 0) <= 2 then return end
    rareAt[id] = now
  end
  local P = ns.Progress
  if not (P and P.Toast) then return end
  -- objet pas encore en cache (ex. /drop rare <id>) : on demande ses données et on réessaie une fois
  local name = H.DisplayName(id, nm) or nm
  if not name and not retried and _G.C_Timer and _G.C_Timer.After then
    local CI = _G.C_Item
    if CI and CI.RequestLoadItemDataByID then pcall(CI.RequestLoadItemDataByID, id) end
    _G.C_Timer.After(0.6, function() H.RareAlert(id, nm, force, tier, true) end)
    return
  end
  if not tier then
    tier = H.QualityOf(id) or 4
    if tier < 3 then tier = 3 end
    if tier > 6 then tier = 6 end
  end
  local src = H.SourceOf(id)
  local sub = src and (tostring(H.LocBoss(src.boss)) .. " · " .. tostring(H.LocDungeon(src.dungeon))) or Tr[RARE_TITLE[tier] and RARE_TITLE[tier]:gsub(" : $", "") or "Butin rare"]
  local okT, tf = pcall(P.Toast, Tr[RARE_TITLE[tier] or RARE_TITLE[4]] .. (name or ("#" .. tostring(id))), sub,
    { kind = "achievement", variant = "gold", titleColor = H.QualityRGB(id, tier) or RARE_RGB[4] }, "rare-" .. id, true, H.Icon(id))
  if okT then MakeClickable(tf, id, name or nm) end
end
local function OnChatLoot(msg, author)
  if not Plain(msg) or type(msg) ~= "string" then return end
  local link = msg:match("(|c%x+|Hitem:.-|h%[.-%]|h|r)")
  local id = link and tonumber(link:match("item:(%d+)"))
  if not id then return end
  local s = Store()
  if not s then return end
  local now = (type(time) == "function" and time()) or 0
  -- un boss est mort si un objet de sa table tombe (pour n'importe quel joueur du groupe)
  local _, e = H.SourceOf(id)
  if e and #e.src == 1 and e.q and e.q >= 2 then
    local key = e.src[1].dungeon .. "|" .. tostring(e.src[1].boss)
    if now - (killAt[key] or 0) > 20 then
      s.kills[key] = N(s.kills[key]) + 1
    end
    killAt[key] = now
  end
  local mine = false
  for _, pat in ipairs(SelfPatterns()) do if msg:find(pat) then mine = true break end end
  if not mine and Plain(author) and type(author) == "string" and author ~= "" then
    local ok, me = pcall(_G.UnitName, "player")
    mine = ok and Plain(me) and me == author
  end
  if not mine then Refresh() return end
  local nm = link:match("%[(.-)%]")
  if e then s.log[id] = true end
  H.lastLoot[#H.lastLoot + 1] = { id = id, link = link, q = Quality(link) }
  local tracked = false
  for _, it in ipairs(s.items) do
    if Matches(it, id, nm) then Found(s, it) tracked = true end
  end
  -- alerte de butin : qualités cochées (couleur du lien, fiable même si l'objet n'est pas en cache)
  if not tracked then
    local col = (link:match("|cff(%x%x%x%x%x%x)") or ""):lower()
    local tier = RARE_COLOR[col]
    if tier and H.LootQualityOn(tier[1]) then H.RareAlert(id, nm, false, tier[1]) end
  end
  Refresh()
end
if ns.On then
  ns.On("LOOT_OPENED", function() pcall(OnLoot) end)
  ns.On("CHAT_MSG_LOOT", function(_, ...) pcall(OnChatLoot, ...) end)
end

------------------------------------------------------------------------------
-- Collection log : objets de donjon obtenus (par personnage), lus avec Dungeon Journal
------------------------------------------------------------------------------
-- Ce que le personnage porte ou a en sac : marqué obtenu (au plus une fois toutes les 30 s).
local lastScan = 0
function H.ScanOwned()
  local ix = BuildIndex()
  local s = Store()
  if not (ix and s) then return end
  local now = (type(GetTime) == "function" and GetTime()) or 0
  if now - lastScan < 30 and lastScan > 0 then return end
  lastScan = now
  local function mark(id)
    if Plain(id) and type(id) == "number" and ix.byId[id] then s.log[id] = true end
  end
  if type(_G.GetInventoryItemID) == "function" then
    for slot = 1, 19 do local ok, id = pcall(_G.GetInventoryItemID, "player", slot) if ok then mark(id) end end
  end
  local C = _G.C_Container
  local getN = (C and C.GetContainerNumSlots) or _G.GetContainerNumSlots
  local getId = (C and C.GetContainerItemID) or _G.GetContainerItemID
  if type(getN) == "function" and type(getId) == "function" then
    for bag = 0, 4 do
      local okN, n = pcall(getN, bag)
      if okN and type(n) == "number" then
        for slot = 1, n do local ok, id = pcall(getId, bag, slot) if ok then mark(id) end end
      end
    end
  end
end

local RAIDS = { ["Molten Core"] = true, ["Blackwing Lair"] = true, ["Zul'Gurub"] = true, ["Onyxia's Lair"] = true,
  ["Ruins of Ahn'Qiraj"] = true, ["Temple of Ahn'Qiraj"] = true, ["Naxxramas"] = true }
local BRACKETS = { { "Donjons niv. 10-29", 0, 29 }, { "Donjons niv. 30-49", 30, 49 }, { "Donjons niv. 50-60", 50, 999 } }

-- { { header = "…", entries = { { key, label, x, y, bosses | stat } } } }
function H.LogSections()
  local s = Store()
  local log = s and s.log or {}
  local ix = BuildIndex()
  local db = ix and DJ()
  local secs = {}
  if db then
    local buckets, raids = {}, {}
    for i = 1, #BRACKETS do buckets[i] = {} end
    for dname, d in pairs(db) do
      if type(d) == "table" and type(d.bosses) == "table" then
        local lvl = tonumber(tostring(d.level or ""):match("(%d+)%s*$")) or 0
        local bosses, x, y, seen = {}, 0, 0, {}
        for _, b in ipairs(d.bosses) do
          local items = {}
          for _, it in ipairs(type(b) == "table" and b.loot or {}) do
            local id, nm, q = it[1], it[2], tonumber(it[4]) or 1
            local e = ix.byId[id]
            if e and e.group and q >= 2 then
              local got = log[id] and true or false
              items[#items + 1] = { id = id, name = nm, got = got }
              if not seen[id] then seen[id] = true y = y + 1 if got then x = x + 1 end end
            end
          end
          if #items > 0 then
            local st = Store()
            bosses[#bosses + 1] = { name = H.LocBoss(b.name), items = items, kills = N(st and st.kills and st.kills[dname .. "|" .. tostring(b.name)]) }
          end
        end
        if y > 0 then
          local entry = { key = "dj:" .. dname, label = H.LocDungeon(dname), x = x, y = y, bosses = bosses, level = lvl }
          if RAIDS[dname] then raids[#raids + 1] = entry
          else
            for i, br in ipairs(BRACKETS) do
              if lvl >= br[2] and lvl <= br[3] then buckets[i][#buckets[i] + 1] = entry break end
            end
          end
        end
      end
    end
    local function sortE(t) table.sort(t, function(a, b) if a.level ~= b.level then return a.level < b.level end return a.label < b.label end) end
    for i, br in ipairs(BRACKETS) do
      if #buckets[i] > 0 then sortE(buckets[i]) secs[#secs + 1] = { header = Tr[br[1]], entries = buckets[i] } end
    end
    if #raids > 0 then sortE(raids) secs[#secs + 1] = { header = Tr["Raids"], entries = raids } end
  end
  -- métiers, découvertes et général : repris des statistiques existantes
  local prof, disc, gen = {}, {}, {}
  for _, r in ipairs(H.CollectionRows()) do
    local e = { key = "st:" .. r.label, label = r.label, x = r.x, y = r.y, stat = true, cat = r.cat, skill = r.skill, code = r.code, kind = r.kind, approx = r.approx }
    local lab = tostring(r.label)
    if lab:find("^" .. Tr["Recettes "]) then prof[#prof + 1] = e
    elseif r.cat == 2 or lab == Tr["Nœuds appris"] then disc[#disc + 1] = e
    else gen[#gen + 1] = e end
  end
  if #prof > 0 then secs[#secs + 1] = { header = Tr["Métiers"], entries = prof } end
  if #disc > 0 then secs[#secs + 1] = { header = Tr["Découvertes"], entries = disc } end
  if #gen > 0 then secs[#secs + 1] = { header = Tr["Général"], entries = gen } end
  return secs
end

------------------------------------------------------------------------------
-- Collection : lignes « X / Y » pour l'onglet Collection
------------------------------------------------------------------------------
function H.CollectionRows()
  local rows = {}
  local snap = ns.UI and ns.UI.snapshot
  -- compétences au plafond
  local capped, count = 0, 0
  for _, t in ipairs((snap and snap.tiles) or {}) do
    if t.inTotal and t.kind ~= "level" then
      local cap = N(t.apiMax)
      if cap > 0 then
        count = count + 1
        if N(t.current) >= cap then capped = capped + 1 end
      end
    end
  end
  if count > 0 then rows[#rows + 1] = { label = Tr["Au plafond"], x = capped, y = count, cat = 3 } end
  -- succès
  local P = ns.Progress
  if P and P.UnlockedCount then
    local ok, got, all = pcall(P.UnlockedCount)
    if ok and all and all > 0 then rows[#rows + 1] = { label = Tr["Succès"], x = got, y = all, cat = 1 } end
  end
  -- scanner
  local Sc = ns.Scanner
  local okD, db = pcall(Sc and Sc.DB or function() return nil end)
  if okD and type(db) == "table" then
    local meta = (ns.ScannerDB and ns.ScannerDB.meta) or {}
    local nc, skin, nodes = 0, 0, 0
    for _, c in pairs(db.creatures or {}) do
      nc = nc + 1
      if type(c.skills) == "table" and N(c.skills.skinning) > 0 then skin = skin + 1 end
    end
    for _ in pairs(db.nodes or {}) do nodes = nodes + 1 end
    rows[#rows + 1] = { label = Tr["Bestiaire"], x = nc, y = N(meta.nDropNpcs), cat = 2, kind = "creatures" }
    rows[#rows + 1] = { label = Tr["Créatures dépeçables"], x = skin, y = N(meta.nSkinNpcs), cat = 2, kind = "skin" }
    local cdb = ns.CharDB and ns.CharDB()
    -- Cuisine et Secourisme : totaux de la base embarquée. Autres métiers : totaux relevés par l'auteur (nov. 2026).
    local names = { cooking = { "Cuisine", "c" }, firstaid = { "Secourisme", "f" },
      alchemy = { "Alchimie", nil, 186 }, blacksmithing = { "Forge", nil, 452 }, enchanting = { "Enchantement", nil, 229 },
      engineering = { "Ingénierie", nil, 264 }, leatherworking = { "Travail du cuir", nil, 512 },
      tailoring = { "Couture", nil, 422 }, mining = { "Minage", nil, 17 },
      herbalism = { "Herboristerie", nil, 3 }, skinning = { "Dépeçage", nil, 3 }, fishing = { "Pêche", nil, 3 } }
    -- seulement les métiers que le personnage a appris (une tuile de métier existe dans la grille)
    local learned
    if snap then
      learned = {}
      for _, t in ipairs(snap.allTiles or snap.tiles or {}) do
        if t.id and not t.placeholder and (t.kind == "profession" or t.kind == "secondary") then learned[t.id] = true end
      end
      if next(learned) == nil then learned = nil end
    end
    local totals = {}
    if ns.ScannerDB and type(ns.ScannerDB.recipes) == "table" then
      for _, raw in pairs(ns.ScannerDB.recipes) do
        local code = tostring(raw):match("^([^|]*)")
        if code then totals[code] = (totals[code] or 0) + 1 end
      end
    end
    for id, r in pairs((cdb and cdb.recipes) or {}) do
      local nm = names[id]
      if nm and type(r) == "table" and (not learned or learned[id]) then
        local y = nm[2] and (totals[nm[2]] or 0) or nm[3]
        rows[#rows + 1] = { label = Tr["Recettes "] .. Tr[nm[1]], x = r.list and #r.list or 0, y = y, cat = 3, skill = id, code = nm[2] }
      end
    end
  end
  -- paliers du total
  if ns.Milestones and snap then
    local total, tmax = N(snap.total), N(snap.totalMax or ns.TOTAL_MAX)
    local passed = ns.Milestones(total, tmax)
    local list = 1 + 5
    rows[#rows + 1] = { label = Tr["Paliers du total"], x = #passed, y = list, cat = 1 }
  end
  return rows
end

-- Recettes de la base (Cuisine, Secourisme) que le personnage ne connaît pas encore, par niveau requis.
-- src : t = entraîneur, b = appris de base, - = autre (butin, quête ou vendeur : la base ne précise pas).
function H.MissingRecipes(skill, code)
  local SD = ns.ScannerDB
  if not (SD and type(SD.recipes) == "table") then return nil, "nodata" end
  local cdb = ns.CharDB and ns.CharDB()
  local rec = cdb and cdb.recipes and cdb.recipes[skill]
  if not (rec and type(rec.list) == "table" and #rec.list > 0) then return nil, "noread" end
  local known = {}
  for _, r in ipairs(rec.list) do if r.name then known[ns.Fold(r.name)] = true end end
  local out = {}
  for _, raw in pairs(SD.recipes) do
    local c2, lvl, en, fr, src = tostring(raw):match("^([^|]*)|([^|]*)|[^|]*|[^|]*|([^|]*)|([^|]*)|([^|]*)")
    if c2 == code and en then
      local nm = (ns.GameName and ns.GameName(en, fr)) or fr or en
      if not (known[ns.Fold(nm)] or known[ns.Fold(en)] or known[ns.Fold(fr or "")]) then
        out[#out + 1] = { name = nm, lvl = tonumber(lvl) or 0, src = src }
      end
    end
  end
  table.sort(out, function(a, b) if a.lvl ~= b.lvl then return a.lvl < b.lvl end return a.name < b.name end)
  return out
end
-- Créatures (butin) ou dépeçables apprises, par tranche de 10 niveaux : { lo, hi, x, y }.
function H.LevelSummary(kind)
  local SD = ns.ScannerDB
  local src = SD and ((kind == "skin") and SD.skin or SD.drops)
  if not (SD and type(SD.npcs) == "table" and type(src) == "table") then return nil end
  local okD, db = pcall(ns.Scanner and ns.Scanner.DB or function() return nil end)
  local seen = (okD and type(db) == "table" and db.creatures) or {}
  local out = {}
  for i = 1, 6 do out[i] = { lo = (i - 1) * 10 + 1, hi = i * 10, x = 0, y = 0 } end
  for id in pairs(src) do
    local raw = SD.npcs[id]
    local lvl = raw and tonumber(tostring(raw):match("^[^|]*|[^|]*|(%d+)"))
    if lvl and lvl > 0 then
      local b = out[math.min(6, math.floor((lvl - 1) / 10) + 1)]
      b.y = b.y + 1
      local c = seen[id]
      if c and (kind ~= "skin" or (type(c.skills) == "table" and N(c.skills.skinning) > 0)) then b.x = b.x + 1 end
    end
  end
  return out
end

------------------------------------------------------------------------------
-- Commandes
------------------------------------------------------------------------------
ns.SlashExt = ns.SlashExt or {}
local function Out(lines)
  local DW = ns.DebugWindow
  if DW and DW.Show and pcall(DW.Show, lines) then return end
  for _, l in ipairs(lines) do if ns.Print then ns.Print(l) end end
end
local function ListLines()
  local lines = {}
  for _, it in ipairs(H.List()) do
    local ch = H.Chance({ rate = it.rate, attempts = it.attempts })
    lines[#lines + 1] = string.format("%d. %s — %d %s, %d %s%s", it.i, tostring(it.name), it.attempts, Tr["tentatives"],
      it.drops, Tr["trouvé(s)"], ch and string.format(" · %d %%", math.floor(ch * 100 + 0.5)) or "")
  end
  if #lines == 0 then lines[1] = Tr["Aucun objet recherché. /drop chasse ajouter [objet] [taux %]"] end
  return lines
end
function H.LogTotals()
  local x, y = 0, 0
  for _, sec in ipairs(H.LogSections()) do
    for _, e in ipairs(sec.entries) do if not e.stat then x, y = x + e.x, y + e.y end end
  end
  return x, y
end
-- diagnostic : /drop item <id> montre ce que chaque source de nom répond
ns.SlashExt.item = function(rest)
  local id = tonumber(rest or "")
  if not id then ns.Print("/drop item <id>") return end
  local function show(lbl, ok, v) ns.Print(lbl .. " : " .. (ok and tostring(v) or "erreur")) end
  local ok, n = pcall(_G.GetItemInfo, id) show("GetItemInfo", ok, n)
  local CI = _G.C_Item
  if CI and CI.GetItemNameByID then local o, v = pcall(CI.GetItemNameByID, id) show("C_Item.GetItemNameByID", o, v) end
  local TI = _G.C_TooltipInfo
  if TI and TI.GetItemByID then
    local o, d = pcall(TI.GetItemByID, id)
    local l = o and type(d) == "table" and d.lines and d.lines[1]
    show("Tooltip ligne 1", o, l and (l.leftText or "(nil)") or "(aucune donnée)")
  end
  show("DisplayName", true, H.DisplayName(id, "(fallback)"))
end
-- test : /drop rare <lien ou id> montre l'alerte de butin rare pour cet objet (sans toucher au journal)
ns.SlashExt.rare = function(rest)
  rest = rest or ""
  local id = tonumber(rest:match("item:(%d+)")) or tonumber(rest:match("^%s*(%d+)%s*$"))
  if not id then if ns.Print then ns.Print(Tr["/drop rare <lien ou id> : teste l'alerte de butin rare"]) end return end
  H.RareAlert(id, rest:match("%[(.-)%]"), true)
end
ns.SlashExt.chasse = function(rest)
  rest = rest or ""
  local sub, arg = rest:match("^(%S*)%s*(.-)$")
  sub = (sub or ""):lower()
  if sub == "favoris" or sub == "fav" then
    local a, d, f = H.ImportFavourites()
    ns.Print(string.format(Tr["Favoris du Journal : %d ajoutés, %d déjà suivis."], a, d) .. (f and (" " .. Tr["Liste pleine (20 objets maximum)."]) or ""))
    return
  end
  if sub == "test" then
    local P = ns.Progress
    if P and P.Toast then
      -- exemple : le premier objet de la liste de chasse (nom localisé), sinon un nom générique traduit
      local first = H.List()[1]
      local okT, tf = pcall(P.Toast, Tr["Objet recherché trouvé : "] .. ((first and first.name) or Tr["Sifflet de chien"]), string.format(Tr["Après %d tentatives"], 12),
        { kind = "achievement", variant = "gold", titleColor = first and H.QualityRGB(first.id) or nil }, "hunt-test", true, (first and first.id) and H.Icon(first.id) or nil)
      if okT and first and first.id then MakeClickable(tf, first.id, first.name) end
    end
    return
  end
  if sub == "ajouter" or sub == "add" then
    local link = arg:match("(|c.-|r)") or arg:match("(item:%d+)")
    local tail = arg
    if link then
      local i, j = arg:find(link, 1, true)
      tail = (arg:sub(1, i - 1) .. " " .. arg:sub(j + 1))
    else
      local id, rest2 = arg:match("^%s*(%d+)%s*(.*)$")
      if id then link, tail = id, rest2 end
    end
    local num = tail:match("([%d%.,]+)")
    local rate = num and tonumber((num:gsub(",", ".")))
    local it, why = H.Add(link or arg, rate)
    if not it then
      if ns.Print then ns.Print(why == "full" and Tr["Liste pleine (8 objets maximum)."] or Tr["Objet non reconnu : Maj+clic sur l'objet pour insérer son lien."]) end
    elseif ns.Print then
      ns.Print((why == "dup" and Tr["Déjà suivi : "] or Tr["Suivi : "]) .. tostring(it.name or it.id))
    end
  elseif sub == "retirer" or sub == "remove" then
    if ns.Print then ns.Print(H.Remove(tonumber(arg) or 0) and Tr["Retiré."] or Tr["Numéro inconnu."]) end
  elseif sub == "reset" then
    if ns.Print then ns.Print(H.ResetOne(tonumber(arg) or 0) and Tr["Compteur remis à zéro."] or Tr["Numéro inconnu."]) end
  else
    Out(ListLines())
    return
  end
  local PU = ns.ProgressUI
  if PU and PU.RequestRefresh then pcall(PU.RequestRefresh) end
end
ns.SlashExt.mode = function(rest)
  local v = (rest or ""):lower():match("^%s*(%S*)")
  if v == "" then
    if ns.Print then ns.Print(Tr["Mode : "] .. H.ModeSetting() .. (H.Endgame() and " (endgame)" or " (route)")) end
    return
  end
  if not H.SetMode(v) and ns.Print then ns.Print("/drop mode auto|route|endgame") end
  if ns.Print then ns.Print(Tr["Mode : "] .. H.ModeSetting() .. (H.Endgame() and " (endgame)" or " (route)")) end
end
ns.HelpExt = ns.HelpExt or {}
ns.HelpExt[#ns.HelpExt + 1] = "/drop mode auto|route|endgame : onglets de niveau max (endgame = simulation)"
ns.HelpExt[#ns.HelpExt + 1] = "/drop chasse [ajouter|retirer|reset] : objets recherchés et tentatives"

-- (3.8.1 : l'option « Mode de la fenêtre Progression » est retirée des réglages ; /drop mode reste pour tester)
