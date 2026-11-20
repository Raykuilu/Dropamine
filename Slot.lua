-- Dropamine 3.6.3 : le puits de la fiole dit ce que tu fais maintenant.
-- Un seul gestionnaire possède la texture de la goutte. Un symbole à la fois,
-- selon la priorité mort > vol / trajet > (épée de combat, si ce style est choisi) >
-- AFK > sacs pleins > pêche > nage > usure (option, défaut off) > z de repos > goutte. Le liquide de combat (rouge + bleu,
-- vert qui s'efface) est une couche derrière le symbole. Style réglable :
-- Bulles (défaut, maquette A), Épée (maquette C) ou Désactivé.
-- Feuilles 8×4 de 64 px, OnUpdate cadencé, pas d'AnimationGroups.
local ADDON, ns = ...
local Tr = ns.L
local S = {}
ns.Slot = S

S.ORDER_SWORD   = { "death", "flight", "combat", "afk", "bags", "fishing", "swimming", "durability", "sleepingbag", "rested" }
S.ORDER_DEFAULT = { "death", "flight", "afk", "bags", "fishing", "swimming", "durability", "sleepingbag", "rested" }

local MEDIA = "Interface\\AddOns\\Dropamine\\Media\\"
S.SHEETS = {
  death     = { tex = MEDIA .. "Death-Sheet",    frames = 32, step = 0.10 },
  combat    = { tex = MEDIA .. "Combat-C-Sheet", frames = 32, step = 0.10 },
  afk       = { tex = MEDIA .. "Afk-Sheet",      frames = 32, step = 0.10 },
  fishing   = { tex = MEDIA .. "Fishing-Sheet",  frames = 32, step = 0.10 },
  swimming  = { tex = MEDIA .. "Swimming-Sheet", frames = 32, step = 0.10 },
  bags      = { tex = MEDIA .. "Bags-Sheet",     frames = 32, step = 0.10 },
  durability= { tex = MEDIA .. "Durability-Sheet", frames = 32, step = 0.12 },
}
S.TRAINER_SHEET = MEDIA .. "Trainer-Sheet"
S.COMBAT_A_SHEET = MEDIA .. "Combat-A-Sheet"
S.WELL_RESTED_SPELL = 429959  -- buff résultant (Bien reposé / Well-Rested), pas la charge
S.UNROLL_BAG_SPELL = 429961  -- sort « Unroll Bag » : déploiement / phase de charge (20 min)
S.BAG_TIER_SEC = 60          -- une charge de Bien reposé par minute dans le sac
S.BAG_ICONS = {
  [1] = MEDIA .. "SleepingBag-A-1",
  [2] = MEDIA .. "SleepingBag-A-2",
  [3] = MEDIA .. "SleepingBag-A-3",
}
S.OPT_KEYS = {
  death = "slotDeath", flight = "slotFlight",
  afk = "slotAfk", bags = "slotBags", fishing = "slotFishing", swimming = "slotSwimming",
  durability = "slotDurability",
  sleepingbag = "slotSleepingBag",
  trainer = "slotTrainer",
}

-- Style Bulles / Épée retiré : la fiole ne s'anime plus en combat
-- (icône d'état statique). Les anciens réglages sont ignorés.
function S.CombatStyle()
  return "off"
end

function S.SetCombatStyle(v)
  return "off"
end

function S.CombatLiquidOn()
  return S.CombatStyle() ~= "off"
end

function S.Priority()
  if S.CombatStyle() == "sword" then return S.ORDER_SWORD end
  return S.ORDER_DEFAULT
end

S._sim = {}
S.fill = { p = 0, grey = 0, drain = 1, targetP = 0, targetGrey = 0, targetDrain = 1 }
S._phase = 0
S._jolt = 0
S._fishUntil = 0
S._frame = { death = 1, combat = 1, afk = 1, fishing = 1, swimming = 1, trainer = 1, bags = 1, durability = 1 }
S._acc = { death = 0, combat = 0, afk = 0, fishing = 0, swimming = 0, trainer = 0, bags = 0, durability = 0 }
S._zBits = {}

local function N(v)
  v = tonumber(v)
  return v
end

local function Call(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a, b, c, d, e, f = pcall(fn, ...)
  if not ok then return nil end
  return a, b, c, d, e, f
end

local function Now()
  if type(GetTime) == "function" then
    local ok, t = pcall(GetTime)
    if ok and N(t) then return N(t) end
  end
  return 0
end

local function Approach(cur, target, rate, dt)
  cur, target = N(cur) or 0, N(target) or 0
  if cur < target then
    cur = cur + rate * dt
    if cur > target then cur = target end
  elseif cur > target then
    cur = cur - rate * dt
    if cur < target then cur = target end
  end
  return cur
end

function S.Opt(key)
  -- usure : coupée par défaut (OptOff) ; les autres cases sont allumées par défaut
  if key == "slotDurability" then
    if ns.OptOff then return ns.OptOff(key) and true or false end
    local ui = ns.db and ns.db.ui
    return ui and ui[key] == true or false
  end
  if ns.Opt then return ns.Opt(key) ~= false end
  return true
end

function S.SetSim(id, on)
  if on then S._sim[id] = true else S._sim[id] = nil end
  if id == "sleepingbag" and not on then
    S._simBagStacks = nil
    S._bagBuilding, S._bagPeak = false, 0
  end
end

function S.SetEatSim(kind)
  kind = tostring(kind or ""):lower()
  if kind == "food" or kind == "nourriture" or kind == "manger" then kind = "food"
  elseif kind == "drink" or kind == "boisson" or kind == "boire" then kind = "drink"
  elseif kind == "both" or kind == "lesdeux" or kind == "les deux" or kind == "all" then kind = "both"
  else kind = "both" end
  S._simEat = kind
  S.SetSim("eating", true)
  return kind
end

function S.SetSleepingBagSim(stacks)
  stacks = N(stacks)
  if not stacks or stacks < 1 then
    S.SetSim("sleepingbag", false)
    return
  end
  S._simBagStacks = math.max(1, math.min(3, math.floor(stacks + 0.5)))
  S._bagBuilding = true
  S._bagSession = true
  S._bagStartedAt = S._bagStartedAt or Now()
  S._bagPeak = S._simBagStacks
  S.SetSim("sleepingbag", true)
end

function S.ClearSim()
  S._sim = {}
  S._jolt = 0
  S._fishUntil = 0
  S._simBagStacks = nil
  S._bagBuilding, S._bagPeak = false, 0
  S._bagSession, S._bagStartedAt, S._bagUsing = nil, nil, nil
  S._simCamp, S._simEat = nil, nil
  S._campBurstUntil, S._campChargeAt, S._fireUntil = nil, nil, nil
  S._campStartedAt, S._campExpire, S._restEnteredAt, S._campBenefitSeenAt, S._campState = nil, nil, nil, nil, nil
end

function S.IsSim(id)
  return S._sim[id] and true or false
end

------------------------------------------------------------------------------
-- Détection
------------------------------------------------------------------------------
function S.LiveDeath()
  if S._sim.death then return true end
  if type(UnitIsDeadOrGhost) == "function" then
    local v = Call(UnitIsDeadOrGhost, "player")
    if v then return true end
  end
  if Call(UnitIsDead, "player") or Call(UnitIsGhost, "player") then return true end
  return false
end

function S.LiveFlight()
  if S._sim.flight or S._sim.transport then return true end
  local F = ns.Flight
  if F and F.ShowHourglass then return F.ShowHourglass() and true or false end
  return (F and F.Paused and F.Paused()) and true or false
end

function S.LiveCombat()
  if S._sim.combat then return true end
  if type(UnitAffectingCombat) == "function" then
    return Call(UnitAffectingCombat, "player") and true or false
  end
  if type(InCombatLockdown) == "function" then
    return Call(InCombatLockdown) and true or false
  end
  return false
end

function S.LiveAfk()
  if S._sim.afk then return true end
  if type(UnitIsAFK) == "function" then
    return Call(UnitIsAFK, "player") and true or false
  end
  return false
end

local function LooksLikeFishing(name, icon)
  local n = type(name) == "string" and name:lower() or ""
  if n:find("fish", 1, true) or n:find("pêche", 1, true) or n:find("peche", 1, true) then return true end
  if type(icon) == "string" and icon:lower():find("fishing", 1, true) then return true end
  return false
end

function S.RawFishing()
  if type(UnitChannelInfo) == "function" then
    local name, rank, display, icon = Call(UnitChannelInfo, "player")
    if LooksLikeFishing(name, icon) or LooksLikeFishing(display, icon) then return true end
  end
  return false
end

function S.LiveFishing()
  if S._sim.fishing then return true end
  if not S._auraFresh then S.ScanPlayerAuras(true) end
  return S._fishOn and true or false
end

function S.LiveSwimming()
  if S._sim.swimming then return true end
  if type(IsSwimming) == "function" then
    return Call(IsSwimming) and true or false
  end
  return false
end

function S.LiveRested()
  if S._sim.rested then return true end
  return Call(IsResting) and true or false
end

function S.LiveTrainer()
  if S._sim.trainer then return true end
  local tf = _G.TrainerFrame
  if tf and type(tf.IsShown) == "function" and Call(tf.IsShown, tf) then return true end
  local names = { Call(UnitName, "npc"), Call(UnitName, "target"), Call(UnitName, "mouseover") }
  for i = 1, #names do
    local n = names[i]
    if type(n) == "string" and n ~= "" then
      local f = (ns.Fold and ns.Fold(n) or n:lower())
      if f:find("maitre", 1, true) or f:find("trainer", 1, true) then return true end
    end
  end
  return false
end

local function CallBag(fn, bag)
  if type(fn) ~= "function" then return nil end
  local ok, a, b = pcall(fn, bag)
  if ok then return a, b end
end

-- Places libres dans les sacs GÉNÉRAUX seulement (bagType 0).
-- Exclus : carquois, munitions, âme, métier, trousseau de clés.
-- Nil si l'API n'a rien renvoyé (chargement / BAG_UPDATE transitoire) :
-- on ne traite jamais une lecture ratée comme « 0 place ».
S.BAG_CONFIRM = 0.75
function S.BagFreeFn()
  if type(_G.C_Container) == "table" and type(_G.C_Container.GetContainerNumFreeSlots) == "function" then
    return _G.C_Container.GetContainerNumFreeSlots
  end
  if type(_G.GetContainerNumFreeSlots) == "function" then return _G.GetContainerNumFreeSlots end
  return nil
end

function S.BagIndexList()
  local out, seen = {}, {}
  local function add(bag)
    if bag == nil then return end
    bag = N(bag)
    if not bag or seen[bag] then return end
    -- trousseau de clés (souvent -2) : jamais compté
    local keyring = N(_G.KEYRING_CONTAINER) or -2
    if bag == keyring or bag < 0 then return end
    seen[bag] = true
    out[#out + 1] = bag
  end
  add(0) -- sac à dos
  local n = N(_G.NUM_BAG_SLOTS) or 4
  for i = 1, n do add(i) end
  if _G.REAGENTBAG_CONTAINER then add(_G.REAGENTBAG_CONTAINER) end
  if (N(_G.NUM_REAGENTBAG_SLOTS) or 0) > 0 then add(n + 1) end
  return out
end

function S.FreeBagSlots()
  if S._simFree ~= nil then return S._simFree end
  local fn = S.BagFreeFn()
  if type(fn) ~= "function" then return nil end
  local free, seen = 0, 0
  local bags = S.BagIndexList()
  for i = 1, #bags do
    local a, typ = CallBag(fn, bags[i])
    -- typ nil : certains clients ne renvoient que les places ; le sac à dos est général.
    typ = N(typ)
    if typ == nil or typ == 0 then
      if type(a) == "number" then
        free = free + a
        seen = seen + 1
      end
    end
  end
  if seen == 0 then return nil end
  return free
end

function S.LiveBags()
  if S._sim.bags then return true end
  -- Compte mis en cache par CheckBags (BAG_UPDATE_DELAYED), pas à chaque Tick.
  local free = S._bagsLastFree
  if free == nil then return false end
  return free == 0
end

function S.LowestDurability()
  if S._simDura ~= nil then return S._simDura end
  local worst
  local fn = _G.GetInventoryItemDurability
  if type(fn) ~= "function" then return nil end
  for slot = 1, 23 do
    local ok, cur, mx = pcall(fn, slot)
    if ok and type(cur) == "number" and type(mx) == "number" and mx > 0 then
      local r = cur / mx
      if not worst or r < worst then worst = r end
    end
  end
  return worst
end

function S.LiveDurability()
  if S._sim.durability then return true end
  local r = S.LowestDurability()
  return r ~= nil and r < 0.20
end

-- Noms génériques FR/EN du canal / de l'aura de régénération (pas « Bien nourri »).
local EAT_NAMES = {
  drink = true, food = true, ["food & drink"] = true, ["food and drink"] = true,
  boisson = true, nourriture = true, ["boisson et nourriture"] = true,
  ["nourriture et boisson"] = true, refreshment = true, restauration = true,
  eating = true, drinking = true, eat = true, ["en train de manger"] = true,
  ["en train de boire"] = true,
}
local NOT_EAT = {
  ["well fed"] = true, ["bien nourri"] = true, ["bien nourrie"] = true,
  foodbuff = true, ["food buff"] = true,
}
-- Sorts classiques / TBC / Wrath de nourriture et boisson (régénération).
-- Pas les auras « Well Fed » (19705–19711, 24799, 24870, 25661…).
S.EAT_SPELLS = {
  [430] = true, [431] = true, [432] = true, [1133] = true, [1135] = true, [1137] = true,
  [22734] = true, [24355] = true, [25696] = true, [26261] = true, [26402] = true, [26475] = true,
  [27089] = true, [29007] = true, [34291] = true, [43182] = true, [43183] = true, [52911] = true,
  [57085] = true, [61827] = true, [64356] = true, [66041] = true, [80167] = true,
  [433] = true, [434] = true, [435] = true, [1127] = true, [1129] = true, [1131] = true,
  [2639] = true, [5004] = true, [5005] = true, [5006] = true, [5007] = true, [7737] = true,
  [10256] = true, [10257] = true, [18229] = true, [18230] = true, [18231] = true, [18232] = true,
  [18233] = true, [18234] = true, [22731] = true, [24063] = true, [24707] = true, [24869] = true,
  [25660] = true, [25695] = true, [25697] = true, [25700] = true, [25702] = true, [25886] = true,
  [25888] = true, [25990] = true, [26030] = true, [26263] = true, [27094] = true, [28616] = true,
  [29008] = true, [29038] = true, [29039] = true, [29073] = true, [33253] = true, [33257] = true,
  [33258] = true, [33259] = true, [33260] = true, [33261] = true, [33262] = true, [33263] = true,
  [33264] = true, [33265] = true, [33266] = true, [33725] = true, [35270] = true, [35271] = true,
  [40745] = true, [40768] = true, [41030] = true, [42207] = true, [43763] = true, [43771] = true,
  [44166] = true, [45618] = true, [46683] = true, [46812] = true, [46898] = true, [53270] = true,
  [57069] = true, [57070] = true, [57111] = true, [57139] = true, [57285] = true, [57294] = true,
  [57325] = true, [57327] = true, [57329] = true, [57332] = true, [57334] = true, [57356] = true,
  [57358] = true, [57360] = true, [57365] = true, [57367] = true, [57371] = true, [59227] = true,
  [61830] = true, [65341] = true, [80168] = true,
  [43706] = true, [44107] = true, [52993] = true, [53373] = true, [57288] = true, [57291] = true,
  [58503] = true, [58511] = true, [59230] = true, [61828] = true, [65418] = true, [65419] = true,
  [65420] = true, [65421] = true, [65422] = true,
}
-- Boissons (le reste de EAT_SPELLS est de la nourriture, sauf nom « les deux »).
S.DRINK_SPELLS = {
  [430] = true, [431] = true, [432] = true, [1133] = true, [1135] = true, [1137] = true,
  [22734] = true, [24355] = true, [25696] = true, [26261] = true, [26402] = true, [26475] = true,
  [27089] = true, [29007] = true, [34291] = true, [43182] = true, [43183] = true, [52911] = true,
  [57085] = true, [61827] = true, [64356] = true, [66041] = true, [80167] = true,
  [44107] = true, [53270] = true, [53373] = true,
}
S.NOT_EAT_SPELLS = {
  [19705] = true, [19706] = true, [19708] = true, [19709] = true, [19710] = true, [19711] = true,
  [24799] = true, [24870] = true, [25661] = true, [33254] = true, [33255] = true, [33256] = true,
  [45619] = true, [46899] = true, [53284] = true, [57100] = true, [66645] = true,
}

local function SafeStr(v)
  if type(v) ~= "string" or v == "" then return nil end
  if ns.IsSecret and ns.IsSecret(v) then return nil end
  return v
end

local function SafeFold(v)
  v = SafeStr(v)
  if not v then return "" end
  local ok, f = pcall(function()
    return (ns.Fold and ns.Fold(v)) or v:lower()
  end)
  if ok and type(f) == "string" then return f end
  return ""
end

local function IsWellFed(fold, spellId)
  spellId = N(spellId)
  if spellId and S.NOT_EAT_SPELLS[spellId] then return true end
  if fold == "" then return false end
  return NOT_EAT[fold] and true or false
end

local function IsFoodName(fold)
  if fold == "" then return false end
  if NOT_EAT[fold] then return false end
  if EAT_NAMES[fold] then return true end
  if fold:find("boisson", 1, true) or fold:find("nourriture", 1, true) then return true end
  if fold:find("refreshment", 1, true) or fold:find("restauration", 1, true) then return true end
  if fold:find("drink", 1, true) or fold:find("drinking", 1, true) then return true end
  if fold:find("food", 1, true) and not fold:find("foodbuff", 1, true) and not fold:find("well fed", 1, true) then
    return true
  end
  return false
end

local function IsFoodDrink(name, spellId)
  spellId = N(spellId)
  if spellId and S.NOT_EAT_SPELLS[spellId] then return false end
  if spellId and S.EAT_SPELLS[spellId] then return true end
  local fold = SafeFold(name)
  if IsWellFed(fold, spellId) then return false end
  return IsFoodName(fold)
end

-- "food" | "drink" | "both" | nil
function S.ClassifyEat(name, spellId)
  spellId = N(spellId)
  if spellId and S.NOT_EAT_SPELLS[spellId] then return nil end
  local fold = SafeFold(name)
  if IsWellFed(fold, spellId) then return nil end
  local both = fold:find("et boisson", 1, true) or fold:find("and drink", 1, true)
    or fold:find("food & drink", 1, true) or fold:find("food and drink", 1, true)
    or fold:find("nourriture et boisson", 1, true) or fold:find("boisson et nourriture", 1, true)
    or fold == "refreshment" or fold == "restauration"
  if both then return "both" end
  local drink = (spellId and S.DRINK_SPELLS[spellId])
    or (fold:find("boisson", 1, true) or fold:find("drink", 1, true) or fold:find("drinking", 1, true)
        or fold:find("en train de boire", 1, true)) and true
  local food = (spellId and S.EAT_SPELLS[spellId] and not S.DRINK_SPELLS[spellId])
    or (fold:find("nourriture", 1, true) or (fold:find("food", 1, true) and not fold:find("foodbuff", 1, true))
        or fold:find("eating", 1, true) or fold:find("en train de manger", 1, true)) and true
  if food and drink then return "both" end
  if drink then return "drink" end
  if food or IsFoodDrink(name, spellId) then return "food" end
  return nil
end

-- Un index d'aura : nom + spellId, via C_UnitAuras, UnitAura/UnitBuff, AuraUtil.
-- Ne lève jamais (pcall + gardes secrètes). Un trou (nom secret) n'arrête pas le scan.
local function AuraAt(i)
  local name, spellId
  local C = _G.C_UnitAuras
  if type(C) == "table" and type(C.GetAuraDataByIndex) == "function" then
    local ok, data = pcall(C.GetAuraDataByIndex, "player", i, "HELPFUL")
    if ok and type(data) == "table" then
      name = SafeStr(data.name or data.Name)
      spellId = N(data.spellId or data.spellID or data.SpellID)
      return name, spellId, true
    end
  end
  local fn = _G.UnitAura or _G.UnitBuff
  if type(fn) == "function" then
    local ok, r = pcall(function() return { fn("player", i, "HELPFUL") } end)
    if ok and type(r) == "table" and (r[1] ~= nil or r[10] ~= nil or r[11] ~= nil) then
      name = SafeStr(r[1])
      for _, idx in ipairs({ 10, 11, 12, 8, 9 }) do
        local id = N(r[idx])
        if id and id > 0 and id < 2000000 then spellId = id break end
      end
      return name, spellId, true
    end
  end
  return nil, nil, false
end

function S.FoodDrinkAura()
  -- 1) C_UnitAuras par identifiant de sort (même si le nom est secret)
  local C = _G.C_UnitAuras
  if type(C) == "table" and type(C.GetPlayerAuraBySpellID) == "function" then
    for id in pairs(S.EAT_SPELLS) do
      local ok, data = pcall(C.GetPlayerAuraBySpellID, id)
      if ok and type(data) == "table" then return SafeStr(data.name) or ("spell:" .. tostring(id)), id end
    end
  end
  -- 2) AuraUtil par nom FR/EN (et noms localisés des sorts connus)
  local A = _G.AuraUtil
  if type(A) == "table" and type(A.FindAuraByName) == "function" then
    local names = {
      "Nourriture", "Boisson", "Nourriture et Boisson", "Boisson et Nourriture",
      "Food", "Drink", "Food & Drink", "Food and Drink", "Refreshment", "Restauration",
    }
    if type(_G.GetSpellInfo) == "function" then
      local n = 0
      for id in pairs(S.EAT_SPELLS) do
        if n >= 24 then break end
        local ok, nm = pcall(_G.GetSpellInfo, id)
        if ok and SafeStr(nm) then names[#names + 1] = nm n = n + 1 end
      end
    end
    for i = 1, #names do
      local ok, hit = pcall(A.FindAuraByName, names[i], "player", "HELPFUL")
      if ok and hit then
        local nm = SafeStr(hit) or (type(hit) == "table" and SafeStr(hit.name)) or names[i]
        if not IsWellFed(SafeFold(nm)) then return nm end
      end
    end
  end
  -- 3) Scan des auras (ne pas s'arrêter sur un nom secret / un trou isolé)
  local holes = 0
  for i = 1, 40 do
    local name, spellId, present = AuraAt(i)
    if not present then
      holes = holes + 1
      if holes >= 3 then break end
    else
      holes = 0
      if IsFoodDrink(name, spellId) then return name or ("spell:" .. tostring(spellId)), spellId end
    end
  end
  -- 4) Canal en cours (le repas est souvent un canal « Nourriture » / « Food »)
  local ch = _G.UnitChannelInfo
  if type(ch) == "function" then
    local ok, r = pcall(function() return { ch("player") } end)
    if ok and type(r) == "table" then
      local nm = SafeStr(r[1])
      local sid
      for _, idx in ipairs({ 8, 7, 5, 10, 11 }) do
        local id = N(r[idx])
        if id and id > 0 and id < 2000000 then sid = id break end
      end
      if IsFoodDrink(nm, sid) then return nm or ("channel:" .. tostring(sid)), sid end
    end
  end
  return nil
end

-- Cache d'auras / canal : on ne rescane que sur UNIT_AURA (joueur) ou
-- début/fin de canal, après un court regroupement. Live* lit le cache.
S.AURA_COALESCE = 0.15

function S.ScanPlayerAuras(force)
  if S.CombatQuiet and S.CombatQuiet() and not S._flushing then
    S.Defer("auras")
    return S._eatName, S._eatSpell
  end
  if not force and S._auraFresh then return S._eatName, S._eatSpell end
  S._auraFresh = true
  S._auraAt = Now()
  S._auraScans = (S._auraScans or 0) + 1
  local ok, name, spell = pcall(function()
    local n, s = S.FoodDrinkAura()
    return n, s
  end)
  if ok then
    S._eatName, S._eatSpell = name, spell
  else
    S._eatName, S._eatSpell = nil, nil
  end
  local food, drink = false, false
  local kind0 = S.ClassifyEat and S.ClassifyEat(S._eatName, S._eatSpell)
  if kind0 == "both" then food, drink = true, true
  elseif kind0 == "food" then food = true
  elseif kind0 == "drink" then drink = true end
  -- Second passage : une aura nourriture ET une aura boisson en même temps.
  if not (food and drink) then
    local holes = 0
    for i = 1, 40 do
      local n, sid, present = AuraAt(i)
      if not present then
        holes = holes + 1
        if holes >= 3 then break end
      else
        holes = 0
        local k = S.ClassifyEat and S.ClassifyEat(n, sid)
        if k == "food" or k == "both" then food = true end
        if k == "drink" or k == "both" then drink = true end
      end
    end
  end
  S._eatFood, S._eatDrink = food, drink
  local okR, stacks = pcall(S.WellRestedAura)
  S._restedStacks = (okR and stacks) or 0
  local okF, fish = pcall(S.RawFishing)
  S._fishOn = okF and fish and true or false
  local okB, using = pcall(S.SleepingBagUsing)
  S._bagUsing = okB and using and true or false
  return S._eatName, S._eatSpell
end

function S.InvalidateAuras()
  S._auraFresh = false
end

function S.FlushAuras(reason)
  S._auraPending = false
  S._auraFresh = false
  S.ScanPlayerAuras(true)
  pcall(S.Refresh, reason or "UNIT_AURA")
end

function S.OnPlayerAura(reason)
  -- Unité déjà filtrée (player). Regroupe les salves d'UNIT_AURA.
  if S.CombatQuiet and S.CombatQuiet() and not S._flushing then
    S.Defer("auras")
    S._auraFresh = false
    return
  end
  S._auraPending = true
  local wait = S.AURA_COALESCE or 0.15
  local C = _G.C_Timer
  if type(C) == "table" and type(C.After) == "function" then
    if S._auraTimer then return end
    S._auraTimer = true
    pcall(C.After, wait, function()
      S._auraTimer = nil
      if S._auraPending then S.FlushAuras(reason or "UNIT_AURA") end
    end)
    return
  end
  -- Harnais / pas de C_Timer : un seul scan par fenêtre de regroupement.
  local now = Now()
  if S._auraAt and (now - S._auraAt) < wait and S._auraFresh then
    return
  end
  S.FlushAuras(reason or "UNIT_AURA")
end


function S.LiveEating()
  if S._sim.eating or S._sim.eat or S._sim.repas then return true end
  if not S._auraFresh then S.ScanPlayerAuras(true) end
  return S._eatName and true or false
end

function S.EatKind()
  if S._simEat == "food" or S._simEat == "drink" or S._simEat == "both" then return S._simEat end
  if not S._auraFresh then S.ScanPlayerAuras(true) end
  if S._eatFood and S._eatDrink then return "both" end
  if S._eatDrink then return "drink" end
  if S._eatFood or S._eatName then return "food" end
  local k = S.ClassifyEat and S.ClassifyEat(S._eatName, S._eatSpell)
  return k or "food"
end

-- Aura « Bien reposé » / Well-Rested (sort 429959), 1 à 3 charges.
-- +1 % d'XP gagnée par charge, une charge par minute dans le sac.
local WELL_RESTED_NAMES = {
  ["bien repose"] = true, ["bien reposé"] = true, ["bien reposée"] = true,
  ["well-rested"] = true, ["well rested"] = true, wellrested = true,
}

local function AuraStacks(data)
  if type(data) ~= "table" then return nil end
  for _, k in ipairs({ "applications", "stacks", "stackCount", "charges", "count", "Applications" }) do
    local n = N(data[k])
    if n and n > 0 then return n end
  end
  return nil
end

local function IsWellRestedName(name)
  local fold = SafeFold(name)
  if fold == "" then return false end
  if WELL_RESTED_NAMES[fold] then return true end
  if fold:find("bien repos", 1, true) then return true end
  if fold:find("well%-rested") or fold:find("well rested", 1, true) then return true end
  return false
end

function S.WellRestedAura()
  -- 1) Par identifiant de sort (même si le nom est secret).
  local C = _G.C_UnitAuras
  if type(C) == "table" and type(C.GetPlayerAuraBySpellID) == "function" then
    local ok, data = pcall(C.GetPlayerAuraBySpellID, S.WELL_RESTED_SPELL)
    if ok and type(data) == "table" then
      local stacks = AuraStacks(data) or 1
      return math.max(1, math.min(3, stacks))
    end
  end
  -- 2) AuraUtil par nom FR/EN.
  local A = _G.AuraUtil
  if type(A) == "table" and type(A.FindAuraByName) == "function" then
    local names = { "Bien reposé", "Bien repose", "Well-Rested", "Well Rested" }
    if type(_G.GetSpellInfo) == "function" then
      local ok, nm = pcall(_G.GetSpellInfo, S.WELL_RESTED_SPELL)
      if ok and SafeStr(nm) then names[#names + 1] = nm end
    end
    for i = 1, #names do
      local ok, hit = pcall(A.FindAuraByName, names[i], "player", "HELPFUL")
      if ok and hit then
        local stacks = 1
        if type(hit) == "table" then stacks = AuraStacks(hit) or 1 end
        return math.max(1, math.min(3, stacks))
      end
    end
  end
  -- 3) Scan des auras (charges dans le 3e / 4e retour de UnitAura).
  local holes = 0
  for i = 1, 40 do
    local name, spellId, present = AuraAt(i)
    if not present then
      holes = holes + 1
      if holes >= 3 then break end
    else
      holes = 0
      local id = N(spellId)
      if (id and id == S.WELL_RESTED_SPELL) or IsWellRestedName(name) then
        local stacks = 1
        local fn = _G.UnitAura or _G.UnitBuff
        if type(fn) == "function" then
          local ok, r = pcall(function() return { fn("player", i, "HELPFUL") } end)
          if ok and type(r) == "table" then
            for _, idx in ipairs({ 3, 4, 2 }) do
              local n = N(r[idx])
              if n and n >= 1 and n <= 20 then stacks = n break end
            end
          end
        end
        local C = _G.C_UnitAuras
        if type(C) == "table" and type(C.GetAuraDataByIndex) == "function" then
          local ok, data = pcall(C.GetAuraDataByIndex, "player", i, "HELPFUL")
          if ok then stacks = AuraStacks(data) or stacks end
        end
        return math.max(1, math.min(3, stacks))
      end
    end
  end
  return 0
end

-- Buffs *résultants* (après la charge) : ils ne doivent ni garder le pictogramme
-- du sac, ni être pris pour un canal de charge (« au repos », Bien reposé,
-- « chaleur du feu »).
function S.IsResultingBagBuffName(name)
  local fold = SafeFold(name)
  if fold == "" then return false end
  if fold == "au repos" or fold == "repos" then return true end
  if fold:find("bien repos", 1, true) then return true end
  if fold:find("well%-rested") or fold == "well rested" or fold == "wellrested" then return true end
  if fold:find("chaleur du feu", 1, true) or fold:find("warmth of the fire", 1, true) then return true end
  return false
end

function S.IsSleepingBagActionName(name)
  if S.IsResultingBagBuffName(name) then return false end
  local fold = SafeFold(name)
  if fold == "" then return false end
  if fold:find("sac de couchage", 1, true) or fold:find("sleeping bag", 1, true) then return true end
  if fold:find("unroll bag", 1, true) or fold:find("unfurl", 1, true) then return true end
  if fold:find("deplier le sac", 1, true) or fold:find("derouler le sac", 1, true)
    or fold:find("deployer le sac", 1, true) then
    return true
  end
  return false
end

local function ActionSpellId(r)
  if type(r) ~= "table" then return nil end
  for _, idx in ipairs({ 10, 9, 8, 11, 7, 12 }) do
    local id = N(r[idx])
    if id and id > 0 then return id end
  end
  return nil
end

-- Cast ou canal de déploiement / charge (pas le buff Bien reposé).
function S.SleepingBagCasting()
  for _, fn in ipairs({ _G.UnitChannelInfo, _G.UnitCastingInfo }) do
    if type(fn) == "function" then
      local ok, r = pcall(function() return { fn("player") } end)
      if ok and type(r) == "table" and (r[1] or r[4]) then
        local id = ActionSpellId(r)
        if id and id == (S.UNROLL_BAG_SPELL or 429961) then return true, id end
        local nm = SafeStr(r[1]) or SafeStr(r[4]) or SafeStr(r[2])
        if S.IsSleepingBagActionName(nm) then return true, id end
      end
    end
  end
  return false
end

-- Aura de déploiement 429961 (si le client la pose sur le joueur).
function S.UnrollBagAura()
  local id0 = S.UNROLL_BAG_SPELL or 429961
  local C = _G.C_UnitAuras
  if type(C) == "table" and type(C.GetPlayerAuraBySpellID) == "function" then
    local ok, data = pcall(C.GetPlayerAuraBySpellID, id0)
    if ok and type(data) == "table" then return true, data end
  end
  for i = 1, 40 do
    local name, spellId, present = AuraAt(i)
    if not present then
      -- pas de coupure précoce : l'aura peut être plus loin
    elseif spellId and spellId == id0 then
      return true, name
    elseif name and S.IsSleepingBagActionName(name) then
      return true, name
    end
  end
  return false
end

-- Action de charge uniquement (cast, canal, aura 429961). Jamais « assis +
-- charges de Bien reposé » : ce buff dure après la charge et gardait l'icône.
function S.SleepingBagUsing()
  if S._sim.sleepingbag then return true end
  if S.SleepingBagCasting() then return true end
  if S.UnrollBagAura() then return true end
  return false
end

-- Phase de charge : action ci-dessus, ou session ouverte encore en cours
-- (on reste assis dans le sac après le jet de 15 s). Pas le buff résultant.
function S.SleepingBagCharging()
  if S._sim.sleepingbag then return true end
  if S.Opt and not S.Opt("slotSleepingBag") then return false end
  local combat = (ns.InCombat and ns.InCombat()) or (type(_G.UnitAffectingCombat) == "function" and Call(_G.UnitAffectingCombat, "player"))
  if combat then return false end
  if S.SleepingBagUsing() then
    if not S._bagSession then
      S._bagSession = true
      S._bagStartedAt = Now()
    end
    return true
  end
  if S._bagSession and S._bagBuilding then
    if type(_G.IsSitting) == "function" then
      local sit = Call(_G.IsSitting)
      if sit == false then return false end
    end
    return true
  end
  return false
end

function S.SleepingBagStacks()
  if S._sim.sleepingbag or S._simBagStacks then
    local n = N(S._simBagStacks) or 1
    return math.max(1, math.min(3, math.floor(n + 0.5)))
  end
  if not S._auraFresh then S.ScanPlayerAuras(true) end
  local stacks = N(S._restedStacks) or 0
  if stacks >= 1 then return math.min(3, stacks) end
  return 0
end

function S.NotifySleepingBagMiss(peak)
  peak = math.max(1, math.min(2, math.floor((N(peak) or 1) + 0.5)))
  if not (ns.UI and ns.UI.SpawnDrop) then return nil end
  local title = string.format(Tr["Sac de couchage : %d/3 %%"], peak)
  local sub = string.format(Tr["%d %% manqué"], 3 - peak)
  local icon = S.BAG_ICONS[peak] or S.BAG_ICONS[1]
  local ok, f = pcall(ns.UI.SpawnDrop, ns.UI, icon, title, sub, nil, nil, nil, {
    kind = "sleepingbag", hint = Tr["Bien reposé"], dedupeKey = "sleepingbag-miss",
  })
  return ok and f or nil
end

function S.EndSleepingBag(why)
  if not S._bagBuilding then
    S._bagPeak, S._bagSession, S._bagStartedAt, S._bagUsing = 0, nil, nil, nil
    return
  end
  local peak = N(S._bagPeak) or 0
  S._bagBuilding = false
  S._bagSession, S._bagStartedAt, S._bagUsing = nil, nil, nil
  if peak >= 1 and peak < 3 and not S._sim.sleepingbag then
    pcall(S.NotifySleepingBagMiss, peak)
  end
  -- En simulation, le toast « miss » est déclenché par /drop test sleepingbag miss.
  if not S._sim.sleepingbag then S._bagPeak = 0 end
end

function S.SyncSleepingBag()
  if S._sim.sleepingbag then return end
  local combat = (ns.InCombat and ns.InCombat()) or (type(_G.UnitAffectingCombat) == "function" and Call(_G.UnitAffectingCombat, "player"))
  if combat then
    if S._bagBuilding or S._bagSession then S.EndSleepingBag("combat") end
    return
  end
  if not S._auraFresh then
    S.ScanPlayerAuras(true)
  end
  local stacks = N(S._restedStacks) or 0
  if stacks > 3 then stacks = 3 end
  local charging = S.SleepingBagCharging and S.SleepingBagCharging()
  -- Mouvement : fin immédiate de la charge.
  if charging or S._bagBuilding or S._bagSession then
    local speed
    if type(_G.GetUnitSpeed) == "function" then speed = Call(_G.GetUnitSpeed, "player") end
    if N(speed) and speed > 0 then
      S.EndSleepingBag("move")
      return
    end
  end
  if charging then
    if not S._bagSession then
      S._bagSession = true
      S._bagStartedAt = S._bagStartedAt or Now()
    end
    S._bagBuilding = true
    S._bagUsing = true
    if stacks > (S._bagPeak or 0) then S._bagPeak = stacks end
    return
  end
  -- Plus en charge : les buffs résultants (Bien reposé, au repos, chaleur du feu)
  -- ne conservent pas l'icône. Toast palier manqué si on part avant 3/3.
  if S._bagBuilding or S._bagSession then
    S.EndSleepingBag("leave")
  end
end

function S.LiveSleepingBag()
  if S._sim.sleepingbag then return true end
  if S.Opt and not S.Opt("slotSleepingBag") then return false end
  local combat = (ns.InCombat and ns.InCombat()) or (type(_G.UnitAffectingCombat) == "function" and Call(_G.UnitAffectingCombat, "player"))
  if combat then return false end
  -- Uniquement pendant la charge, pas tant que le buff Bien reposé / au repos reste.
  return S.SleepingBagCharging() and true or false
end

function S.Want(id)
  local key = S.OPT_KEYS[id]
  if key and not S.Opt(key) then return false end
  if id == "death" then return S.LiveDeath() end
  if id == "flight" then return S.LiveFlight() end
  if id == "combat" then return S.CombatStyle() == "sword" and S.LiveCombat() end
  if id == "afk" then return S.LiveAfk() end
  if id == "bags" then return S.LiveBags() end
  if id == "fishing" then return S.LiveFishing() end
  if id == "swimming" then return S.LiveSwimming() end
  if id == "durability" then return S.LiveDurability() end
  if id == "rested" then return S.LiveRested() end
  if id == "trainer" then return S.LiveTrainer() end
  if id == "eating" then return S.LiveEating() end
  if id == "sleepingbag" then return S.LiveSleepingBag() end
  return false
end


function S.Active()
  local order = S.Priority and S.Priority() or S.ORDER_DEFAULT
  for i = 1, #order do
    local id = order[i]
    if S.Want(id) then return id end
  end
  return "drop"
end

function S.DeathPause()
  return S.Opt("slotDeath") and S.LiveDeath()
end

local function FlaskVisible(t)
  if not (t and t.data and t.data.kind == "total") then return false end
  -- masquée par option : pas de fiole cible (les z restent sur Niveau).
  local Wd = ns.Wide
  if Wd and Wd.Shown and not Wd.Shown() then return false end
  if type(t.IsShown) == "function" then return t:IsShown() and true or false end
  return true
end

function S.FlaskTile()
  local Wd = ns.Wide
  local t = Wd and Wd.TotalTile and Wd.TotalTile()
  if FlaskVisible(t) then return t end
  local ui = ns.UI
  local tiles = ui and ui.embed and ui.embed.tiles
  if tiles then
    for i = 1, #tiles do
      local tt = tiles[i]
      if FlaskVisible(tt) then return tt end
    end
  end
  return nil
end

function S.FlaskIsWide(t)
  t = t or S.FlaskTile()
  return t and t._wideOn and true or false
end

function S.TakesRestedZ()
  return false   -- z sur la fiole retirés : l'état repos remplace l'icône
end

function S.StealsLevelZ()
  return false
end

------------------------------------------------------------------------------
-- Remplissage de la fiole (barre 3 couleurs)
-- p = 0 état normal (3 couleurs), 1 = combat (rouge+bleu remplissent, vert éteint)
-- grey 0..1, drain 1 = plein / 0 = vide (mort)
------------------------------------------------------------------------------
S.FILL_RATE = 1 / 0.6
S.GREY = { 0.42, 0.42, 0.40 }

function S.SyncFillTargets()
  local f = S.fill
  if S.Opt("slotDeath") and S.LiveDeath() then
    f.targetP, f.targetGrey, f.targetDrain = 0, 1, 0
  elseif S.CombatLiquidOn() and S.LiveCombat() then
    f.targetP, f.targetGrey, f.targetDrain = 1, 0, 1
  else
    f.targetP, f.targetGrey, f.targetDrain = 0, 0, 1
  end
end

function S.FillBusy()
  local f = S.fill
  if math.abs((f.p or 0) - (f.targetP or 0)) > 0.001 then return true end
  if math.abs((f.grey or 0) - (f.targetGrey or 0)) > 0.001 then return true end
  if math.abs((f.drain or 1) - (f.targetDrain or 1)) > 0.001 then return true end
  if (f.p or 0) > 0.02 and (f.drain or 1) > 0.02 and (f.grey or 0) < 0.5 then return true end -- ondulation
  return false
end

function S.TransformWidths(widths, track, fill)
  widths = widths or { 0, 0, 0 }
  track = math.max(0, N(track) or 0)
  fill = fill or S.fill
  local p = math.max(0, math.min(1, N(fill.p) or 0))
  local grey = math.max(0, math.min(1, N(fill.grey) or 0))
  local drain = math.max(0, math.min(1, N(fill.drain) or 1))
  local wR, wB, wG = N(widths[1]) or 0, N(widths[2]) or 0, N(widths[3]) or 0
  local rb = wR + wB
  local srcR, srcB = wR, wB
  if rb <= 0 and p > 0 and track > 0 then
    srcR, srcB, rb = 1, 1, 2
  end
  local dstR = (rb > 0) and (track * (srcR / rb)) or 0
  local dstB = (rb > 0) and (track * (srcB / rb)) or 0
  local outR = wR + (dstR - wR) * p
  local outB = wB + (dstB - wB) * p
  local outG = wG * (1 - p)
  outR, outB, outG = outR * drain, outB * drain, outG * drain
  if p > 0.15 and drain > 0.2 and grey < 0.5 and track > 0 then
    local wave = 0.035 * math.sin((S._phase or 0) * 2 * math.pi)
    local extra = wave * track
    local sum = outR + outB
    if sum > 0 then
      outR = math.max(0, outR + extra * (outR / sum))
      outB = math.max(0, outB + extra * (outB / sum))
      if outR + outB + outG > track then
        local scale = track / (outR + outB + outG)
        outR, outB, outG = outR * scale, outB * scale, outG * scale
      end
    end
  end
  local out = S._widthOut
  if not out then out = { outR, outB, outG } S._widthOut = out
  else out[1], out[2], out[3] = outR, outB, outG end
  return out, p, grey, drain
end

function S.FillRatios(t)
  local Wd = ns.Wide
  local last = Wd and Wd.last
  local widths, track
  if last and last.widths and last.track and last.track > 0 then
    widths, track = last.widths, last.track
  else
    local snap = ns.UI and ns.UI.snapshot
    local segs = (snap and snap.segments)
      or (ns.ComputeTotalSegments and ns.ComputeTotalSegments(snap and snap.tiles))
      or {}
    local d = t and t.data
    local cur = (d and (N(d.current) or N(d.total)))
      or (snap and (N(snap.total) or N(snap.ficTotal))) or 0
    local mx = (d and (N(d.apiMax) or N(d.max) or N(d.totalMax)))
      or (snap and (N(snap.totalMax) or N(snap.ficMax))) or N(ns.TOTAL_MAX) or 2460
    if Wd and Wd.SegmentWidths then
      widths = Wd.SegmentWidths(segs, 100, cur, mx)
      track = 100
    else
      local p = (mx > 0) and math.max(0, math.min(1, cur / mx)) or 0
      widths, track = { 0, 0, p * 100 }, 100
    end
  end
  return S.TransformWidths(widths, track, S.fill)
end

function S.EnsureGridFill(t)
  if not t then return nil end
  local _, content = S.PlaceIconClip(t)
  local parent = content or t.icon or t
  if t._gFill then
    if t._gFill.SetParent and parent and t._gFill.GetParent and t._gFill:GetParent() ~= parent then
      pcall(t._gFill.SetParent, t._gFill, parent)
    end
    return t._gFill
  end
  local ok, f = pcall(CreateFrame, "Frame", nil, parent)
  if not (ok and f) then return nil end
  S.SetSizeIf(f, 1, 1)
  if f.EnableMouse then pcall(f.EnableMouse, f, false) end
  local function tex(layer)
    if type(f.CreateTexture) ~= "function" then return nil end
    return f:CreateTexture(nil, layer or "ARTWORK")
  end
  f.red, f.blue, f.green, f.wave = tex("ARTWORK"), tex("ARTWORK"), tex("ARTWORK"), tex("OVERLAY")
  local waveTex = (ns.Rested and ns.Rested.WAVE_TEX) or (MEDIA .. "Dropamine-Wave")
  if f.wave and f.wave.SetTexture then pcall(f.wave.SetTexture, f.wave, waveTex) end
  t._gFill = f
  return f
end

function S.TickFlaskWave(dt)
  local t = S.FlaskTile and S.FlaskTile() or (ns.Wide and ns.Wide.TotalTile and ns.Wide.TotalTile())
  local e = t and t._gFill
  if not (e and e.wave) then return end
  if e.wave.IsShown and not e.wave:IsShown() then return end
  e.u = (e.u or 0) + (N(dt) or 0) / 2.4
  if e.u > 1 then e.u = e.u - math.floor(e.u) end
  if e.wave.SetTexCoord then
    local span = (ns.Rested and ns.Rested.WAVE_U) or 0.5
    local u = e.u * span
    pcall(e.wave.SetTexCoord, e.wave, u, 0, u + span, 1)
  end
end

function S.ApplyGridFill(t)
  t = t or S.FlaskTile()
  if not t then return end
  -- En combat le liquide rouge/bleu prend le relais ; au repos on ne peint
  -- plus de barres bleu/vert/rouge ni de vague par-dessus l'icône officielle.
  if t._gFill then
    if S.HideFlaskOverlay then S.HideFlaskOverlay(t._gFill) elseif t._gFill.Hide then t._gFill:Hide() end
  end
  if not S.ReplacesFlaskIcon(t) then
    if t.icon and t.icon.Show then t.icon:Show() end
  end
end


function S.ApplyFlaskFill(t)
  local Wd = ns.Wide
  if not (Wd and Wd.EnsureSegs) then
    t = t or S.FlaskTile()
    if t and not t._wideOn then S.ApplyGridFill(t) end
    return
  end
  t = t or S.FlaskTile() or (Wd.TotalTile and Wd.TotalTile())
  if not t then return end
  -- Hors barre large : liquide + vague dans l'icône officielle (jamais un puits vide).
  if not t._wideOn then
    local pseg = t._pseg or (Wd.EnsureSegs and Wd.EnsureSegs(t))
    if pseg and pseg.segs then
      for i = 1, #pseg.segs do
        if pseg.segs[i] and pseg.segs[i].Hide then pseg.segs[i]:Hide() end
      end
    end
    S.ApplyGridFill(t)
    return
  end
  if t._gFill and t._gFill.Hide then t._gFill:Hide() end
  -- La barre officielle est un remplissage statique posé par Wd.Paint.
  -- Aucune animation, dégradé ou teinte d'état : seule l'étincelle colorée
  -- (PlayBarSpark) a le droit d'y passer, puis alpha 0 sans résidu.
  return
end
function S._ApplyFlaskFill_UNUSED_TRANSFORM(t)
  local Wd = ns.Wide
  local last = Wd.last
  if not last or not last.widths or not last.track then return end
  local pseg = Wd.EnsureSegs(t)
  if not (pseg and pseg.segs) then return end
  local out, p, grey, drain = S.TransformWidths(last.widths, last.track, S.fill)
  local il, ir, ib = last.il or 0, last.ir or 0, last.ib or 0
  local left, by, fh = last.left or 0, last.by or 0, last.fh or 0
  local x = left + il
  local GREY = S.GREY
  for i = 1, 3 do
    local tex, w = pseg.segs[i], out[i] or 0
    if not tex then break end
    local c = Wd.SEG_COLORS and Wd.SEG_COLORS[i] or { 1, 1, 1, 1 }
    local r = (c[1] or 1) + (GREY[1] - (c[1] or 1)) * grey
    local g = (c[2] or 1) + (GREY[2] - (c[2] or 1)) * grey
    local b = (c[3] or 1) + (GREY[3] - (c[3] or 1)) * grey
    local a = c[4] or 1
    if i == 3 then a = a * (1 - p) end
    if tex.ClearAllPoints then tex:ClearAllPoints() end
    if w > 0.5 and fh > 0 and a > 0.02 then
      tex:SetPoint("BOTTOMLEFT", t, "BOTTOMLEFT", x, by + ib)
      if tex.SetSize then tex:SetSize(math.max(0.01, w), fh) end
      if tex.SetVertexColor then tex:SetVertexColor(r, g, b, a) end
      if tex.Show then tex:Show() end
      x = x + w
    else
      if tex.Hide then tex:Hide() end
    end
  end
end

------------------------------------------------------------------------------
-- Symbole dans le puits (même texture que le sablier)
------------------------------------------------------------------------------
local function TexCoord(i, frames, cols, rows)
  frames = frames or 32
  cols, rows = cols or 8, rows or 4
  i = ((i - 1) % frames) + 1
  local col = (i - 1) % cols
  local row = math.floor((i - 1) / cols)
  local u0, v0 = col / cols, row / rows
  return u0, u0 + 1 / cols, v0, v0 + 1 / rows
end
S.TexCoord = TexCoord

local function HideBagIcon(t)
  if t and t._bagIcon and t._bagIcon.Hide then t._bagIcon:Hide() end
end

local function HideSymbol(t)
  if t and t._hg then
    if t._hg.ClearAllPoints and t.icon then pcall(t._hg.ClearAllPoints, t._hg) pcall(t._hg.SetAllPoints, t._hg, t.icon) end
    if t._hg.Hide then t._hg:Hide() end
  end
  HideBagIcon(t)
  if t and t.icon and (not ns.Flight or (ns.Flight._vis or 0) <= 0) then
    if t.icon.Show then t.icon:Show() end
    if t.icon.SetAlpha then t.icon:SetAlpha(1) end
  end
end

function S.ApplySheet(t, id)
  local Wd = ns.Wide
  if not (t and id and S.SHEETS[id] and Wd and Wd.EnsureHourglass) then return nil end
  local h = Wd.EnsureHourglass(t)
  if not h then return nil end
  local sh = S.SHEETS[id]
  if h.SetTexture then pcall(h.SetTexture, h, sh.tex) end
  local fi = S._frame[id] or 1
  if h.SetTexCoord then pcall(h.SetTexCoord, h, TexCoord(fi, sh.frames)) end
  -- Toujours dans le clip de l'icône : jamais sur la case (ça recouvrirait le compteur).
  local clip, content, iw, ih = S.PlaceIconClip(t)
  iw, ih = iw or 16, ih or 16
  local parent = content or clip
  if h.SetParent and parent then pcall(h.SetParent, h, parent) end
  local sideW, sideH, x, y = iw, ih, 0, 0
  if t.icon and t.icon.Hide then t.icon:Hide() end
  -- Pêche validée : la feuille remplace toute la fiole (pas un badge en coin).
  -- Un sursaut à la prise décale légèrement le glyphe dans le clip.
  if id == "fishing" and (S._jolt or 0) > 0 then
    local j = S._jolt
    x = math.sin(j * 42) * 1.2 * j
    y = math.cos(j * 31) * 1.2 * j
  end
  if S.PlaceClippedTex then
    S.PlaceClippedTex(h, parent or t, sideW, sideH, x, y)
  else
    if h.ClearAllPoints then pcall(h.ClearAllPoints, h) end
    if h.SetSize then pcall(h.SetSize, h, sideW, sideH) end
  end
  if h.SetAlpha then pcall(h.SetAlpha, h, 1) end
  if h.Show then h:Show() end
  return h
end

function S.EnsureBagIcon(t, parent)
  if t._bagIcon then
    if parent and t._bagIcon.SetParent then pcall(t._bagIcon.SetParent, t._bagIcon, parent) end
    return t._bagIcon
  end
  parent = parent or t
  if not (parent and type(parent.CreateTexture) == "function") then return nil end
  local tex = parent:CreateTexture(nil, "ARTWORK", nil, 5)
  if not tex then return nil end
  t._bagIcon = tex
  return tex
end

-- Pictogramme style A (1 / 2 / 3 bandes), cadré dans l'icône (barre et grille).
function S.ApplySleepingBag(t)
  if not t then return nil end
  local step = S.SleepingBagStacks()
  if step < 1 then step = 1 end
  if step > 3 then step = 3 end
  local path = S.BAG_ICONS[step] or S.BAG_ICONS[1]
  t._bagStep = step
  local clip, content, w, h = S.PlaceIconClip(t)
  local parent = content or clip or t.icon or t
  local tex = S.EnsureBagIcon(t, parent)
  if not tex then return nil end
  S.PlaceClippedTex(tex, parent, w or 16, h or 16, 0, 0)
  if tex.SetTexture then pcall(tex.SetTexture, tex, path) end
  if tex.SetTexCoord then pcall(tex.SetTexCoord, tex, 0, 1, 0, 1) end
  if tex.SetAlpha then pcall(tex.SetAlpha, tex, 1) end
  if tex.Show then tex:Show() end
  if t.icon and t.icon.Hide then t.icon:Hide() end
  if t._hg and t._hg.Hide then t._hg:Hide() end
  return tex
end

-- Cadre de rognage (ScrollFrame) calé dans l'icône, en retrait du cadre bronze /
-- du fond de la case. SetClipsChildren est utilisé s'il existe, mais Forever
-- ne le garantit pas : le ScrollFrame est le clip fiable.
function S.IconAnchor(t)
  if not t then return nil end
  return t.icon or t.iconSlot or t.slotBorder or t
end

-- États qui remplacent le glyphe de la goutte (pas une couche par-dessus).

-- Icônes de jeu pour les états encore à valider : elles remplacent la
-- fiole (comme le sablier), restent dans la zone icône, le compteur reste
-- lisible, et la fiole est restaurée proprement à la fin.
S.STATE_ICON = {
  combat   = MEDIA .. "Combat-Icon",
  food     = MEDIA .. "Food-Icon",
  drink    = MEDIA .. "Drink-Icon",
  both     = MEDIA .. "Eat-Both-Icon",
  rested   = MEDIA .. "Rest-Icon",
}
function S.IsCustomIcon(path)
  return type(path) == "string" and path:find("Interface\\AddOns\\Dropamine", 1, true) and true or false
end

function S.CombatStateOn()
  local act = S.Active and S.Active()
  if act and act ~= "drop" and act ~= "combat" then return false end
  return (S.LiveCombat and S.LiveCombat()) and true or false
end

function S.EnsureStateIcon(t)
  if not t then return nil end
  local _, content, w, h = S.PlaceIconClip(t)
  local parent = content
  if not parent then return t._stIcon end
  if t._stIcon then
    if t._stIcon.SetParent and t._stIcon.GetParent and t._stIcon:GetParent() ~= parent then
      pcall(t._stIcon.SetParent, t._stIcon, parent)
    end
    return t._stIcon, parent, w, h
  end
  if type(parent.CreateTexture) ~= "function" then return nil end
  local tex = parent:CreateTexture(nil, "ARTWORK", nil, 5)
  if not tex then return nil end
  S.PlaceClippedTex(tex, parent, 1, 1, 0, 0)
  if tex.Hide then tex:Hide() end
  t._stIcon = tex
  return tex, parent, w, h
end

function S.HideStateIcon(t)
  t = t or (S.FlaskTile and S.FlaskTile())
  if not t then return end
  local right = t._stIconR
  if right then
    if right.SetAlpha then pcall(right.SetAlpha, right, 0) end
    if right.SetHeight then pcall(right.SetHeight, right, 0) end
    if right.Hide then right:Hide() end
  end
  local tex = t._stIcon
  if tex then
    if S.HideFlaskOverlay then
      -- HideFlaskOverlay expects a frame with named textures; hide the tex directly.
    end
    if tex.SetAlpha then pcall(tex.SetAlpha, tex, 0) end
    if tex.SetHeight then pcall(tex.SetHeight, tex, 0) end
    tex._szH, tex._clipY, tex._kind = 0, nil, nil
    if tex.Hide then tex:Hide() end
  end
  if t.icon and t.icon.Show and not (S.ReplacesFlaskIcon and S.ReplacesFlaskIcon(t)) then
    t.icon:Show()
    if t.icon.SetAlpha then pcall(t.icon.SetAlpha, t.icon, 1) end
  end
end

-- mode : "pulse" | "bob" | "near" | "charge" | "burst"
function S.ApplyStateIcon(t, key, mode)
  if not (t and key) then return nil end
  local path = S.STATE_ICON and S.STATE_ICON[key]
  if not path then return nil end
  local tex, parent, w, h = S.EnsureStateIcon(t)
  if not (tex and parent) then return nil end
  local clip, content, iw, ih = S.PlaceIconClip(t)
  w, h = iw or w or 16, ih or h or 16
  parent = content or clip or parent
  if not parent then return nil end
  -- Glyphe seul (pas de disque) : remplit le puits comme la fiole officielle,
  -- 1 px de marge pour que le filet bronze de contour ne soit pas rogné.
  local side = math.min(w, h)
  side = math.max(6, side - 1)
  local x, y = (w - side) * 0.5, (h - side) * 0.5
  local alpha = 1
  local phase = S._phase or 0
  mode = mode or "pulse"
  if mode == "near" then
    -- feu sombre, taille presque pleine (le glyphe « Near » est déjà atténué)
    side = math.max(8, side * 0.96)
    x, y = (w - side) * 0.5, (h - side) * 0.5
    alpha = 0.88
  elseif mode == "charge" then
    local pulse = 0.03 * math.sin(phase * 2 * math.pi)
    side = math.max(8, side * (0.97 + pulse))
    x, y = (w - side) * 0.5, (h - side) * 0.5
    alpha = 0.92 + 0.08 * (0.5 + 0.5 * math.sin(phase * 2 * math.pi))
  elseif mode == "burst" or mode == "buff" then
    -- flamme / glyphe plein, statique
    alpha = 1
  elseif mode == "bob" then
    local bob = math.sin(phase * 2 * math.pi) * math.max(0.6, h * 0.04)
    y = y + bob
    if (S._jolt or 0) > 0 then
      local j = S._jolt
      local ox = math.sin(j * 42) * 1.1 * j
      local oy = math.cos(j * 31) * 1.1 * j
      x, y = x + ox, y + oy
    end
    if x < 0 then x = 0 end
    if y < 0 then y = 0 end
    if x + side > w then x = math.max(0, w - side) end
    if y + side > h then y = math.max(0, h - side) end
    alpha = 0.78 + 0.22 * (0.5 + 0.5 * math.sin(phase * 2 * math.pi))
  else
    -- pulse (combat, défaut) : simple battement d'alpha, comme un sablier discret.
    alpha = 0.78 + 0.22 * (0.5 + 0.5 * math.sin(phase * 2 * math.pi))
  end
  if tex.SetTexture then pcall(tex.SetTexture, tex, path) end
  -- Art maison : pas de crop 0.07 (réservé aux icônes Blizzard).
  if tex.SetTexCoord then
    if S.IsCustomIcon and S.IsCustomIcon(path) then pcall(tex.SetTexCoord, tex, 0, 1, 0, 1)
    else pcall(tex.SetTexCoord, tex, 0.07, 0.93, 0.07, 0.93) end
  end
  if tex.SetVertexColor then pcall(tex.SetVertexColor, tex, 1, 1, 1, 1) end
  S.PlaceClippedTex(tex, parent, side, side, x, y)
  if tex.SetAlpha then pcall(tex.SetAlpha, tex, alpha) end
  if tex.Show then tex:Show() end
  tex._kind = key
  if t.icon and t.icon.Hide then t.icon:Hide() end
  -- Art maison déjà cadré dans un disque : un masque circulaire de case
  -- rognait le liseré (surtout en petit). Les icônes Blizzard gardent le mask.
  if not (S.IsCustomIcon and S.IsCustomIcon(path)) then
    local mask = S.IconMaskFor and S.IconMaskFor(t)
    if mask and tex.AddMaskTexture then pcall(tex.AddMaskTexture, tex, mask) end
  elseif tex.RemoveMaskTexture then
    local mask = t._flareMask or (t.icon and t.icon._thMask)
    if mask then pcall(tex.RemoveMaskTexture, tex, mask) end
  end
  return tex
end


-- Cache les bandes rouge/bleu/vert de la jauge (barre large) et le remplissage grille.
function S.HideBarBands(t)
  -- Ne plus cacher la barre ni le texte « 85/2460 » : les états ne remplacent
  -- que l'icône de la fiole. On range seulement les calques d'icône hérités.
  t = t or (S.FlaskTile and S.FlaskTile())
  if not t then return end
  if t._gFill then
    if S.HideFlaskOverlay then S.HideFlaskOverlay(t._gFill) elseif t._gFill.Hide then t._gFill:Hide() end
  end
  if t._cLiq and t._cLiq.Hide then t._cLiq:Hide() end
end

-- Z de repos : un glyphe unique, créé une fois, animé comme le sablier
-- (flottement + fondu, phase partagée, zéro allocation). Crème / bronze, sobre.
S.REST_Z_COLOR = { 0.93, 0.82, 0.58, 1 }   -- crème bronze (guideline)
function S.EnsureRestIcon(t)
  if not t then return nil end
  local _, content, w, h = S.PlaceIconClip(t)
  local parent = content or t
  local function style_fs(fs)
    if not fs then return end
    if fs.SetFont then pcall(fs.SetFont, fs, "Fonts\\FRIZQT__.TTF", 16, "OUTLINE") end
    if fs.SetText then fs:SetText("Z") end
    fs._txt = "Z"
    local c = S.REST_Z_COLOR
    if fs.SetTextColor then pcall(fs.SetTextColor, fs, c[1], c[2], c[3], c[4] or 1) end
    -- Contour bronze (guideline), pas un Z nu dans une case.
    if fs.SetShadowColor then pcall(fs.SetShadowColor, fs, 0.65, 0.49, 0.27, 1) end
    if fs.SetShadowOffset then pcall(fs.SetShadowOffset, fs, 1, -1) end
    if fs.SetJustifyH then fs:SetJustifyH("CENTER") end
    if fs.SetJustifyV then fs:SetJustifyV("MIDDLE") end
  end
  local function ensure_disc(holder)
    if not holder or holder.disc then return holder and holder.disc end
    if type(holder.CreateTexture) ~= "function" then return nil end
    local disc = holder:CreateTexture(nil, "ARTWORK", nil, 1)
    if not disc then return nil end
    if disc.SetTexture then pcall(disc.SetTexture, disc, MEDIA .. "RoundMask") end
    if disc.SetVertexColor then pcall(disc.SetVertexColor, disc, 0.08, 0.07, 0.05, 0.96) end
    if disc.SetAllPoints then pcall(disc.SetAllPoints, disc, holder) end
    holder.disc = disc
    return disc
  end
  if t._restZ and t._restZ.fs then
    if t._restZ.SetParent and parent and t._restZ.GetParent and t._restZ:GetParent() ~= parent then
      pcall(t._restZ.SetParent, t._restZ, parent)
    end
    ensure_disc(t._restZ)
    return t._restZ, w, h
  end
  if type(parent.CreateFontString) ~= "function" and type(parent.CreateFrame) ~= "function" then
    return t._restZ, w, h
  end
  local ok, holder = pcall(CreateFrame, "Frame", nil, parent)
  if not (ok and holder) then return t._restZ, w, h end
  S.SetSizeIf(holder, 1, 1)
  if holder.EnableMouse then pcall(holder.EnableMouse, holder, false) end
  if holder.Hide then holder:Hide() end
  ensure_disc(holder)
  local fs = holder.CreateFontString and holder:CreateFontString(nil, "OVERLAY")
  style_fs(fs)
  holder.fs = fs
  t._restZ = holder
  return holder, w, h
end

function S.HideRestIcon(t)
  t = t or (S.FlaskTile and S.FlaskTile())
  if not t then return end
  local h = t._restZ
  if h then
    if h.Hide then h:Hide() end
    if h.fs and h.fs.Hide then h.fs:Hide() end
    if h.disc and h.disc.Hide then h.disc:Hide() end
  end
  if t._slotZ and t._slotZ.Hide then t._slotZ:Hide() end
  if t._stIcon and t._stIcon._kind == "rested" and S.HideStateIcon then
    S.HideStateIcon(t)
  elseif t.icon and t.icon.Show and not (S.ReplacesFlaskIcon and S.ReplacesFlaskIcon(t)) then
    t.icon:Show()
    if t.icon.SetAlpha then pcall(t.icon.SetAlpha, t.icon, 1) end
  end
end

function S.ApplyRestIcon(t)
  t = t or (S.FlaskTile and S.FlaskTile())
  if not t then return nil end
  -- Z maison (disque sombre, filet bronze, glyphe crème) : une texture poolée, comme les autres états.
  if t._slotZ and t._slotZ.Hide then t._slotZ:Hide() end
  if t._restZ and t._restZ.Hide then t._restZ:Hide() end
  local tex = S.ApplyStateIcon(t, "rested", "bob")
  local Wd = ns.Wide
  if Wd and Wd.SyncFlaskHit then Wd.SyncFlaskHit(t) end
  return tex
end


function S.ApplyEatDisc(t)
  t = t or (S.FlaskTile and S.FlaskTile())
  if not t then return nil end
  local kind = (S.EatKind and S.EatKind()) or "food"
  if kind == "both" then
    -- Une seule texture maison (disque partagé fourchette | coupe), pas un crop d'icônes de jeu.
    if t._stIconR then
      if t._stIconR.SetAlpha then pcall(t._stIconR.SetAlpha, t._stIconR, 0) end
      if t._stIconR.Hide then t._stIconR:Hide() end
    end
    return S.ApplyStateIcon(t, "both", "pulse")
  end
  if t._stIconR then
    if t._stIconR.SetAlpha then pcall(t._stIconR.SetAlpha, t._stIconR, 0) end
    if t._stIconR.Hide then t._stIconR:Hide() end
  end
  return S.ApplyStateIcon(t, kind, "pulse")
end

function S.ReplacesFlaskIcon(t)
  local act = S.Active and S.Active()
  if act == "sleepingbag" or act == "fishing" or act == "combat" or act == "rested" then return true end
  if act == "drop" and S.CombatStateOn and S.CombatStateOn() then return true end
  if act == "drop" and S.Want and S.Want("eating") then return true end
  if act and act ~= "drop" and S.SHEETS and S.SHEETS[act] then return true end
  return false
end

-- Taille intérieure de l'icône (goutte en barre ~14 px, case grille ~32 px).
-- Ne jamais se fier à GetWidth d'un cadre seulement ancré : avant le layout
-- (et dans le harnais) ça rend souvent 0 ou la taille par défaut (100).
function S.IconInnerSize(t)
  if not t then return 16, 16, nil, 2 end
  local anchor = S.IconAnchor(t)
  local aw, ah = 0, 0
  local function take(obj)
    if not obj then return end
    if aw < 2 and obj.GetWidth then aw = N(obj:GetWidth()) or aw end
    if ah < 2 and obj.GetHeight then ah = N(obj:GetHeight()) or ah end
  end
  take(anchor)
  take(t.icon)
  take(t.iconSlot)
  if aw < 2 and t._wideH then
    aw = math.max(8, (N(t._wideH) or 16) - 2)
  end
  -- Repli : barre large = petite goutte ; grille = icône de case.
  if aw < 2 then aw = (t._wideOn and 14) or 32 end
  if ah < 2 then ah = aw end
  -- Jamais la largeur de la case : ça poserait le clip sur « 85/2460 ».
  local cap = t._wideOn and math.max(14, N(t._wideH) or 16) or ((ns.View and ns.View.ICON_SIZE) or 32)
  if aw > cap + 0.5 then aw = cap end
  if ah > cap + 0.5 then ah = cap end
  local inset = 0
  local slot = t.iconSlot or t
  if slot then inset = N(slot._ringInset) or 0 end
  if not inset or inset <= 0 then
    inset = math.max(2, math.floor(aw * 3 / 32 + 0.5))
  end
  if inset * 2 >= aw then inset = math.max(1, math.floor(aw / 8)) end
  local w = math.max(1, aw - inset * 2)
  local h = math.max(1, ah - inset * 2)
  return w, h, anchor, inset, aw, ah
end

function S.IconInset(t, anchor)
  local _, _, _, inset = S.IconInnerSize(t)
  return inset
end

function S.EnsureIconClip(t)
  if not t then return nil end
  local parent = t.iconSlot or t
  if t._iconClip and t._iconClip._content then
    if t._iconClip.SetParent and parent and t._iconClip.GetParent
        and t._iconClip:GetParent() ~= parent then
      pcall(t._iconClip.SetParent, t._iconClip, parent)
    end
    return t._iconClip, t._iconClip._content
  end
  local ok, clip = pcall(CreateFrame, "ScrollFrame", nil, parent)
  if not (ok and clip) then
    ok, clip = pcall(CreateFrame, "Frame", nil, parent)
    if not (ok and clip) then return nil end
  end
  -- Jamais laisser le défaut 100×50 : ça recouvre la fiole et peut gonfler le panneau.
  S.SetSizeIf(clip, 1, 1)
  if clip.EnableMouse then pcall(clip.EnableMouse, clip, false) end
  if clip.SetClipsChildren then pcall(clip.SetClipsChildren, clip, true) end
  if clip.SetHorizontalScroll then pcall(clip.SetHorizontalScroll, clip, 0) end
  if clip.SetVerticalScroll then pcall(clip.SetVerticalScroll, clip, 0) end
  -- Pas de barre / flèche de défilement (triangle parasite au-dessus de la case).
  if clip.ScrollBar and clip.ScrollBar.Hide then pcall(clip.ScrollBar.Hide, clip.ScrollBar) end
  local okC, content = pcall(CreateFrame, "Frame", nil, clip)
  if okC and content then
    S.SetSizeIf(content, 1, 1)
    if clip.SetScrollChild then pcall(clip.SetScrollChild, clip, content) end
    if content.ClearAllPoints then pcall(content.ClearAllPoints, content) end
    if content.SetPoint then pcall(content.SetPoint, content, "TOPLEFT", clip, "TOPLEFT", 0, 0) end
    if content.EnableMouse then pcall(content.EnableMouse, content, false) end
    if content.SetClipsChildren then pcall(content.SetClipsChildren, content, true) end
    clip._content = content
  end
  t._iconClip = clip
  return clip, clip._content
end

-- SetSize seulement si la taille a changé (évite le coût chaque image).
function S.SetSizeIf(obj, w, h)
  if not obj then return false end
  w, h = N(w), N(h)
  if not w or not h then return false end
  if obj._szW and obj._szH and math.abs(obj._szW - w) < 0.5 and math.abs(obj._szH - h) < 0.5 then
    return false
  end
  if obj.SetSize then pcall(obj.SetSize, obj, w, h) end
  if obj.SetWidth then pcall(obj.SetWidth, obj, w) end
  if obj.SetHeight then pcall(obj.SetHeight, obj, h) end
  obj._szW, obj._szH = w, h
  return true
end

function S.PlaceIconClip(t)
  if not t then return nil end
  local clip, content = S.EnsureIconClip(t)
  if not clip then return nil end
  local w, h, anchor, inset = S.IconInnerSize(t)
  local same = clip._innerW and clip._innerH
    and math.abs((clip._innerW or 0) - w) < 0.5 and math.abs((clip._innerH or 0) - h) < 0.5
    and clip._clipAnchor == anchor
  if not same then
    if clip.ClearAllPoints then pcall(clip.ClearAllPoints, clip) end
    -- Taille posée explicitement : on ne laisse pas un défaut 100×50 recouvrir la fiole.
    S.SetSizeIf(clip, w, h)
    if clip.SetPoint and anchor then
      pcall(clip.SetPoint, clip, "CENTER", anchor, "CENTER", 0, 0)
    elseif clip.SetAllPoints and anchor then
      pcall(clip.SetAllPoints, clip, anchor)
    end
    if content then
      if content.ClearAllPoints then pcall(content.ClearAllPoints, content) end
      S.SetSizeIf(content, w, h)
      -- pas de SetAllPoints : le contenu doit rester à w×h, pas à une taille héritée.
    end
    clip._innerW, clip._innerH = w, h
    clip._clipAnchor = anchor
  end
  if clip.SetHorizontalScroll then pcall(clip.SetHorizontalScroll, clip, 0) end
  if clip.SetVerticalScroll then pcall(clip.SetVerticalScroll, clip, 0) end
  if content then
    if clip.SetScrollChild then pcall(clip.SetScrollChild, clip, content) end
    if content.ClearAllPoints then pcall(content.ClearAllPoints, content) end
    if content.SetPoint then pcall(content.SetPoint, content, "TOPLEFT", clip, "TOPLEFT", 0, 0) end
    S.SetSizeIf(content, w, h)
  end
  if clip.SetFrameLevel then
    local base = (t.iconSlot and t.iconSlot.GetFrameLevel and t.iconSlot:GetFrameLevel())
      or (t.GetFrameLevel and t:GetFrameLevel()) or 1
    pcall(clip.SetFrameLevel, clip, (base or 1) + 3)
  end
  if clip.Show then clip:Show() end
  if content and content.Show then content:Show() end
  if t.icon and t.icon.SetClipsChildren then pcall(t.icon.SetClipsChildren, t.icon, true) end
  return clip, content, w, h
end

-- Place une texture par un coin + SetSize (jamais seulement SetHeight après
-- un étirement LEFT/RIGHT, qui laisse la taille par défaut et déborde).
function S.PlaceClippedTex(tex, parent, w, h, x, y)
  if not tex then return end
  w, h = math.max(1, N(w) or 1), math.max(1, N(h) or 1)
  x, y = N(x) or 0, N(y) or 0
  if tex._clipParent == parent and tex._szW and tex._szH
    and math.abs(tex._szW - w) < 0.5 and math.abs(tex._szH - h) < 0.5
    and math.abs((tex._clipX or 0) - x) < 0.5 and math.abs((tex._clipY or 0) - y) < 0.5 then
    return
  end
  if tex.SetParent and parent then pcall(tex.SetParent, tex, parent) end
  if tex.ClearAllPoints then pcall(tex.ClearAllPoints, tex) end
  S.SetSizeIf(tex, w, h)
  if tex.SetPoint and parent then
    pcall(tex.SetPoint, tex, "BOTTOMLEFT", parent, "BOTTOMLEFT", x, y)
  end
  tex._clipParent, tex._clipX, tex._clipY = parent, x, y
end

function S.EnsureSlotZ(t)
  if t._slotZ then return t._slotZ end
  local parent = t.icon or t.slotBorder or t
  local ok, clip = pcall(CreateFrame, "ScrollFrame", nil, t)
  if not (ok and clip) then return nil end
  S.SetSizeIf(clip, 1, 1)
  if clip.EnableMouse then pcall(clip.EnableMouse, clip, false) end
  if clip.SetHorizontalScroll then pcall(clip.SetHorizontalScroll, clip, 0) end
  if clip.SetVerticalScroll then pcall(clip.SetVerticalScroll, clip, 0) end
  if clip.ScrollBar and clip.ScrollBar.Hide then pcall(clip.ScrollBar.Hide, clip.ScrollBar) end
  local okC, content = pcall(CreateFrame, "Frame", nil, clip)
  if not (okC and content) then return nil end
  if clip.SetScrollChild then pcall(clip.SetScrollChild, clip, content) end
  -- Taille posée dans ApplySlotZ (IconInnerSize), pas SetAllPoints.
  local zs = {}
  for i = 1, 3 do
    local fs = content.CreateFontString and content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    if not fs and type(CreateFrame) == "function" then
      -- harnais de tests : certains CreateFontString sont sur le cadre
    end
    if fs then
      if fs.SetText then fs:SetText("z") end
      if fs.SetTextColor then fs:SetTextColor(0.925, 0.788, 0.412) end
      if fs.SetAlpha then fs:SetAlpha(0) end
      if fs.Hide then fs:Hide() end
      zs[i] = { fs = fs, y = 0, age = -i * 0.55, born = false }
    end
  end
  clip._content, clip.z = content, zs
  t._slotZ = clip
  return clip
end

function S.ApplySlotZ(t, on)
  on = false
  if not t then return end
  if not on then
    if t._slotZ and t._slotZ.Hide then t._slotZ:Hide() end
    return
  end
  local clip = S.EnsureSlotZ(t)
  if not clip then return end
  local w, h, anchor, inset = S.IconInnerSize(t)
  local same = clip._innerW and clip._innerH
    and math.abs((clip._innerW or 0) - w) < 0.5 and math.abs((clip._innerH or 0) - h) < 0.5
    and clip._clipAnchor == anchor
  if not same then
    if clip.ClearAllPoints then pcall(clip.ClearAllPoints, clip) end
    S.SetSizeIf(clip, w, h)
    if clip.SetPoint and anchor then
      pcall(clip.SetPoint, clip, "CENTER", anchor, "CENTER", 0, 0)
    elseif clip.SetAllPoints and anchor then
      pcall(clip.SetAllPoints, clip, anchor)
    end
    if clip._content then
      if clip._content.ClearAllPoints then pcall(clip._content.ClearAllPoints, clip._content) end
      S.SetSizeIf(clip._content, w, h)
    end
    clip._innerW, clip._innerH = w, h
    clip._clipAnchor = anchor
  end
  if clip.Show then clip:Show() end
  -- Jamais cacher la fiole officielle (sinon le puits est noir en barre).
  -- Les z et la vague se dessinent dedans (clip), icône toujours visible.
  if t.icon and t.icon.Show then t.icon:Show() end
  if t.icon and t.icon.SetAlpha then t.icon:SetAlpha(1) end
  if t._hg and t._hg.Hide then t._hg:Hide() end
end

function S.TickSlotZ(dt)
  return
end
function S._TickSlotZRemoved(dt)
  local t = S.FlaskTile and S.FlaskTile() or (ns.Wide and ns.Wide.TotalTile and ns.Wide.TotalTile())
  if not (t and t._slotZ and S.TakesRestedZ()) then return end
  local clip = t._slotZ
  local w, h = clip._innerW, clip._innerH
  if not w or not h or w < 1 or h < 1 then
    w, h = S.IconInnerSize(t)
  end
  for i, z in ipairs(clip.z or {}) do
    z.age = (z.age or 0) + dt
    if z.age >= 0 then
      local life = 1.55
      local u = z.age % life
      local y = (u / life) * (h - 2)
      local a = 1
      if u < 0.15 then a = u / 0.15
      elseif u > life - 0.35 then a = math.max(0, (life - u) / 0.35) end
      local fs = z.fs
      if fs then
        local x = 2 + ((i - 1) % 3) * math.max(3, (w - 8) / 3)
        if not (fs._zx and fs._zy
            and math.abs((fs._zx or 0) - x) < 0.5 and math.abs((fs._zy or 0) - y) < 0.5) then
          if fs.ClearAllPoints then pcall(fs.ClearAllPoints, fs) end
          if fs.SetPoint then pcall(fs.SetPoint, fs, "BOTTOMLEFT", clip._content or clip, "BOTTOMLEFT", x, y) end
          fs._zx, fs._zy = x, y
        end
        if fs.SetAlpha then pcall(fs.SetAlpha, fs, a) end
        if fs.Show then fs:Show() end
      end
    end
  end
end

-- Rogne un calque (liquide, vague, z) à l'intérieur de l'icône de la case :
-- masque rond si le client le propose, sinon ScrollFrame, plus SetClipsChildren.
function S.IconMaskFor(t)
  if not t then return nil end
  if t.icon and t.icon._thMask then return t.icon._thMask end
  if t._flareMask then return t._flareMask end
  local slot = t.iconSlot or t.icon or t
  if type(slot.CreateMaskTexture) ~= "function" then return nil end
  local ok, m = pcall(slot.CreateMaskTexture, slot)
  if not (ok and m) then return nil end
  local path = (ns.STYLE and ns.STYLE.FLARE and ns.STYLE.FLARE.mask)
    or (ns.Style and ns.Style.FLARE and ns.Style.FLARE.mask)
    or "Interface\\CharacterFrame\\TempPortraitAlphaMask"
  pcall(m.SetTexture, m, path, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  if m.SetAllPoints and slot then pcall(m.SetAllPoints, m, slot) end
  t._flareMask = m
  if t.icon then t.icon._thMask = t.icon._thMask or m end
  return m
end

function S.ClipToIcon(frame, t)
  if not (frame and t) then return frame end
  local anchor = t.icon or t.slotBorder or t
  if frame.ClearAllPoints then pcall(frame.ClearAllPoints, frame) end
  if frame.SetAllPoints and anchor then pcall(frame.SetAllPoints, frame, anchor) end
  local w, h = 16, 16
  if anchor.GetWidth then w = N(anchor:GetWidth()) or w end
  if anchor.GetHeight then h = N(anchor:GetHeight()) or h end
  if frame.SetSize then pcall(frame.SetSize, frame, w, h) end
  if frame.SetClipsChildren then pcall(frame.SetClipsChildren, frame, true) end
  local mask = S.IconMaskFor(t)
  if mask and frame.AddMaskTexture then
    pcall(frame.AddMaskTexture, frame, mask)
  end
  if mask then
    local function maskTex(tex)
      if tex and tex.AddMaskTexture then pcall(tex.AddMaskTexture, tex, mask) end
    end
    maskTex(frame.blue) maskTex(frame.red) maskTex(frame.wave) maskTex(frame.bubbles)
    maskTex(frame.body) maskTex(frame.eatWave)
  end
  return frame, w, h, anchor
end

function S.EnsureCombatLiq(t)
  if not t then return nil end
  local _, content = S.PlaceIconClip(t)
  local parent = content or t
  if t._cLiq then
    if t._cLiq.SetParent and parent and t._cLiq.GetParent and t._cLiq:GetParent() ~= parent then
      pcall(t._cLiq.SetParent, t._cLiq, parent)
    end
    return t._cLiq
  end
  local ok, f = pcall(CreateFrame, "Frame", nil, parent)
  if not (ok and f) then return nil end
  S.SetSizeIf(f, 1, 1)
  if f.EnableMouse then pcall(f.EnableMouse, f, false) end
  local function tex(layer)
    if type(f.CreateTexture) ~= "function" then return nil end
    local tx = f:CreateTexture(nil, layer or "ARTWORK")
    return tx
  end
  f.blue = tex("ARTWORK")
  f.red = tex("ARTWORK")
  f.wave = tex("ARTWORK")
  f.bubbles = tex("OVERLAY")
  if f.bubbles and f.bubbles.SetTexture then pcall(f.bubbles.SetTexture, f.bubbles, S.COMBAT_A_SHEET) end
  t._cLiq = f
  return f
end

function S.ApplyCombatLiq(t)
  local Wd = ns.Wide
  t = t or S.FlaskTile() or (Wd and Wd.TotalTile and Wd.TotalTile())
  if not t then return end
  -- Plus de bandes rouge/bleu/vert par-dessus la fiole : icône de jeu, comme le sablier.
  if S.HideCombatLiq then S.HideCombatLiq(t) elseif t._cLiq and t._cLiq.Hide then t._cLiq:Hide() end
  local show = S.CombatStateOn and S.CombatStateOn()
  if not show then
    if t._stIcon and t._stIcon._kind == "combat" then S.HideStateIcon(t) end
    return
  end
  S.ApplyStateIcon(t, "combat", "pulse")
  do return end
  local style = S.CombatStyle()
  local fill = S.fill or {}
  local p = math.max(0, math.min(1, (N(fill.p) or 0) * (N(fill.drain) or 1)))
  local grey = N(fill.grey) or 0
  local liq = t._cLiq
  if not show then
    return
  end
  liq = S.EnsureCombatLiq(t)
  if not liq then return end
  local clip, content, w, h = S.PlaceIconClip(t)
  w, h = w or 16, h or 16
  if liq.SetParent and content and liq._clipParent ~= content then pcall(liq.SetParent, liq, content) end
  -- SetSize explicite, pas SetAllPoints (évite d'hériter d'une taille 100×50).
  if S.SetSizeIf(liq, w, h) or liq._clipParent ~= (content or clip) then
    if liq.ClearAllPoints then pcall(liq.ClearAllPoints, liq) end
    if liq.SetPoint then pcall(liq.SetPoint, liq, "BOTTOMLEFT", content or clip, "BOTTOMLEFT", 0, 0) end
    liq._clipParent = content or clip
  end
  -- Remplissage depuis le bas, strictement dans le clip (jamais au-dessus de h).
  local inset = math.max(1, w * 0.18)
  local bodyH = math.max(1, (h * 0.72) * p)
  local wave = 0.04 * h * math.sin((S._phase or 0) * 2 * math.pi)
  bodyH = math.max(1, math.min(h * 0.82, bodyH + wave))
  local baseY = math.max(0, h * 0.10)
  if baseY + bodyH > h then bodyH = math.max(1, h - baseY) end
  local redH = bodyH * 0.38
  local blueH = bodyH - redH
  local function place(tex, height, y, r, g, b, a)
    if not tex or height < 0.5 then
      if tex and tex.Hide then tex:Hide() end
      return
    end
    if y < 0 then height = height + y y = 0 end
    if y + height > h then height = h - y end
    if height < 0.5 then
      if tex.Hide then tex:Hide() end
      return
    end
    local tw = math.max(1, w - inset * 2)
    if S.SetSizeIf(tex, tw, height) or tex._clipY ~= y then
      if tex.ClearAllPoints then pcall(tex.ClearAllPoints, tex) end
      if tex.SetPoint then pcall(tex.SetPoint, tex, "BOTTOMLEFT", liq, "BOTTOMLEFT", inset, y) end
      tex._clipY = y
    end
    if tex.SetTexture then pcall(tex.SetTexture, tex, "Interface\\Buttons\\WHITE8X8") end
    if tex.SetAlpha then pcall(tex.SetAlpha, tex, 1) end
    if tex.SetVertexColor then pcall(tex.SetVertexColor, tex, r, g, b, a) end
    if tex.Show then tex:Show() end
  end
  local cr = (grey > 0) and (0.42 + (0.71 - 0.42) * (1 - grey)) or 0.71
  -- Wd.SEG_COLORS approx: red 0.616,0.278,0.227  blue 0.329,0.408,0.604
  place(liq.blue, blueH, baseY, 0.329, 0.408, 0.604, 0.72)
  place(liq.red, redH, baseY + blueH, 0.616, 0.278, 0.227, 0.78)
  if liq.wave then
    local wy = baseY + bodyH - 1
    local wh = math.max(1, h * 0.08)
    if wy + wh > h then wy = math.max(0, h - wh) end
    place(liq.wave, wh, wy, 0.82, 0.47, 0.37, 0.55)
  end
  -- Bulles (style A) : feuille par-dessus le liquide, seulement si assez rempli.
  if liq.bubbles then
    if style == "bubbles" and p > 0.15 and grey < 0.5 then
      if liq.bubbles.SetTexture then pcall(liq.bubbles.SetTexture, liq.bubbles, S.COMBAT_A_SHEET) end
      S.PlaceClippedTex(liq.bubbles, liq, w, h, 0, 0)
      local fi = S._frame.combatA or 1
      if liq.bubbles.SetTexCoord then pcall(liq.bubbles.SetTexCoord, liq.bubbles, S.TexCoord(fi, 32)) end
      if liq.bubbles.SetAlpha then pcall(liq.bubbles.SetAlpha, liq.bubbles, math.min(1, (p - 0.15) / 0.25)) end
      if liq.bubbles.Show then liq.bubbles:Show() end
    else
      if liq.bubbles.Hide then liq.bubbles:Hide() end
    end
  end
  local mask = S.IconMaskFor(t)
  if mask then
    local function maskTex(tex)
      if tex and tex.AddMaskTexture then pcall(tex.AddMaskTexture, tex, mask) end
    end
    maskTex(liq.blue) maskTex(liq.red) maskTex(liq.wave) maskTex(liq.bubbles)
  end
  if liq.SetFrameLevel and t.GetFrameLevel then
    pcall(liq.SetFrameLevel, liq, (t:GetFrameLevel() or 1) + 2)
  end
  if liq.SetAlpha then pcall(liq.SetAlpha, liq, 1) end
  if liq.Show then liq:Show() end
end

function S.ApplyTotal(t)
  local Wd = ns.Wide
  t = t or (Wd and Wd.TotalTile and Wd.TotalTile())
  if not (t and t.data and t.data.kind == "total") then
    -- tenter toutes les cases total
    local ui = ns.UI
    local tiles = ui and ui.embed and ui.embed.tiles
    if tiles then
      for i = 1, #tiles do
        local tt = tiles[i]
        if tt and tt.data and tt.data.kind == "total" then S.ApplyTotal(tt) end
      end
    end
    return
  end
  local act = S.Active()
  local F = ns.Flight
  if act == "flight" or (act == "drop" and F and (F._vis or 0) > 0) then
    S.ApplySlotZ(t, false)
    if Wd and Wd.ApplyHourglassTo then Wd.ApplyHourglassTo(t, F._vis or 0) end
    if Wd and Wd.SyncFlaskHit then Wd.SyncFlaskHit(t, F and F._vis or 0) end
    return
  end
  if act == "sleepingbag" then
    S.ApplySlotZ(t, false)
    HideSymbol(t)
    S.ApplySleepingBag(t)
  elseif act == "rested" then
    S.ApplySlotZ(t, false)
    HideSymbol(t)
    S.ApplyRestIcon(t)
  elseif act ~= "drop" and S.SHEETS[act] then
    S.ApplySlotZ(t, false)
    HideBagIcon(t)
    S.ApplySheet(t, act)
  else
    S.ApplySlotZ(t, false)
    HideSymbol(t)
    if S.CombatStateOn and S.CombatStateOn() then
      S.ApplyStateIcon(t, "combat", "pulse")
    elseif S.Want and S.Want("eating") then
      S.ApplyEatDisc(t)
    elseif t._stIcon and S.HideStateIcon then
      S.HideStateIcon(t)
    end
  end
  if act ~= "rested" and S.HideRestIcon then S.HideRestIcon(t) end
  if act ~= "fishing" and not (S.CombatStateOn and S.CombatStateOn()) then
    if t._stIcon and t._stIcon._kind and S.HideStateIcon then
      if act ~= "combat" then
        local kind = t._stIcon._kind
        if kind == "fishing" or kind == "combat" then S.HideStateIcon(t) end
      end
    end
  end
  if Wd and Wd.SyncFlaskHit then Wd.SyncFlaskHit(t) end
end

------------------------------------------------------------------------------
-- Éclat sur la case métier (maître à proximité)
------------------------------------------------------------------------------
function S.ProfessionTiles()
  local out = {}
  local ui = ns.UI
  local tiles = (ui and ui.embed and ui.embed.tiles) or {}
  for i = 1, #tiles do
    local t = tiles[i]
    local d = t and t.data
    if d and not d.placeholder and (d.kind == "profession" or d.kind == "secondary") and d.id ~= "riding" then
      out[#out + 1] = t
    end
  end
  return out
end

function S.EnsureGlint(t)
  if t._trGlint then return t._trGlint end
  local parent = t.icon or t
  if not parent or type(parent.CreateTexture) ~= "function" then
    if type(t.CreateTexture) ~= "function" then return nil end
    parent = t
  end
  local tex = parent:CreateTexture(nil, "OVERLAY")
  if not tex then return nil end
  if tex.SetTexture then pcall(tex.SetTexture, tex, S.TRAINER_SHEET) end
  if tex.SetSize then pcall(tex.SetSize, tex, 14, 14) end
  t._trGlint = tex
  return tex
end

function S.ApplyTrainerGlints()
  local on = S.Want("trainer")
  local tiles = S.ProfessionTiles()
  for i = 1, #tiles do
    local t = tiles[i]
    if on then
      local g = S.EnsureGlint(t)
      if g then
        local a = t.icon or t
        if g.ClearAllPoints then pcall(g.ClearAllPoints, g) end
        if g.SetPoint then pcall(g.SetPoint, g, "TOPRIGHT", a, "TOPRIGHT", 1, 1) end
        if g.SetTexCoord then pcall(g.SetTexCoord, g, TexCoord(S._frame.trainer or 1, 32)) end
        if g.Show then g:Show() end
      end
    elseif t._trGlint and t._trGlint.Hide then
      t._trGlint:Hide()
    end
  end
end

------------------------------------------------------------------------------
-- Infobulle du puits
------------------------------------------------------------------------------
S.TIPS = {
  death     = { "Mort ou fantôme", "Le suivi est en pause jusqu'à la résurrection." },
  flight    = { "En pause pendant le vol", "Le scan reprend dès l'atterrissage." },
  transport = { "En pause pendant le trajet", "Le scan reprend à l'arrivée." },
  afk       = { "Absent", "Tu es absent." },
  bags      = { "Sacs pleins", "Le butin sera perdu." },
  fishing   = { "En train de pêcher", "La ligne est lancée." },
  swimming  = { "À la nage", "Tu nages." },
  durability= { "Équipement usé", "Une pièce d'équipement est sous 20 %." },
  rested    = { "Au repos", "Tu te reposes à l'auberge ou en capitale." },
}
S.COMBAT_TIP = "En combat : XP et armes en cours"

function S.FormatExact(sec)
  sec = N(sec)
  if not sec then return nil end
  sec = math.floor(sec + 0.5)
  if sec < 0 then sec = 0 end
  if sec < 60 then return string.format(Tr["%d s"], sec) end
  local m = math.floor(sec / 60)
  local s = sec - m * 60
  if m < 60 then
    if s == 0 then return string.format(Tr["%d min"], m) end
    return string.format(Tr["%d min %d s"], m, s)
  end
  local h = math.floor(m / 60)
  m = m - h * 60
  return string.format(Tr["%d h %02d min"], h, m)
end

function S.StopTipTicker()
  S._tipOwner, S._tipRefresh, S._tipAcc = nil, nil, nil
  local f = S._tipFrame
  if f and f.SetScript then pcall(f.SetScript, f, "OnUpdate", nil) end
  if f and f.Hide then pcall(f.Hide, f) end
end

function S._onTipUpdate(_, elapsed)
  if not S._tipOwner or not S._tipRefresh then
    S.StopTipTicker()
    return
  end
  local o = S._tipOwner
  if o.IsMouseOver then
    local ok, over = pcall(o.IsMouseOver, o)
    if ok and over == false then
      S.StopTipTicker()
      local tt = _G.GameTooltip
      if tt and tt.Hide then
        if not tt.IsOwned or (select(1, pcall(tt.IsOwned, tt, o))) then pcall(tt.Hide, tt) end
      end
      return
    end
  end
  S._tipAcc = (S._tipAcc or 0) + ((ns.N and ns.N(elapsed)) or tonumber(elapsed) or 0)
  if S._tipAcc >= 0.25 then
    S._tipAcc = 0
    pcall(S._tipRefresh)
  end
end

function S.StartTipTicker(owner, refresh)
  if not (owner and type(refresh) == "function") then return end
  S._tipOwner, S._tipRefresh, S._tipAcc = owner, refresh, 0
  if not S._tipFrame then
    local ok, f = pcall(CreateFrame, "Frame", nil, _G.UIParent)
    if ok and f then
      if f.EnableMouse then pcall(f.EnableMouse, f, false) end
      if f.Hide then f:Hide() end
      S._tipFrame = f
    end
  end
  local f = S._tipFrame
  if not f then return end
  if f.SetScript and not f._tipHooked then
    f._tipHooked = true
    pcall(f.SetScript, f, "OnUpdate", S._onTipUpdate)
  end
  if f.Show then pcall(f.Show, f) end
end

-- Lignes d'état (sac / repos / feu) : uniquement des valeurs lues, jamais inventées.
function S.FillStateTip(tt)
  if not tt then return nil end
  local act = S.Active and S.Active()
  if act ~= "sleepingbag" and act ~= "rested" then
    return nil
  end
  local function line(text, r, g, b)
    if type(tt.AddLine) == "function" and text and text ~= "" then
      pcall(tt.AddLine, tt, text, r or 1, g or 1, b or 1, true)
    end
  end
  local function title(text)
    if type(tt.SetText) == "function" then
      pcall(tt.SetText, tt, text, 1, 0.82, 0)
    else
      line(text, 1, 0.82, 0)
    end
  end
  if act == "sleepingbag" then
    local stacks = S.SleepingBagStacks and S.SleepingBagStacks() or 0
    if stacks > 3 then stacks = 3 end
    local step = (stacks < 1) and 1 or stacks
    title(Tr["Sac de couchage"])
    line(string.format(Tr["Palier : %d/3 (%d %% d'XP)"], step, step), 1, 1, 1)
    local started = N(S._bagStartedAt)
    if started and started > 0 then
      local elapsed = Now() - started
      if elapsed < 0 then elapsed = 0 end
      local ev = S.FormatExact(elapsed)
      if ev then line(string.format(Tr["Depuis le début : %s"], ev), 1, 1, 1) end
      if stacks < 3 and (S.BAG_TIER_SEC or 60) > 0 then
        -- palier k après k minutes de charge
        local nextAt = started + (stacks + 1) * (S.BAG_TIER_SEC or 60)
        local remain = nextAt - Now()
        if remain < 0 then remain = 0 end
        local rv = S.FormatExact(remain)
        if rv then line(string.format(Tr["Prochain palier : %s"], rv), 1, 1, 1) end
      elseif stacks >= 3 then
        line(Tr["Palier maximum atteint"], 1, 0.93, 0.80)
      end
    end
    return "sleepingbag"
  end
  if act == "rested" then
    title(Tr["Zone de repos"])
    S.NoteRestZone()
    local entered = N(S._restEnteredAt)
    if entered and entered > 0 then
      local ev = S.FormatExact(Now() - entered)
      if ev then line(string.format(Tr["Dans la zone depuis : %s"], ev), 1, 1, 1) end
    end
    local rest = N(Call(_G.GetXPExhaustion))
    local maxxp = N(Call(_G.UnitXPMax, "player"))
    if rest and rest > 0 then
      local pct
      if maxxp and maxxp > 0 then pct = math.floor(rest / maxxp * 100 + 0.5) end
      if pct then
        line(string.format(Tr["XP de repos : %s (%s %% du niveau)"], tostring(math.floor(rest + 0.5)), tostring(pct)), 1, 1, 1)
      else
        line(string.format(Tr["XP de repos : %s"], tostring(math.floor(rest + 0.5))), 1, 1, 1)
      end
    end
    return "rested"
  end
  return nil
end

function S.ShowExplanation(owner)
  if S._suppressTip then return end
  local act = S.Active()
  if act == "flight" then
    local F = ns.Flight
    if F and F.OnTransport and F.OnTransport() and not (F.OnTaxi and F.OnTaxi()) then act = "transport" end
    if S._sim.transport and not S._sim.flight then act = "transport" end
  end
  if act == "drop" and S.LiveFlight() then
    local F = ns.Flight
    if S._sim.transport or (F and F.OnTransport and F.OnTransport() and not (F.OnTaxi and F.OnTaxi())) then
      act = "transport"
    else
      act = "flight"
    end
  end
  if act == "drop" and ((S.CombatStateOn and S.CombatStateOn()) or (S.LiveCombat and S.LiveCombat())) then
    act = "combat"
  end
  if act == "drop" then return end
  local tt = _G.GameTooltip
  if not (tt and owner) then return end
  if type(tt.SetOwner) == "function" then pcall(tt.SetOwner, tt, owner, "ANCHOR_RIGHT") end
  if type(tt.ClearLines) == "function" then pcall(tt.ClearLines, tt) end
  if act == "sleepingbag" or act == "rested" then
    S.FillStateTip(tt)
    local Wd = ns.Wide
    if Wd and Wd.FillTotalTip then
      if tt.AddLine then pcall(tt.AddLine, tt, " ") end
      Wd.FillTotalTip(tt)
    end
    if type(tt.Show) == "function" then pcall(tt.Show, tt) end
    S.StartTipTicker(owner, function() S.ShowExplanation(owner) end)
    return
  end
  if act == "combat" then
    local title = Tr[S.COMBAT_TIP] or S.COMBAT_TIP
    if type(tt.SetText) == "function" then
      pcall(tt.SetText, tt, title, 1, 0.82, 0)
    elseif type(tt.AddLine) == "function" then
      pcall(tt.AddLine, tt, title, 1, 0.82, 0, true)
    end
  else
    local tip = S.TIPS[act]
    if not tip then return end
    local title, line = Tr[tip[1]] or tip[1], Tr[tip[2]] or tip[2]
    if type(tt.SetText) == "function" then
      pcall(tt.SetText, tt, title, 1, 0.82, 0)
    elseif type(tt.AddLine) == "function" then
      pcall(tt.AddLine, tt, title, 1, 0.82, 0, true)
    end
    if type(tt.AddLine) == "function" then
      pcall(tt.AddLine, tt, line, 1, 1, 1, true)
    end
  end
  if type(tt.Show) == "function" then pcall(tt.Show, tt) end
end

------------------------------------------------------------------------------
-- Cadence
------------------------------------------------------------------------------
function S.RestedOnly()
  -- z + vague de repos : pas besoin de repeindre tout le puits à 20 i/s.
  if S.Want("trainer") or S.FillBusy() then return false end
  if (S._jolt or 0) > 0 or S._lvlT or S._sparkT then return false end
  local F = ns.Flight
  if F and (F.Paused and F.Paused() or (F._vis or 0) > 0) then return false end
  return S.Active() == "rested"
end

function S.NeedsDriver()
  local act = S.Active()
  -- sac de couchage : pictogramme statique, pas d'OnUpdate.
  if act and act ~= "drop" and act ~= "sleepingbag" then return true end
  if S.Want("trainer") then return true end
  if S.Want("eating") then return true end
  if act == "rested" then return true end
  if S.CombatStateOn and S.CombatStateOn() then return true end
  if S.FillBusy() then return true end
  if (S._jolt or 0) > 0 then return true end
  if S._lvlT or S._sparkT then return true end
  if S._sparkQ and S._sparkQ[1] then return true end
  local F = ns.Flight
  if F and (F.Paused and F.Paused() or (F._vis or 0) > 0) then return true end
  return false
end

function S.StartDriver()
  local F = ns.Flight
  if F and F.StartVisualDriver then return F.StartVisualDriver() end
  return nil
end

function S.TickSheets(dt)
  for id, sh in pairs(S.SHEETS) do
    S._acc[id] = (S._acc[id] or 0) + dt
    if S._acc[id] >= (sh.step or 0.1) then
      local steps = math.floor(S._acc[id] / sh.step)
      S._acc[id] = S._acc[id] - steps * sh.step
      S._frame[id] = ((S._frame[id] or 1) - 1 + steps) % sh.frames + 1
    end
  end
  S._acc.combatA = (S._acc.combatA or 0) + dt
  if S._acc.combatA >= 0.08 then
    -- bulles plus rapides que la nage (~12,5 i/s)
    local steps = math.floor(S._acc.combatA / 0.08)
    S._acc.combatA = S._acc.combatA - steps * 0.08
    S._frame.combatA = ((S._frame.combatA or 1) - 1 + steps) % 32 + 1
  end
  S._acc.trainer = (S._acc.trainer or 0) + dt
  if S._acc.trainer >= 0.1 then
    local steps = math.floor(S._acc.trainer / 0.1)
    S._acc.trainer = S._acc.trainer - steps * 0.1
    S._frame.trainer = ((S._frame.trainer or 1) - 1 + steps) % 32 + 1
  end
end


S.COMBAT_REFRESH = 0.75
S.PAINT_WAIT = 0.2
function S.CombatQuiet()
  return (ns.InCombat and ns.InCombat()) and true or false
end
function S.Defer(kind)
  S._deferred = S._deferred or {}
  if kind then S._deferred[kind] = true end
end
function S.FlushDeferred()
  S._flushing = true
  local d = S._deferred
  S._deferred = nil
  if d and d.auras then pcall(S.ScanPlayerAuras, true) end
  if d and d.bags then pcall(S.CheckBags) end
  pcall(S.Refresh, "flush")
  S._flushing = false
  if ns.StepGC then pcall(ns.StepGC, 400) end
end

function S.Tick(dt)
  dt = N(dt) or 0
  if dt <= 0 then return end
  if dt > 0.25 then dt = 0.25 end
  -- pêche récente (pour le sursaut à la prise)
  if S.LiveFishing() then S._fishUntil = Now() + 2 end
  S._jolt = math.max(0, (S._jolt or 0) - dt * 4)
  S._phase = (S._phase or 0) + dt * 0.7
  if S._phase > 1 then S._phase = S._phase - math.floor(S._phase) end
  if S._sparkT ~= nil then S.TickBarSpark(dt) end
  if S._lvlT ~= nil then S.TickLevelUp(dt) end
  if S.Active and S.Active() == "rested" then
    S.ApplyRestIcon()
  end
  if S.RestedOnly and S.RestedOnly() then
    S.ApplyRestIcon()
    return
  end
  S.SyncFillTargets()
  local rate = S.FILL_RATE
  local f = S.fill
  f.p = Approach(f.p, f.targetP, rate, dt)
  f.grey = Approach(f.grey, f.targetGrey, rate, dt)
  f.drain = Approach(f.drain, f.targetDrain, rate, dt)
  S.TickSheets(dt)
  S.ApplyCombatLiq()
  S.ApplyRegenWave(dt)
  S.ApplyTrainerGlints()
  S.TickSlotZ(dt)
  local quiet = S.CombatQuiet and S.CombatQuiet()
  local now = Now()
  if (not quiet) or (not S._paintAt) or (now - S._paintAt) >= (S.PAINT_WAIT or 0.2) then
    S._paintAt = now
    S.ApplyTotal()
    S.ApplyFlaskFill()
  elseif S.FillBusy and S.FillBusy() then
    S.ApplyFlaskFill()
  end
end

function S.QuietSkills(sec)
  local ui = ns.UI
  if not ui then return end
  local now = Now()
  ui._skillQuietUntil = math.max(ui._skillQuietUntil or 0, now + (sec or 2))
end

-- Changement de zone / repos : visuel + toast maître, pas de Collect ni de rescan complet.
function S.NoteRestZone()
  local resting = Call(IsResting) and true or false
  if resting then
    S._restEnteredAt = S._restEnteredAt or Now()
  else
    S._restEnteredAt = nil
  end
  return resting
end

function S.OnRestOrZone(reason)
  S.QuietSkills(2)
  pcall(S.NoteRestZone)
  pcall(S.SyncSleepingBag)
  S.SyncFillTargets()
  if S.NeedsDriver() then S.StartDriver() end
  S.ApplyTotal()
  S.ApplyFlaskFill()
  S.ApplyCombatLiq()
  S.ApplyRegenWave(0)
  S.TickSlotZ(0)
  local RT = ns.RankToast
  if RT and RT.Refresh then pcall(RT.Refresh, reason or "") end
end

function S.Refresh(reason)
  reason = reason or ""
  if S.CombatQuiet and S.CombatQuiet() and reason ~= "flush" and reason ~= "PLAYER_REGEN_ENABLED" and not S._flushing then
    S.Defer("refresh")
    if reason == "BAG_UPDATE_DELAYED" or reason == "LOOT_CLOSED" or reason == "UI_ERROR_MESSAGE" then S.Defer("bags") end
    if S.NeedsDriver() then S.StartDriver() end
    local now = Now()
    if not S._paintAt or (now - S._paintAt) >= (S.COMBAT_REFRESH or 0.75) then
      S._paintAt = now
      S.ApplyTotal()
    end
    return
  end
  pcall(S.SyncSleepingBag)
  S.SyncFillTargets()
  if S.LiveFishing() then S._fishUntil = Now() + 2 end
  if S.NeedsDriver() then S.StartDriver() end
  S.ApplyTotal()
  S.ApplyFlaskFill()
  S.ApplyCombatLiq()
  S.ApplyRegenWave(0)
  S.ApplyTrainerGlints()
  -- Comptage des sacs : pas à chaque Refresh (UNIT_AURA, etc.).
  if reason == "BAG_UPDATE_DELAYED" or reason == "LOOT_CLOSED"
    or reason == "PLAYER_ENTERING_WORLD" or reason == "option"
    or reason == "test" or reason == "test-off" or reason == "UI_ERROR_MESSAGE" then
    S.CheckBags()
  end
  if reason == "UPDATE_INVENTORY_DURABILITY" or reason == "PLAYER_EQUIPMENT_CHANGED"
    or reason == "PLAYER_ENTERING_WORLD" or reason == "option"
    or reason == "test" or reason == "test-off" then
    S.CheckDurability()
  end
  if not (ns.PausedForFlight and ns.PausedForFlight()) then pcall(S.FlushPendingToasts) end
  local RT = ns.RankToast
  if RT and RT.Refresh then pcall(RT.Refresh, reason) end
end

function S.OnCatch()
  if S._sim.fishing or S.LiveFishing() or Now() <= (S._fishUntil or 0) then
    S._jolt = 1
    S.StartDriver()
  end
end

------------------------------------------------------------------------------
-- Options
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- Toasts discrets (une fois jusqu'à disparition de la condition)
------------------------------------------------------------------------------
function S.SpawnOnce(key, icon, title, kind)
  local ui = ns.UI
  if not (ui and ui.SpawnDrop) then return nil end
  if ns.PausedForFlight and ns.PausedForFlight() then
    S._pendingToast = S._pendingToast or {}
    S._pendingToast[key] = { icon = icon, title = title, kind = kind }
    return nil
  end
  local ok, f = pcall(ui.SpawnDrop, ui, icon, title, nil, nil, nil, nil, {
    kind = kind, dedupeKey = key,
  })
  return ok and f or nil
end

function S.FlushPendingToasts()
  local pend = S._pendingToast
  if not pend then return end
  S._pendingToast = nil
  for key, t in pairs(pend) do
    if key == "bags-full" and not S.LiveBags() then
    elseif key == "low-durability" and not S.LiveDurability() then
    else
      S.SpawnOnce(key, t.icon, t.title, t.kind)
    end
  end
end

function S.NotifyBags(force)
  if not S.Opt("slotBags") and not force then return end
  if S._bagsToastShown and not force then return end
  S._bagsToastShown = true
  return S.SpawnOnce("bags-full",
    "Interface\\AddOns\\Dropamine\\Media\\Bags-Icon",
    Tr["Sacs pleins : le butin sera perdu"],
    "bags-full")
end

function S.NotifyDurability(force)
  if not S.Opt("slotDurability") and not force then return end
  if S._duraToastShown and not force then return end
  S._duraToastShown = true
  return S.SpawnOnce("low-durability",
    "Interface\\AddOns\\Dropamine\\Media\\Durability-Icon",
    Tr["Équipement usé : une pièce est sous 20 %"],
    "durability")
end

function S.BagsLoading()
  local F = ns.Flight
  if F and (F.SafetyPause and F.SafetyPause()) then return true end
  if F and F._loading then return true end
  return false
end

function S.CheckBags()
  if S.CombatQuiet and S.CombatQuiet() and not S._flushing then
    S.Defer("bags")
    return
  end
  local now = Now()
  -- simulation DEV : toast immédiat, sans debounce
  if S._sim.bags then
    if not S.Opt("slotBags") then return end
    if not S._bagsToastShown then S.NotifyBags() end
    S._bagsWereFull = true
    return
  end
  if not S.Opt("slotBags") then
    S._bagsToastShown, S._bagsWereFull, S._bagsZeroSince = false, false, nil
    return
  end
  if S.BagsLoading() then return end
  local free = S.FreeBagSlots()
  -- Pas plein (places libres, lecture ratée, ou fin de simulation) : retirer le marqueur.
  if free == nil or free > 0 then
    S._bagsToastShown = false
    S._bagsWereFull = false
    if free and free > 0 then
      S._bagsLastFree = free
      S._bagsZeroSince = nil
    end
    return
  end
  -- 0 place générale : attendre une confirmation (BAG_UPDATE renvoie souvent 0 un instant).
  S._bagsZeroSince = S._bagsZeroSince or now
  local wait = S.BAG_CONFIRM or 0.75
  if (now - S._bagsZeroSince) < wait then
    S._bagsAt = now
    if type(_G.C_Timer) == "table" and type(_G.C_Timer.After) == "function" then
      if not S._bagsTimer then
        S._bagsTimer = true
        _G.C_Timer.After(wait, function()
          S._bagsTimer = nil
          pcall(S.CheckBags)
        end)
      end
    end
    return
  end
  S._bagsAt = now
  S._bagsLastFree = 0
  if not S._bagsToastShown then S.NotifyBags() end
  S._bagsWereFull = true
end

function S.CheckDurability()
  if S.LiveDurability() and S.Opt("slotDurability") then
    if not S._duraToastShown then S.NotifyDurability() end
  else
    local r = S.LowestDurability()
    if r == nil or r >= 0.20 then S._duraToastShown = false end
  end
end

function S.OnInvFullError(event, msg, ...)
  local s = tostring(msg or event or "")
  local f = (ns.Fold and ns.Fold(s)) or s:lower()
  if (f:find("inventaire", 1, true) and f:find("plein", 1, true))
    or (f:find("inventory", 1, true) and f:find("full", 1, true))
    or f:find("bags are full", 1, true) or f:find("sacs sont pleins", 1, true)
    or f:find("err_inv_full", 1, true) then
    if ns.Efficiency and ns.Efficiency.NoteBagMiss then pcall(ns.Efficiency.NoteBagMiss) end
    S.CheckBags()
  end
end

------------------------------------------------------------------------------
-- Nettoyage des calques (plus d'état repas en 3.6.3)
------------------------------------------------------------------------------
function S._DroppedEnsureRegenWave(t)
  if not t then return nil end
  local _, content, w, h = S.PlaceIconClip(t)
  -- Uniquement dans le clip de l'icône : jamais sur la case (ça recouvrirait le compteur).
  local parent = content
  if not parent then return t._eat end
  if t._eat then
    if parent then
      if t._eat.body and t._eat.body.SetParent then pcall(t._eat.body.SetParent, t._eat.body, parent) end
      if t._eat.wave and t._eat.wave.SetParent then pcall(t._eat.wave.SetParent, t._eat.wave, parent) end
      if t._eat.wave2 and t._eat.wave2.SetParent then pcall(t._eat.wave2.SetParent, t._eat.wave2, parent) end
      if t._eat.food and t._eat.food.SetParent then pcall(t._eat.food.SetParent, t._eat.food, parent) end
      if t._eat.drink and t._eat.drink.SetParent then pcall(t._eat.drink.SetParent, t._eat.drink, parent) end
    end
    -- le corps n'est plus peint (le vrai remplissage reste) ; on le garde caché
    if t._eat.body and t._eat.body.Hide then t._eat.body:Hide() end
    S.EnsureEatIcons(t._eat, parent, w, h)
    return t._eat
  end
  if not (parent and type(parent.CreateTexture) == "function") then return nil end
  local function mk(layer)
    local wave = parent:CreateTexture(nil, layer or "ARTWORK", nil, 4)
    if not wave then return nil end
    local tex = (ns.Rested and ns.Rested.WAVE_TEX) or (MEDIA .. "Dropamine-Wave")
    if wave.SetTexture then pcall(wave.SetTexture, wave, tex) end
    S.PlaceClippedTex(wave, parent, w or 16, 1, 0, 0)
    if wave.Hide then wave:Hide() end
    return wave
  end
  local body = parent:CreateTexture(nil, "ARTWORK", nil, 3)
  if body then
    if body.SetTexture then pcall(body.SetTexture, body, "Interface\\Buttons\\WHITE8X8") end
    S.PlaceClippedTex(body, parent, w or 16, 1, 0, 0)
    if body.Hide then body:Hide() end
  end
  local wave, wave2 = mk("ARTWORK"), mk("OVERLAY")
  if not wave then return nil end
  t._eat = { body = body, wave = wave, wave2 = wave2, u = 0 }
  S.EnsureEatIcons(t._eat, parent, w, h)
  return t._eat
end

-- Quand un état s'arrête : cacher et remettre à zéro (alpha 0, hauteur 0)
-- pour qu'aucun trait rouge/bleu ne reste au bas de la fiole.
local function HideTex(tex)
  if not tex then return end
  if tex.SetAlpha then pcall(tex.SetAlpha, tex, 0) end
  if tex.SetHeight then pcall(tex.SetHeight, tex, 0) end
  tex._szH, tex._clipY = 0, nil
  if tex.Hide then tex:Hide() end
end

local function HideOverlay(frame)
  if not frame then return end
  if frame.red then HideTex(frame.red) end
  if frame.blue then HideTex(frame.blue) end
  if frame.green then HideTex(frame.green) end
  if frame.wave then HideTex(frame.wave) end
  if frame.wave2 then HideTex(frame.wave2) end
  if frame.body then HideTex(frame.body) end
  if frame.icon then HideTex(frame.icon) end
  if frame.glyph then HideTex(frame.glyph) end
  if frame.food then HideTex(frame.food) end
  if frame.drink then HideTex(frame.drink) end
  if frame.drop then HideTex(frame.drop) end
  if frame.spill then HideTex(frame.spill) end
  if frame.bubbles then
    if frame.bubbles.Hide then HideTex(frame.bubbles)
    else
      local i, b = 1, frame.bubbles[1]
      while b do HideTex(b); i = i + 1; b = frame.bubbles[i] end
    end
  end
  if frame.SetAlpha then pcall(frame.SetAlpha, frame, 0) end
  if frame.Hide then frame:Hide() end
end

S.HideFlaskOverlay = HideOverlay

function S.HideRegenWave(t)
  t = t or (S.FlaskTile and S.FlaskTile())
  local e = t and t._eat
  if not e then
    S._eatOn = false
    return
  end
  HideOverlay(e)
  S._eatOn = false
end

function S.HideCombatLiq(t)
  t = t or (S.FlaskTile and S.FlaskTile())
  if t and t._cLiq then HideOverlay(t._cLiq) end
end


-- Icônes de jeu (nourriture / boisson). Un état, deux rendus (grille / barre).
S.EAT_ICON = {
  food  = MEDIA .. "Food-Icon",
  drink = MEDIA .. "Drink-Icon",
}

function S.EatIconPath(kind)
  if kind == "drink" then return S.EAT_ICON.drink end
  return S.EAT_ICON.food
end

function S.EnsureEatIcons(e, parent, w, h)
  if not (e and parent and type(parent.CreateTexture) == "function") then return e end
  if not e.food then
    e.food = parent:CreateTexture(nil, "OVERLAY", nil, 6)
    if e.food then
      S.PlaceClippedTex(e.food, parent, w or 8, 1, 0, 0)
      if e.food.Hide then e.food:Hide() end
    end
  end
  if not e.drink then
    e.drink = parent:CreateTexture(nil, "OVERLAY", nil, 7)
    if e.drink then
      S.PlaceClippedTex(e.drink, parent, w or 8, 1, 0, 0)
      if e.drink.Hide then e.drink:Hide() end
    end
  end
  return e
end

local function PlaceGameIcon(tex, path, parent, side, x, y)
  if not (tex and path and parent) then return end
  side = math.max(1, N(side) or 1)
  if tex.SetTexture then pcall(tex.SetTexture, tex, path) end
  if tex.SetTexCoord then pcall(tex.SetTexCoord, tex, 0.07, 0.93, 0.07, 0.93) end
  if tex.SetVertexColor then pcall(tex.SetVertexColor, tex, 1, 1, 1, 1) end
  if tex.SetAlpha then pcall(tex.SetAlpha, tex, 1) end
  S.PlaceClippedTex(tex, parent, side, side, x or 0, y or 0)
  if tex.Show then tex:Show() end
end

-- Grille : grande icône de jeu dans la zone de la fiole (le compteur reste lisible).
-- Barre : petite icône en coin + vague colorée.
function S.PlaceEatIcons(t, e, kind, parent, w, H, bar)
  if not (e and parent) then return end
  w, H = w or 16, H or 16
  kind = kind or "food"
  local foodPath, drinkPath = S.EAT_ICON.food, S.EAT_ICON.drink
  -- Badge en coin (haut-droit), ~1/3 de l'icône en grille ; en barre on garde
  -- la petite icône déjà en place. Jamais de remplacement de la fiole.
  local frac = bar and 0.55 or (1 / 3)
  local lo = bar and 5 or 8
  local hi = bar and 8 or 14
  local side = math.max(lo, math.min(hi, math.floor(math.min(w, H) * frac + 0.5)))
  if side > w then side = w end
  if side > H then side = H end
  if kind == "drink" then
    PlaceGameIcon(e.drink, drinkPath, parent, side, w - side, H - side)
    if e.food then HideTex(e.food) end
  elseif kind == "both" then
    if side * 2 + 1 > w then side = math.max(bar and 4 or 6, math.floor((w - 1) / 2)) end
    PlaceGameIcon(e.food, foodPath, parent, side, w - side, H - side)
    PlaceGameIcon(e.drink, drinkPath, parent, side, 0, H - side)
  else
    PlaceGameIcon(e.food, foodPath, parent, side, w - side, H - side)
    if e.drink then HideTex(e.drink) end
  end
end

S.EAT_WAVE = {
  food  = { 0.98, 0.62, 0.16, 1.00 },
  drink = { 0.32, 0.62, 1.00, 1.00 },
}

function S.FillSurfaceY(t, h)
  -- Hauteur de la surface du vrai remplissage, dans le puits (px depuis le bas).
  h = h or 16
  local baseY = math.max(0, h * 0.10)
  local bodyH = h * 0.72
  local out, p, grey, drain = S.FillRatios and S.FillRatios(t)
  if not out then return baseY + bodyH * 0.55 end
  local last = ns.Wide and ns.Wide.last
  local denom = (last and last.track and last.track > 0 and last.track) or 100
  local track = 0
  for i = 1, 3 do track = track + (out[i] or 0) end
  local frac = math.max(0.08, math.min(1, (track / denom) * (N(drain) or 1)))
  return math.min(h * 0.82, baseY + bodyH * frac)
end

function S.ApplyRegenWave(dt)
  -- 3.6.3 : l'état repas/boisson est retiré. On range d'éventuels reliquats.
  local t = S.FlaskTile and S.FlaskTile() or (ns.Wide and ns.Wide.TotalTile and ns.Wide.TotalTile())
  if S.HideRegenWave then S.HideRegenWave(t) end
  S._eatOn = false
  do return end
  dt = N(dt) or 0
  if not t then return end
  local inCombatFill = S.CombatLiquidOn() and ((S.fill and S.fill.p) or 0) > 0.05
  local show = S.Want("eating") and not inCombatFill and not (S.Opt("slotDeath") and S.LiveDeath())
  -- Pas par-dessus un état qui remplace déjà la fiole (sac de couchage, feuilles).
  local act = S.Active and S.Active()
  if show and act == "sleepingbag" then show = false end
  if show and act and act ~= "drop" and S.SHEETS and S.SHEETS[act] then show = false end
  if not show then
    S.HideRegenWave(t)
    return
  end
  local e = S.EnsureRegenWave(t)
  if not e then return end
  if e.body then HideTex(e.body) end
  local clip, content, w, H = S.PlaceIconClip(t)
  w, H = w or 16, H or 16
  -- Jamais sur la case entière (ça passerait devant « 85/2460 »).
  local a = content or clip
  if not a then return end
  local kind = S.EatKind and S.EatKind() or "food"
  local bar = t._wideOn and true or false
  S.EnsureEatIcons(e, a, w, H)
  S.PlaceEatIcons(t, e, kind, a, w, H, bar)
  -- La fiole officielle n'est jamais remplacée (badge en coin seulement).
  if t.icon and t.icon.Show then t.icon:Show() end
  if not bar then
    if e.wave then HideTex(e.wave) end
    if e.wave2 then HideTex(e.wave2) end
    S._eatOn = true
    return
  end
  local R = ns.Rested
  e.u = (e.u or 0) + dt / ((R and R.LIQ and R.LIQ.charge and R.LIQ.charge.period) or 2.4)
  if e.u > 1 then e.u = e.u - math.floor(e.u) end
  local surf = S.FillSurfaceY(t, H)
  -- Vague bien visible dans le corps de la fiole, pas un filet coincé au fond.
  if surf < H * 0.40 then surf = H * 0.40 end
  local wh = math.max(3, math.min(8, math.max(H * 0.28, 3)))
  local wy = math.max(0, surf - wh * 0.65)
  if wy + wh > H then wy = math.max(0, H - wh) end
  local foodCol, drinkCol = S.EAT_WAVE.food, S.EAT_WAVE.drink
  local function paint(tex, col, phase, yoff)
    if not tex or not col then
      if tex and tex.Hide then tex:Hide() end
      return
    end
    S.PlaceClippedTex(tex, a, w, wh, 0, math.max(0, wy + (yoff or 0)))
    if tex.SetAlpha then pcall(tex.SetAlpha, tex, 1) end
    if tex.SetVertexColor then pcall(tex.SetVertexColor, tex, col[1], col[2], col[3], col[4] or 0.9) end
    if tex.SetTexCoord then
      local span = (R and R.WAVE_U) or 0.5
      local u = ((e.u or 0) + (phase or 0))
      u = (u - math.floor(u)) * span
      pcall(tex.SetTexCoord, tex, u, 0, u + span, 1)
    end
    if tex.Show then tex:Show() end
  end
  if kind == "both" then
    paint(e.wave, foodCol, 0, 0)
    paint(e.wave2, drinkCol, 0.18, math.max(1, H * 0.04))
  elseif kind == "drink" then
    paint(e.wave, drinkCol, 0, 0)
    if e.wave2 then HideTex(e.wave2) end
  else
    paint(e.wave, foodCol, 0, 0)
    if e.wave2 then HideTex(e.wave2) end
  end
  local mask = S.IconMaskFor(t)
  if mask then
    if e.wave and e.wave.AddMaskTexture then pcall(e.wave.AddMaskTexture, e.wave, mask) end
    if e.wave2 and e.wave2.AddMaskTexture then pcall(e.wave2.AddMaskTexture, e.wave2, mask) end
  end
  S._eatOn = true
end

-- Palette unique (voile de case, « +1 », étincelle, teinte de toast).
-- Jamais nil ni noir : tout le monde lit cette table.
S.ADD_COLORS = {
  red   = { 0.616, 0.278, 0.227 },
  blue  = { 0.329, 0.408, 0.604 },
  green = { 0.310, 0.498, 0.243 },
}
ns.GAIN_COLORS = S.ADD_COLORS
-- Rejette un RVB quasi noir (teinte de fond de toast ~0,07) : ça se voyait
-- comme une étincelle ou un +1 noirs si on passait TOAST_TINT au lieu d'ADD_COLORS.
function S.UsableColor(c)
  if type(c) ~= "table" then return nil end
  local r = N(c[1]) or N(c.r)
  local g = N(c[2]) or N(c.g)
  local b = N(c[3]) or N(c.b)
  if not (r and g and b) then return nil end
  if (r + g + b) < 0.35 then return nil end
  return { r, g, b, N(c[4]) or N(c.a) or 1 }
end
local function FoldGain(s)
  if type(s) ~= "string" or s == "" then return "" end
  local ok, f = pcall(function()
    return (ns.Fold and ns.Fold(s)) or s:lower()
  end)
  if not (ok and type(f) == "string") then f = s:lower() end
  f = f:gsub("é", "e"):gsub("è", "e"):gsub("ê", "e"):gsub("à", "a"):gsub("â", "a")
  f = f:gsub("î", "i"):gsub("ô", "o"):gsub("ù", "u"):gsub("û", "u"):gsub("ç", "c")
  return f
end
-- Armes (mêlée + distance) + Défense → bleu ; métiers → vert ; XP → rouge.
-- Jamais nil ni noir : on résout par kind / id / nom / en-tête / catalogue.
S.WEAPON_GAIN_TOKENS = {
  melee = true, ranged = true, defense = true, defence = true, feral = true,
  weapon = true, weapons = true, arme = true, armes = true, combat = true,
  daggers = true, dague = true, dagues = true, dagger = true,
  bows = true, bow = true, arc = true, arcs = true,
  guns = true, gun = true, ["armes a feu"] = true, fusil = true, fusils = true,
  crossbows = true, crossbow = true, arbalete = true, arbaletes = true,
  thrown = true, ["armes de jet"] = true, jet = true,
  wands = true, wand = true, baguette = true, baguettes = true,
  staves = true, staff = true, baton = true, batons = true,
  fist = true, ["fist weapons"] = true, pugilat = true, ["armes de pugilat"] = true,
  polearms = true, polearm = true, hast = true, ["armes d hast"] = true, ["armes d'hast"] = true,
  unarmed = true, ["mains nues"] = true, ["combat a mains nues"] = true,
  swords = true, sword = true, epee = true, epees = true, ["epees a deux mains"] = true, swords2h = true,
  axes = true, axe = true, hache = true, haches = true, axes2h = true, ["haches a deux mains"] = true,
  maces = true, mace = true, masse = true, masses = true, maces2h = true, ["masses a deux mains"] = true,
  ["two handed axes"] = true, ["two-handed axes"] = true,
  ["two handed swords"] = true, ["two-handed swords"] = true,
  ["two handed maces"] = true, ["two-handed maces"] = true,
  ["combat farouche"] = true, ["feral combat"] = true,
}
function S.ColorForGain(kind, id, name, header)
  local k, i, n, h = FoldGain(kind), FoldGain(id), FoldGain(name), FoldGain(header)
  if k == "xp" or k == "level" or k == "levelup" or k == "jalon" or k == "level-up"
    or i == "level" or k == "xp-milestone" then
    return S.ADD_COLORS.red, "red"
  end
  local e
  if id and ns.CatalogById then e = ns.CatalogById(id) end
  if not e and name and ns.LookupCatalog then e = ns.LookupCatalog(name) end
  if e then
    if e.kind == "level" then return S.ADD_COLORS.red, "red" end
    if e.capKind == "weapon" or e.kind == "melee" or e.kind == "ranged"
      or e.kind == "defense" or e.kind == "feral" then
      return S.ADD_COLORS.blue, "blue"
    end
    if e.kind == "profession" or e.kind == "secondary" or e.kind == "class" then
      return S.ADD_COLORS.green, "green"
    end
  end
  if ns.IsWeaponSkill and ns.IsWeaponSkill(id, kind, name) then
    return S.ADD_COLORS.blue, "blue"
  end
  if k == "melee" or k == "ranged" or k == "defense" or k == "defence" or k == "feral" then
    return S.ADD_COLORS.blue, "blue"
  end
  if S.WEAPON_GAIN_TOKENS[k] or S.WEAPON_GAIN_TOKENS[i] or S.WEAPON_GAIN_TOKENS[n] then
    return S.ADD_COLORS.blue, "blue"
  end
  if h:find("arme", 1, true) or h:find("weapon", 1, true) or h == "defense" or h == "defence" then
    return S.ADD_COLORS.blue, "blue"
  end
  if n:find("defense", 1, true) or n:find("defence", 1, true) or i == "defense" then
    return S.ADD_COLORS.blue, "blue"
  end
  if k == "profession" or k == "secondary" or k == "class" or k == "craft" or k == "skill"
    or k == "metier" or k == "metiers" then
    return S.ADD_COLORS.green, "green"
  end
  return S.ADD_COLORS.green, "green"
end
function S.AddColor(key)
  local usable = S.UsableColor(key)
  if usable then return usable end
  if type(key) == "table" then
    -- Table trop sombre ou mal formée : ne jamais peindre en noir.
    return S.ADD_COLORS.red
  end
  key = tostring(key or "red"):lower()
  if key == "red" or key == "rouge" or key == "xp" or key == "level" then return S.ADD_COLORS.red end
  if key == "blue" or key == "bleu" or key == "combat" or key == "armes" or key == "weapon"
    or key == "defense" or key == "defence" or key == "melee" or key == "ranged" then
    return S.ADD_COLORS.blue
  end
  if key == "green" or key == "vert" or key == "skill" or key == "metier" or key == "métier" then
    return S.ADD_COLORS.green
  end
  local col = S.ColorForGain(key, key, key)
  return col or S.ADD_COLORS.red
end
function S.EnsureBarSpark(t)
  if not t then return nil end
  if t._barSpark and t._barFlash then return t._barSpark, t._barFlash end
  if type(t.CreateTexture) ~= "function" then return t._barSpark, t._barFlash end
  if not t._barSpark then
    local spark = t:CreateTexture(nil, "OVERLAY", nil, 7)
    if spark and spark.SetTexture then pcall(spark.SetTexture, spark, "Interface\\Buttons\\WHITE8X8") end
    if spark and spark.SetBlendMode then pcall(spark.SetBlendMode, spark, "ADD") end
    if spark and spark.Hide then spark:Hide() end
    t._barSpark = spark
  end
  if not t._barFlash then
    local flash = t:CreateTexture(nil, "OVERLAY", nil, 8)
    if flash and flash.SetTexture then pcall(flash.SetTexture, flash, "Interface\\Buttons\\WHITE8X8") end
    if flash and flash.SetBlendMode then pcall(flash.SetBlendMode, flash, "ADD") end
    if flash and flash.Hide then flash:Hide() end
    t._barFlash = flash
  end
  return t._barSpark, t._barFlash
end
-- Parcours d'une étincelle : case (+1) → arc jusqu'à la barre → course jusqu'au
-- bout rempli → flash. ~0,7–0,85 s, un seul cadre poolé, file si rafale.
S.SPARK_FLY = 0.28
S.SPARK_RUN = 0.40
S.SPARK_FLASH = 0.15
S.SPARK_QMAX = 4

function S.TileIsSparkable(t)
  if not t then return false end
  if t.IsShown and not t:IsShown() then return false end
  local w = (t.GetWidth and N(t:GetWidth())) or 0
  local h = (t.GetHeight and N(t:GetHeight())) or 0
  if w < 4 or h < 4 then return false end
  return true
end

function S.AbsCenter(o)
  if not o then return nil end
  local ui = ns.UI
  local RectOf = ui and (ui.RectOf or (ui._H and ui._H.RectOf))
  if type(RectOf) == "function" then
    local l, r, top, bot = RectOf(o)
    if l and r and top and bot then return (l + r) * 0.5, (top + bot) * 0.5 end
  end
  local l = o.GetLeft and N(o:GetLeft())
  local b = o.GetBottom and N(o:GetBottom())
  local w = (o.GetWidth and N(o:GetWidth())) or 0
  local h = (o.GetHeight and N(o:GetHeight())) or 0
  if l and b then return l + w * 0.5, b + h * 0.5 end
  return nil
end

function S.BarSparkEnds(t)
  t = t or (S.FlaskTile and S.FlaskTile())
  if not t then return nil end
  local Wd = ns.Wide
  local last = Wd and Wd.last
  local left = (last and last.left) or 0
  local inner = (last and last.inner) or 10
  local by = (last and last.by) or 0
  local bh = (last and last.bh) or (Wd and Wd.BAR_H) or 4
  local pct = (last and last.pct) or 1
  if pct < 0 then pct = 0 elseif pct > 1 then pct = 1 end
  local bl, bb
  local cx, cy = S.AbsCenter(t)
  local w = (t.GetWidth and N(t:GetWidth())) or (t._wideW) or 0
  local h = (t.GetHeight and N(t:GetHeight())) or (t._wideH) or 0
  if cx and cy then
    bl, bb = cx - w * 0.5, cy - h * 0.5
  else
    bl = (t.GetLeft and N(t:GetLeft())) or 0
    bb = (t.GetBottom and N(t:GetBottom())) or 0
  end
  local landX = bl + left
  local landY = bb + by + bh * 0.5
  local tipX = bl + left + inner * pct
  return landX, landY, tipX, landY, bh, left, inner, by, pct
end

function S.EnsureFlySpark()
  if S._flySpark then return S._flySpark end
  local parent = _G.UIParent
  if type(_G.CreateFrame) ~= "function" or not parent then return nil end
  local ok, f = pcall(_G.CreateFrame, "Frame", nil, parent)
  if not (ok and f) then return nil end
  f._osrsOwn = true
  if f.EnableMouse then pcall(f.EnableMouse, f, false) end
  if f.SetFrameStrata then pcall(f.SetFrameStrata, f, "HIGH") end
  if f.SetSize then pcall(f.SetSize, f, 8, 8) end
  if f.CreateTexture then
    local tex = f:CreateTexture(nil, "OVERLAY")
    if tex then
      if tex.SetAllPoints then tex:SetAllPoints(f) end
      if tex.SetTexture then pcall(tex.SetTexture, tex, "Interface\\Buttons\\WHITE8X8") end
      if tex.SetBlendMode then pcall(tex.SetBlendMode, tex, "ADD") end
      f.tex = tex
    end
  end
  if f.Hide then f:Hide() end
  S._flySpark = f
  return f
end

function S.PlaceFlySpark(x, y, col, size, alpha)
  local f = S.EnsureFlySpark()
  if not f then return nil end
  size = size or 8
  if f.SetSize then pcall(f.SetSize, f, size, size) end
  if f.ClearAllPoints then pcall(f.ClearAllPoints, f) end
  local parent = _G.UIParent or f
  if f.SetPoint then pcall(f.SetPoint, f, "CENTER", parent, "BOTTOMLEFT", x, y) end
  if f.tex and f.tex.SetVertexColor and col then
    pcall(f.tex.SetVertexColor, f.tex, col[1], col[2], col[3], 1)
  end
  if f.SetAlpha then pcall(f.SetAlpha, f, alpha or 1) end
  if f.Show then f:Show() end
  return f
end

function S.HideFlySpark()
  local f = S._flySpark
  if not f then return end
  if f.SetAlpha then pcall(f.SetAlpha, f, 0) end
  if f.Hide then f:Hide() end
end

function S.QueueSpark(col, from)
  S._sparkQ = S._sparkQ or {}
  local function same(c)
    return c and col and math.abs((c[1] or 0) - (col[1] or 0)) < 0.02
      and math.abs((c[2] or 0) - (col[2] or 0)) < 0.02
      and math.abs((c[3] or 0) - (col[3] or 0)) < 0.02
  end
  local last = S._sparkQ[#S._sparkQ]
  if last and same(last.color) then
    last.from = from or last.from
    last.n = (last.n or 1) + 1
    return
  end
  if not last and S._sparkT ~= nil and same(S._sparkPlayColor) then
    -- même couleur déjà en cours : on fusionne (pas de 2e trajet)
    return
  end
  if #S._sparkQ >= (S.SPARK_QMAX or 4) then return end
  S._sparkQ[#S._sparkQ + 1] = { color = col, from = from, n = 1 }
end

function S.FlushSparkQueue()
  if S._sparkT ~= nil then return end
  local q = S._sparkQ
  if not (q and q[1]) then return end
  local e = table.remove(q, 1)
  if e then S._PlayBarSparkNow(e.color, e.from) end
end

function S.HideBarSpark(t)
  t = t or (S.FlaskTile and S.FlaskTile())
  local function wipe(tex)
    if not tex then return end
    if tex.SetAlpha then pcall(tex.SetAlpha, tex, 0) end
    if tex.SetVertexColor then pcall(tex.SetVertexColor, tex, 1, 1, 1, 0) end
    if tex.SetSize then pcall(tex.SetSize, tex, 1, 1) end
    if tex.Hide then tex:Hide() end
  end
  if t then
    wipe(t._barSpark)
    wipe(t._barFlash)
  end
  if S.HideFlySpark then S.HideFlySpark() end
  S._sparkT = nil
  S._sparkPhase = nil
  S._sparkFrom = nil
  if not S._sparkFlushing and S.FlushSparkQueue then
    S._sparkFlushing = true
    S.FlushSparkQueue()
    S._sparkFlushing = nil
  end
end

function S._PlayBarSparkNow(color, from)
  local col = S.AddColor(color)
  S._sparkColor, S._sparkPlayColor = col, col
  local t = S.FlaskTile and S.FlaskTile()
  if not t then return end
  S.EnsureBarSpark(t)
  local useFly = from and S.TileIsSparkable(from) and S.AbsCenter(from) and true or false
  if useFly then
    S._sparkFrom = from
    S._sparkPhase = "fly"
    local sx, sy = S.AbsCenter(from)
    S._sparkSX, S._sparkSY = sx, sy
  else
    S._sparkFrom = nil
    S._sparkPhase = "run"
    S._sparkSX, S._sparkSY = nil, nil
    if S.HideFlySpark then S.HideFlySpark() end
  end
  S._sparkT = 0
  if S.StartDriver then S.StartDriver() end
end

function S.PlayBarSpark(color, from)
  local col = S.AddColor(color)
  S._sparkColor = col
  if S._sparkT ~= nil then
    S.QueueSpark(col, from)
    return
  end
  S._PlayBarSparkNow(col, from)
end

function S.TickBarSpark(dt)
  local t = S.FlaskTile and S.FlaskTile()
  if not t or S._sparkT == nil then
    if t and S.HideBarSpark then S.HideBarSpark(t) else S._sparkT = nil end
    return
  end
  if not t._wideOn then
    -- barre masquée / en case : on simplifie, pas de course
    S.HideBarSpark(t)
    return
  end
  local spark, flash = S.EnsureBarSpark(t)
  local col = S._sparkPlayColor or S._sparkColor or S.ADD_COLORS.red
  local flyD, runD, flD = S.SPARK_FLY or 0.28, S.SPARK_RUN or 0.40, S.SPARK_FLASH or 0.15
  S._sparkT = (S._sparkT or 0) + (N(dt) or 0)
  local u = S._sparkT
  local landX, landY, tipX, tipY, bh, left, inner, by, pct = S.BarSparkEnds(t)
  bh = bh or 4
  local phase = S._sparkPhase or "run"

  if phase == "fly" then
    if u >= flyD then
      S.HideFlySpark()
      S._sparkPhase = "run"
      S._sparkT = u - flyD
      u = S._sparkT
      phase = "run"
    else
      local k = u / flyD
      if k < 0 then k = 0 elseif k > 1 then k = 1 end
      -- lissage (smoothstep)
      local s = k * k * (3 - 2 * k)
      local sx, sy = S._sparkSX, S._sparkSY
      if not (sx and sy and landX and landY) then
        S._sparkPhase = "run"
        S._sparkT = 0
        S.HideFlySpark()
      else
        local x = sx + (landX - sx) * s
        local y = sy + (landY - sy) * s
        local hop = math.sin(k * math.pi) * math.min(22, math.abs(sy - landY) * 0.28 + 8)
        y = y + hop
        local sz = 6 + 2 * math.sin(k * math.pi)
        S.PlaceFlySpark(x, y, col, sz, 0.45 + 0.50 * math.sin(k * math.pi))
        if spark and spark.Hide then spark:Hide() end
        if flash and flash.Hide then flash:Hide() end
        return
      end
    end
  end

  if phase == "run" then
    if not spark then S._sparkT = nil return end
    if u >= runD then
      S._sparkPhase = "flash"
      S._sparkT = u - runD
      u = S._sparkT
      phase = "flash"
    else
      local k = (runD > 0) and (u / runD) or 1
      if k < 0 then k = 0 elseif k > 1 then k = 1 end
      local sw = math.max(4, bh * 0.85)
      local tip = (left or 0) + (inner or 10) * (pct or 1)
      local span = math.max(0, tip - (left or 0) - sw)
      local x = (left or 0) + k * span
      if spark.ClearAllPoints then pcall(spark.ClearAllPoints, spark) end
      if spark.SetPoint then pcall(spark.SetPoint, spark, "BOTTOMLEFT", t, "BOTTOMLEFT", x, by or 0) end
      if spark.SetSize then pcall(spark.SetSize, spark, sw, math.max(1, bh)) end
      local a = 0.35 + 0.55 * math.sin(k * math.pi)
      if spark.SetVertexColor then pcall(spark.SetVertexColor, spark, col[1], col[2], col[3], 1) end
      if spark.SetAlpha then pcall(spark.SetAlpha, spark, a) end
      if spark.Show then spark:Show() end
      if flash and flash.Hide then flash:Hide() end
      S.HideFlySpark()
      return
    end
  end

  if phase == "flash" then
    if u >= flD then
      -- fin : HideBarSpark déclenche la file
      local q = S._sparkQ
      S._sparkT, S._sparkPhase = nil, nil
      if t then
        if spark and spark.SetAlpha then pcall(spark.SetAlpha, spark, 0) end
        if spark and spark.Hide then spark:Hide() end
        if flash and flash.SetAlpha then pcall(flash.SetAlpha, flash, 0) end
        if flash and flash.Hide then flash:Hide() end
      end
      S.HideFlySpark()
      if q and q[1] then S.FlushSparkQueue() end
      return
    end
    local k = (flD > 0) and (u / flD) or 1
    if spark and spark.SetAlpha then pcall(spark.SetAlpha, spark, 0) end
    if spark and spark.Hide then spark:Hide() end
    if flash then
      local tip = (left or 0) + (inner or 10) * (pct or 1)
      local fw = math.max(6, bh * (1.15 + 0.7 * (1 - k)))
      local fh = math.max(bh, bh * (1.05 + 0.45 * (1 - k)))
      local fx, fy = tip - fw * 0.5, (by or 0) + (bh - fh) * 0.5
      if flash.ClearAllPoints then pcall(flash.ClearAllPoints, flash) end
      if flash.SetPoint then pcall(flash.SetPoint, flash, "BOTTOMLEFT", t, "BOTTOMLEFT", fx, fy) end
      if flash.SetSize then pcall(flash.SetSize, flash, fw, fh) end
      local r = col[1] + (1 - col[1]) * 0.35
      local g = col[2] + (1 - col[2]) * 0.35
      local b = col[3] + (1 - col[3]) * 0.35
      if flash.SetVertexColor then pcall(flash.SetVertexColor, flash, r, g, b, 1) end
      if flash.SetAlpha then pcall(flash.SetAlpha, flash, 0.85 * (1 - k)) end
      if flash.Show then flash:Show() end
    end
    S.HideFlySpark()
    return
  end
end

-- Débordement de niveau : le liquide dépasse, anneau bronze pulse, vague de reset.
function S.EnsureLevelUp(t)
  if not t then return nil end
  local _, content = S.PlaceIconClip(t)
  local parent = content or t
  if t._lvl then
    if t._lvl.SetParent and parent then pcall(t._lvl.SetParent, t._lvl, parent) end
    return t._lvl
  end
  local ok, f = pcall(CreateFrame, "Frame", nil, parent)
  if not (ok and f) then return nil end
  S.SetSizeIf(f, 1, 1)
  if f.EnableMouse then pcall(f.EnableMouse, f, false) end
  local function tex(layer)
    if type(f.CreateTexture) ~= "function" then return nil end
    return f:CreateTexture(nil, layer or "OVERLAY")
  end
  f.spill = tex("ARTWORK")
  f.ring = tex("OVERLAY")
  f.wave = tex("ARTWORK")
  if f.wave and f.wave.SetTexture then
    pcall(f.wave.SetTexture, f.wave, (ns.Rested and ns.Rested.WAVE_TEX) or (MEDIA .. "Dropamine-Wave"))
  end
  if f.spill and f.spill.SetTexture then pcall(f.spill.SetTexture, f.spill, "Interface\\Buttons\\WHITE8X8") end
  if f.ring and f.ring.SetTexture then
    -- Anneau : filet bronze, ou disque teinté si pas de texture dédiée.
    pcall(f.ring.SetTexture, f.ring, "Interface\\Minimap\\MiniMap-TrackingBorder")
  end
  t._lvl = f
  return f
end

function S.PlayLevelUp()
  local t = S.FlaskTile and S.FlaskTile()
  if not t then return end
  S._lvlT = 0
  S.StartDriver()
  S.EnsureLevelUp(t)
end

function S.TickLevelUp(dt)
  local t = S.FlaskTile and S.FlaskTile()
  if not t then S._lvlT = nil return end
  if S._lvlT == nil then
    if t._lvl and t._lvl.Hide then t._lvl:Hide() end
    return
  end
  S._lvlT = (S._lvlT or 0) + (N(dt) or 0)
  local u = S._lvlT
  local f = S.EnsureLevelUp(t)
  if not f then S._lvlT = nil return end
  local clip, content, w, h = S.PlaceIconClip(t)
  w, h = w or 16, h or 16
  if f.SetParent and content then pcall(f.SetParent, f, content) end
  if S.SetSizeIf(f, w, h) or f._clipParent ~= (content or clip) then
    if f.ClearAllPoints then pcall(f.ClearAllPoints, f) end
    if f.SetPoint then pcall(f.SetPoint, f, "BOTTOMLEFT", content or clip, "BOTTOMLEFT", 0, 0) end
    f._clipParent = content or clip
  end
  if f.Show then f:Show() end
  -- 0–0.35 débordement, 0.35–0.75 pulse de l'anneau, 0.75–1.25 vague de reset.
  if u < 0.35 then
    local k = u / 0.35
    if f.spill then
      local sh = h * (0.72 + 0.28 * k)
      S.PlaceClippedTex(f.spill, f, math.max(1, w * 0.62), sh, w * 0.19, 0)
      if f.spill.SetVertexColor then pcall(f.spill.SetVertexColor, f.spill, 0.72, 0.32, 0.24, 0.55 * k) end
      if f.spill.Show then f.spill:Show() end
    end
    if f.ring and f.ring.Hide then f.ring:Hide() end
    if f.wave and f.wave.Hide then f.wave:Hide() end
  elseif u < 0.75 then
    local k = (u - 0.35) / 0.40
    if f.spill and f.spill.SetAlpha then pcall(f.spill.SetAlpha, f.spill, 0.45 * (1 - k)) end
    if f.ring then
      local rw = w * (1.05 + 0.18 * math.sin(k * 3.14))
      local rh = h * (1.05 + 0.18 * math.sin(k * 3.14))
      S.PlaceClippedTex(f.ring, f, rw, rh, (w - rw) / 2, (h - rh) / 2)
      if f.ring.SetVertexColor then pcall(f.ring.SetVertexColor, f.ring, 0.65, 0.49, 0.27, 0.9 * (1 - math.abs(2 * k - 1))) end
      if f.ring.Show then f.ring:Show() end
    end
    if f.wave and f.wave.Hide then f.wave:Hide() end
  elseif u < 1.25 then
    local k = (u - 0.75) / 0.50
    if f.spill and f.spill.Hide then f.spill:Hide() end
    if f.ring and f.ring.Hide then f.ring:Hide() end
    if f.wave then
      local surf = S.FillSurfaceY and S.FillSurfaceY(t, h) or (h * 0.5)
      local wh = math.max(2, h * 0.14)
      S.PlaceClippedTex(f.wave, f, w, wh, 0, math.max(0, surf - wh * 0.4))
      if f.wave.SetVertexColor then pcall(f.wave.SetVertexColor, f.wave, 0.80, 0.42, 0.32, 0.85 * (1 - k)) end
      if f.wave.SetTexCoord then
        local span, uu = 0.5, k * 0.5
        pcall(f.wave.SetTexCoord, f.wave, uu, 0, uu + span, 1)
      end
      if f.wave.Show then f.wave:Show() end
    end
  else
    if f.Hide then f:Hide() end
    S._lvlT = nil
  end
end

S.OPTIONS = {
  { type = "check", key = "slotDeath", label = "Crâne à la mort", default = true,
    help = "Dans le puits de la fiole : un crâne, fiole vidée et grisée, suivi en pause jusqu'à la résurrection." },
  { type = "check", key = "slotFlight", label = "Sablier pendant le vol", default = true,
    help = "Remplace la goutte par le sablier pendant un trajet aérien. La pause du suivi reste réglée à part." },
  { type = "check", key = "slotAfk", label = "Horloge AFK", default = true,
    help = "Une horloge de bronze à aiguille tournante quand tu es absent." },
  { type = "check", key = "slotBags", label = "Sacs pleins", default = true,
    help = "Un sac dans le puits et un toast quand il n'y a plus de place : le butin sera perdu." },
  { type = "check", key = "slotFishing", label = "Hameçon à la pêche", default = true,
    help = "Un hameçon qui tangue tant que la ligne est lancée, et un petit sursaut quand la prise arrive dans les sacs." },
  { type = "check", key = "slotSwimming", label = "Bulles à la nage", default = true,
    help = "Des bulles montent dans le puits tant que tu nages." },
  { type = "check", key = "slotDurability", label = "Équipement usé", default = false,
    help = "Un bouclier fendu dans le puits et un toast quand une pièce équipée passe sous 20 % de durabilité. Coupé par défaut." },
  { type = "check", key = "slotSleepingBag", label = "Sac de couchage", default = true,
    help = "Dans le puits de la fiole, le sac de couchage (style A) à 1, 2 ou 3 bandes uniquement pendant la charge (sort Unroll Bag 429961 / canal). Le buff Bien reposé (429959) et les buffs résultants n'entretiennent pas l'icône. Si tu pars avant 3 charges, un toast XP indique le palier manqué." },
  { type = "check", key = "slotTrainer", label = "Éclat maître à proximité", default = true,
    help = "Un petit éclat sur la case du métier quand un maître est à proximité (pas dans la fiole)." },
}

------------------------------------------------------------------------------
-- Branchements
------------------------------------------------------------------------------
local function Hook(obj, name, wrap)
  if not (obj and obj[name]) then return end
  local base = obj[name]
  obj[name] = function(...)
    return wrap(base, ...)
  end
end

-- Pause du suivi pendant la mort (même porte que le vol).
do
  local prev = ns.PausedForFlight
  function ns.PausedForFlight()
    if S.DeathPause and S.DeathPause() then return true end
    if prev then return prev() end
    return false
  end
end

if ns.Wide and ns.Wide.LayoutSegments then
  local base = ns.Wide.LayoutSegments
  function ns.Wide.LayoutSegments(...)
    local a, b = base(...)
    pcall(S.ApplyFlaskFill)
    return a, b
  end
end

if ns.OnOptionChanged then
  -- déjà une fonction ; on s'y greffe plus bas si besoin
end
local prevOpt = ns.OnOptionChanged
function ns.OnOptionChanged(key, value)
  if prevOpt then pcall(prevOpt, key, value) end
  if type(key) == "string" and (key:find("^slot", 1) or key == "trainerRankToast" or key == "quietAuto") then
    pcall(S.Refresh, "option")
  end
  -- slotFlight off : cacher le sablier même en vol
  if key == "slotFlight" and value == false then
    local F = ns.Flight
    if F and not F.Paused() then return end
    pcall(S.Refresh, "option")
  end
end

if ns.On then
  local evs = {
    "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST", "PLAYER_FLAGS_CHANGED",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP",
    "UNIT_SPELLCAST_CHANNEL_UPDATE",
    "BAG_UPDATE", "BAG_UPDATE_DELAYED", "CHAT_MSG_LOOT", "LOOT_CLOSED",
    "UPDATE_INVENTORY_DURABILITY", "PLAYER_EQUIPMENT_CHANGED",
    "UNIT_AURA", "UI_ERROR_MESSAGE",
    "PLAYER_ENTERING_WORLD", "PLAYER_UPDATE_RESTING", "PLAYER_STARTED_MOVING", "PLAYER_STOPPED_MOVING",
    "UNIT_SPELLCAST_SUCCEEDED",
    "TRAINER_SHOW", "TRAINER_CLOSED", "GOSSIP_SHOW", "GOSSIP_CLOSED",
    "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT",
    "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA",
    "SKILL_LINES_CHANGED", "CHAT_MSG_SKILL",
  }
  for i = 1, #evs do
    local ev = evs[i]
    ns.On(ev, function(...)
      -- BAG_UPDATE est trop bavard (souvent un événement par case) : on attend DELAYED.
      if ev == "BAG_UPDATE" then
        return
      end
      if ev == "BAG_UPDATE_DELAYED" or ev == "LOOT_CLOSED" then
        pcall(S.OnCatch)
        pcall(S.CheckBags)
        pcall(S.Refresh, ev)
        return
      end
      if ev == "CHAT_MSG_LOOT" then
        pcall(S.OnCatch)
        pcall(S.Refresh, ev)
        return
      end
      if ev == "UNIT_AURA" or ev == "UNIT_SPELLCAST_CHANNEL_START"
        or ev == "UNIT_SPELLCAST_CHANNEL_STOP" or ev == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
        local unit = select(2, ...)
        if type(unit) ~= "string" then unit = select(1, ...) end
        if type(unit) == "string" and unit ~= "player" then return end
        pcall(S.OnPlayerAura, ev)
        return
      end
      if ev == "UPDATE_INVENTORY_DURABILITY" or ev == "PLAYER_EQUIPMENT_CHANGED" then
        pcall(S.CheckDurability)
      end
      if ev == "UI_ERROR_MESSAGE" then
        pcall(S.OnInvFullError, ...)
      end
      if ev == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit = select(2, ...)
        if type(unit) ~= "string" then unit = select(1, ...) end
        if unit and unit ~= "player" then return end
      end
      if ev == "PLAYER_UPDATE_RESTING" or ev == "ZONE_CHANGED"
        or ev == "ZONE_CHANGED_INDOORS" or ev == "ZONE_CHANGED_NEW_AREA" then
        pcall(S.OnRestOrZone, ev)
        return
      end
      pcall(S.Refresh, ev)
    end)
  end
end

-- Dernier mot après Polish/ClassicTheme : un état ne remplace que l'icône.
do
  local Wd = ns.Wide
  if Wd and Wd.Paint then
    local basePaint = Wd.Paint
    function Wd.Paint(t, ...)
      local r = { basePaint(t, ...) }
      if t and S.ReplacesFlaskIcon and S.ReplacesFlaskIcon(t) then
        if t.icon and t.icon.Hide then t.icon:Hide() end
        if S.Active and S.Active() == "rested" and S.ApplyRestIcon then
          S.ApplyRestIcon(t)
        end
      end
      return unpack(r)
    end
  end
end

if ns.Options then
  ns.Options.EXTRA = ns.Options.EXTRA or {}
  ns.Options.EXTRA_HOME = ns.Options.EXTRA_HOME or {}
  local order = ns.Options.ITEM_ORDER and ns.Options.ITEM_ORDER.display
  local at = order and (#order + 1) or 1
  if order then
    for i, k in ipairs(order) do
      if k == "pauseFlying" or k == "restedAnim" then at = i + 1 end
    end
  end
  for _, it in ipairs(S.OPTIONS) do
    ns.Options.EXTRA[#ns.Options.EXTRA + 1] = it
    ns.Options.EXTRA_HOME[it.key] = "display"
    if order then
      table.insert(order, at, it.key)
      at = at + 1
    end
  end
  if ns.Options.All then ns.Options.ITEMS = ns.Options.All() end
end

