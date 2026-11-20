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

S.ORDER_SWORD   = { "death", "flight", "combat", "afk", "bags", "fishing", "swimming", "durability", "rested" }
S.ORDER_DEFAULT = { "death", "flight", "afk", "bags", "fishing", "swimming", "durability", "rested" }

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
S.OPT_KEYS = {
  death = "slotDeath", flight = "slotFlight",
  afk = "slotAfk", bags = "slotBags", fishing = "slotFishing", swimming = "slotSwimming",
  durability = "slotDurability",
  rested = "slotRested", trainer = "slotTrainer", eating = "slotEating",
}

function S.CombatStyle()
  local ui = ns.db and ns.db.ui
  local v = ui and ui.combatStyle
  if type(v) == "string" then
    v = v:lower()
    if v == "sword" or v == "epee" or v == "épée" or v == "c" then return "sword" end
    if v == "off" or v == "none" or v == "desactive" or v == "désactivé" then return "off" end
    if v == "bubbles" or v == "bulles" or v == "a" then return "bubbles" end
  end
  return "bubbles"
end

function S.SetCombatStyle(v)
  local n = S.CombatStyle()
  if type(v) == "string" then
    local k = v:lower()
    if k == "sword" or k == "epee" or k == "épée" or k == "c" then n = "sword"
    elseif k == "off" or k == "none" or k == "desactive" or k == "désactivé" then n = "off"
    elseif k == "bubbles" or k == "bulles" or k == "a" then n = "bubbles"
    end
  elseif v == false then
    n = "off"
  end
  if ns.SetOpt then ns.SetOpt("combatStyle", n) end
  return n
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
end

function S.ClearSim()
  S._sim = {}
  S._jolt = 0
  S._fishUntil = 0
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

function S.LiveFishing()
  if S._sim.fishing then return true end
  if type(UnitChannelInfo) == "function" then
    local name, rank, display, icon = Call(UnitChannelInfo, "player")
    if LooksLikeFishing(name, icon) or LooksLikeFishing(display, icon) then return true end
  end
  return false
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
  local resting = Call(IsResting) and true or false
  if not resting then return false end
  if ns.Rested and ns.Rested.State then
    local st = ns.Rested.State()
    if st and N(st.z) and st.z > 0 then return true end
    -- pas de « z » sans XP de repos
    return false
  end
  return resting
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
  local free = S.FreeBagSlots()
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

function S.LiveEating()
  if S._sim.eating or S._sim.eat or S._sim.repas then return true end
  local ok, found = pcall(S.FoodDrinkAura)
  return ok and found and true or false
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

function S.FlaskTile()
  local Wd = ns.Wide
  local t = Wd and Wd.TotalTile and Wd.TotalTile()
  if t and t.data and t.data.kind == "total" then return t end
  local ui = ns.UI
  local tiles = ui and ui.embed and ui.embed.tiles
  if tiles then
    for i = 1, #tiles do
      local tt = tiles[i]
      if tt and tt.data and tt.data.kind == "total" then return tt end
    end
  end
  return nil
end

function S.FlaskIsWide(t)
  t = t or S.FlaskTile()
  return t and t._wideOn and true or false
end

function S.TakesRestedZ()
  -- z dans la fiole (barre large OU case grille 1/2/3/5 col.) si c'est l'état actif
  if S.Active() ~= "rested" then return false end
  local t = S.FlaskTile()
  return t and t.data and t.data.kind == "total" and true or false
end

-- En barre large, les z quittent le portrait Niveau (règle historique).
-- En grille, ils s'ajoutent dans la case total sans retirer ceux du portrait
-- (les tests 3.6.2 et la vague de repos restent sur la case Niveau).
function S.StealsLevelZ()
  return S.TakesRestedZ() and S.FlaskIsWide()
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
  return { outR, outB, outG }, p, grey, drain
end

function S.ApplyFlaskFill(t)
  local Wd = ns.Wide
  if not (Wd and Wd.EnsureSegs) then return end
  t = t or S.FlaskTile() or (Wd.TotalTile and Wd.TotalTile())
  if not t then return end
  -- Hors barre large : pas de segments horizontaux (le liquide combat / la vague
  -- se peignent dans l'icône). On cache d'éventuels reliquats.
  if not t._wideOn then
    local pseg = t._pseg or (Wd.EnsureSegs and Wd.EnsureSegs(t))
    if pseg and pseg.segs then
      for i = 1, #pseg.segs do
        if pseg.segs[i] and pseg.segs[i].Hide then pseg.segs[i]:Hide() end
      end
    end
    return
  end
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

local function HideSymbol(t)
  if t and t._hg then
    if t._hg.ClearAllPoints and t.icon then pcall(t._hg.ClearAllPoints, t._hg) pcall(t._hg.SetAllPoints, t._hg, t.icon) end
    if t._hg.Hide then t._hg:Hide() end
  end
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
  if h.SetAllPoints and t.icon then pcall(h.SetAllPoints, h, t.icon) end
  if h.SetSize and t.icon and t.icon.GetWidth then
    local w = N(t.icon:GetWidth()) or 16
    local ht = N(t.icon:GetHeight()) or w
    pcall(h.SetSize, h, w, ht)
  end
  if id == "fishing" and (S._jolt or 0) > 0 and t.icon and h.ClearAllPoints and h.SetPoint then
    local j = S._jolt
    local ox = math.sin(j * 42) * 2.2 * j
    local oy = math.cos(j * 31) * 2.2 * j
    pcall(h.ClearAllPoints, h)
    pcall(h.SetPoint, h, "TOPLEFT", t.icon, "TOPLEFT", ox, oy)
    pcall(h.SetPoint, h, "BOTTOMRIGHT", t.icon, "BOTTOMRIGHT", ox, oy)
  end
  if h.SetAlpha then pcall(h.SetAlpha, h, 1) end
  if h.Show then h:Show() end
  if t.icon and t.icon.Hide then t.icon:Hide() end
  return h
end

-- Cadre de rognage (ScrollFrame) calé dans l'icône, en retrait du cadre bronze /
-- du fond de la case. SetClipsChildren est utilisé s'il existe, mais Forever
-- ne le garantit pas : le ScrollFrame est le clip fiable.
function S.IconAnchor(t)
  if not t then return nil end
  return t.icon or t.iconSlot or t.slotBorder or t
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
  if t._iconClip and t._iconClip._content then return t._iconClip, t._iconClip._content end
  local ok, clip = pcall(CreateFrame, "ScrollFrame", nil, t)
  if not (ok and clip) then
    ok, clip = pcall(CreateFrame, "Frame", nil, t)
    if not (ok and clip) then return nil end
  end
  if clip.EnableMouse then pcall(clip.EnableMouse, clip, false) end
  if clip.SetClipsChildren then pcall(clip.SetClipsChildren, clip, true) end
  local okC, content = pcall(CreateFrame, "Frame", nil, clip)
  if okC and content then
    if clip.SetScrollChild then pcall(clip.SetScrollChild, clip, content) end
    if content.EnableMouse then pcall(content.EnableMouse, content, false) end
    if content.SetClipsChildren then pcall(content.SetClipsChildren, content, true) end
    clip._content = content
  end
  t._iconClip = clip
  return clip, clip._content
end

function S.PlaceIconClip(t)
  if not t then return nil end
  local clip, content = S.EnsureIconClip(t)
  if not clip then return nil end
  local w, h, anchor, inset = S.IconInnerSize(t)
  if clip.ClearAllPoints then pcall(clip.ClearAllPoints, clip) end
  -- Taille posée explicitement : on ne laisse pas un défaut 100×50 recouvrir la fiole.
  if clip.SetSize then pcall(clip.SetSize, clip, w, h) end
  if clip.SetWidth then pcall(clip.SetWidth, clip, w) end
  if clip.SetHeight then pcall(clip.SetHeight, clip, h) end
  if clip.SetPoint and anchor then
    pcall(clip.SetPoint, clip, "CENTER", anchor, "CENTER", 0, 0)
  elseif clip.SetAllPoints and anchor then
    pcall(clip.SetAllPoints, clip, anchor)
  end
  if content then
    if content.ClearAllPoints then pcall(content.ClearAllPoints, content) end
    if content.SetSize then pcall(content.SetSize, content, w, h) end
    if content.SetWidth then pcall(content.SetWidth, content, w) end
    if content.SetHeight then pcall(content.SetHeight, content, h) end
    -- pas de SetAllPoints : le contenu doit rester à w×h, pas à une taille héritée.
  end
  if clip.SetHorizontalScroll then pcall(clip.SetHorizontalScroll, clip, 0) end
  if clip.SetVerticalScroll then pcall(clip.SetVerticalScroll, clip, 0) end
  clip._innerW, clip._innerH = w, h
  if clip.Show then clip:Show() end
  if t.SetClipsChildren then pcall(t.SetClipsChildren, t, true) end
  if t.icon and t.icon.SetClipsChildren then pcall(t.icon.SetClipsChildren, t.icon, true) end
  return clip, content, w, h
end

-- Place une texture par un coin + SetSize (jamais seulement SetHeight après
-- un étirement LEFT/RIGHT, qui laisse la taille par défaut et déborde).
function S.PlaceClippedTex(tex, parent, w, h, x, y)
  if not tex then return end
  if tex.SetParent and parent then pcall(tex.SetParent, tex, parent) end
  if tex.ClearAllPoints then pcall(tex.ClearAllPoints, tex) end
  w, h = math.max(1, N(w) or 1), math.max(1, N(h) or 1)
  if tex.SetSize then pcall(tex.SetSize, tex, w, h) end
  if tex.SetWidth then pcall(tex.SetWidth, tex, w) end
  if tex.SetHeight then pcall(tex.SetHeight, tex, h) end
  if tex.SetPoint and parent then
    pcall(tex.SetPoint, tex, "BOTTOMLEFT", parent, "BOTTOMLEFT", x or 0, y or 0)
  end
end

function S.EnsureSlotZ(t)
  if t._slotZ then return t._slotZ end
  local parent = t.icon or t.slotBorder or t
  local ok, clip = pcall(CreateFrame, "ScrollFrame", nil, t)
  if not (ok and clip) then return nil end
  if clip.EnableMouse then pcall(clip.EnableMouse, clip, false) end
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
  if not t then return end
  if not on then
    if t._slotZ and t._slotZ.Hide then t._slotZ:Hide() end
    return
  end
  local clip = S.EnsureSlotZ(t)
  if not clip then return end
  local w, h, anchor, inset = S.IconInnerSize(t)
  if clip.ClearAllPoints then pcall(clip.ClearAllPoints, clip) end
  if clip.SetSize then pcall(clip.SetSize, clip, w, h) end
  if clip.SetWidth then pcall(clip.SetWidth, clip, w) end
  if clip.SetHeight then pcall(clip.SetHeight, clip, h) end
  if clip.SetPoint and anchor then
    pcall(clip.SetPoint, clip, "CENTER", anchor, "CENTER", 0, 0)
  elseif clip.SetAllPoints and anchor then
    pcall(clip.SetAllPoints, clip, anchor)
  end
  if clip._content then
    if clip._content.ClearAllPoints then pcall(clip._content.ClearAllPoints, clip._content) end
    if clip._content.SetSize then pcall(clip._content.SetSize, clip._content, w, h) end
    if clip._content.SetWidth then pcall(clip._content.SetWidth, clip._content, w) end
    if clip._content.SetHeight then pcall(clip._content.SetHeight, clip._content, h) end
  end
  clip._innerW, clip._innerH = w, h
  if clip.Show then clip:Show() end
  -- barre large : la goutte du puits cède la place aux z ; en grille, l'icône
  -- de la case total reste visible, les z se dessinent par-dessus (clipés).
  if t._wideOn then
    if t.icon and t.icon.Hide then t.icon:Hide() end
  end
  if t._hg and t._hg.Hide then t._hg:Hide() end
end

function S.TickSlotZ(dt)
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
        if fs.ClearAllPoints then pcall(fs.ClearAllPoints, fs) end
        local x = 2 + ((i - 1) % 3) * math.max(3, (w - 8) / 3)
        if fs.SetPoint then pcall(fs.SetPoint, fs, "BOTTOMLEFT", clip._content or clip, "BOTTOMLEFT", x, y) end
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
    or "Interface\CharacterFrame\TempPortraitAlphaMask"
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
  local style = S.CombatStyle()
  local fill = S.fill or {}
  local p = math.max(0, math.min(1, (N(fill.p) or 0) * (N(fill.drain) or 1)))
  local grey = N(fill.grey) or 0
  -- En barre large, le remplissage combat est déjà dans les segments horizontaux.
  local show = (not t._wideOn) and style ~= "off" and p > 0.01 and grey < 0.85
  local liq = t._cLiq
  if not show then
    if liq and liq.Hide then liq:Hide() end
    return
  end
  liq = S.EnsureCombatLiq(t)
  if not liq then return end
  local clip, content, w, h = S.PlaceIconClip(t)
  w, h = w or 16, h or 16
  if liq.ClearAllPoints then pcall(liq.ClearAllPoints, liq) end
  if liq.SetParent and content then pcall(liq.SetParent, liq, content) end
  -- SetSize explicite, pas SetAllPoints (évite d'hériter d'une taille 100×50).
  if liq.SetSize then pcall(liq.SetSize, liq, w, h) end
  if liq.SetWidth then pcall(liq.SetWidth, liq, w) end
  if liq.SetHeight then pcall(liq.SetHeight, liq, h) end
  if liq.SetPoint then pcall(liq.SetPoint, liq, "BOTTOMLEFT", content or clip, "BOTTOMLEFT", 0, 0) end
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
    if tex.ClearAllPoints then pcall(tex.ClearAllPoints, tex) end
    if tex.SetPoint then pcall(tex.SetPoint, tex, "BOTTOMLEFT", liq, "BOTTOMLEFT", inset, y) end
    if tex.SetSize then pcall(tex.SetSize, tex, math.max(1, w - inset * 2), height) end
    if tex.SetTexture then pcall(tex.SetTexture, tex, "Interface\\Buttons\\WHITE8X8") end
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
  if act == "rested" then
    HideSymbol(t)
    S.ApplySlotZ(t, true)
  elseif act ~= "drop" and S.SHEETS[act] then
    S.ApplySlotZ(t, false)
    S.ApplySheet(t, act)
  else
    S.ApplySlotZ(t, false)
    HideSymbol(t)
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
  eating    = { "En train de manger ou de boire", "La fiole se remplit doucement." },
  rested    = { "Au repos", "Tu te reposes à l'auberge ou en capitale." },
}
S.COMBAT_TIP = "En combat : XP et armes en cours"

function S.ShowExplanation(owner)
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
  if act == "drop" and S.CombatLiquidOn() and (S.LiveCombat() or ((S.fill and S.fill.p) or 0) > 0.05) then
    act = "combat"
  end
  if act == "drop" and S.Want("eating") then act = "eating" end
  if act == "drop" then return end
  local tt = _G.GameTooltip
  if not (tt and owner) then return end
  if type(tt.SetOwner) == "function" then pcall(tt.SetOwner, tt, owner, "ANCHOR_RIGHT") end
  if type(tt.ClearLines) == "function" then pcall(tt.ClearLines, tt) end
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
function S.NeedsDriver()
  local act = S.Active()
  if act ~= "drop" then return true end
  if S.Want("trainer") then return true end
  if S.Want("eating") then return true end
  if S.FillBusy() then return true end
  if (S._jolt or 0) > 0 then return true end
  if S._eatOn then return true end
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

function S.Tick(dt)
  dt = N(dt) or 0
  if dt <= 0 then return end
  if dt > 0.25 then dt = 0.25 end
  -- pêche récente (pour le sursaut à la prise)
  if S.LiveFishing() then S._fishUntil = Now() + 2 end
  S._jolt = math.max(0, (S._jolt or 0) - dt * 4)
  S._phase = (S._phase or 0) + dt * 0.7
  if S._phase > 1 then S._phase = S._phase - math.floor(S._phase) end
  S.SyncFillTargets()
  local rate = S.FILL_RATE
  local f = S.fill
  f.p = Approach(f.p, f.targetP, rate, dt)
  f.grey = Approach(f.grey, f.targetGrey, rate, dt)
  f.drain = Approach(f.drain, f.targetDrain, rate, dt)
  S.TickSheets(dt)
  S.ApplyTotal()
  S.ApplyFlaskFill()
  S.ApplyCombatLiq()
  S.ApplyRegenWave(dt)
  S.ApplyTrainerGlints()
  S.TickSlotZ(dt)
end

function S.Refresh(reason)
  S.SyncFillTargets()
  if S.LiveFishing() then S._fishUntil = Now() + 2 end
  if S.NeedsDriver() then S.StartDriver() end
  S.ApplyTotal()
  S.ApplyFlaskFill()
  S.ApplyCombatLiq()
  S.ApplyRegenWave(0)
  S.ApplyTrainerGlints()
  S.CheckBags()
  S.CheckDurability()
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
-- Vague de repas (réutilise le style « repos » : Dropamine-Wave)
------------------------------------------------------------------------------
function S.EnsureRegenWave(t)
  if not t then return nil end
  local _, content, w, h = S.PlaceIconClip(t)
  local parent = content or t
  if t._eat then
    if parent then
      if t._eat.body and t._eat.body.SetParent then pcall(t._eat.body.SetParent, t._eat.body, parent) end
      if t._eat.wave and t._eat.wave.SetParent then pcall(t._eat.wave.SetParent, t._eat.wave, parent) end
    end
    return t._eat
  end
  if not (parent and type(parent.CreateTexture) == "function") then return nil end
  local body = parent:CreateTexture(nil, "ARTWORK", nil, 3)
  local wave = parent:CreateTexture(nil, "ARTWORK", nil, 4)
  if not (body and wave) then return nil end
  if body.SetColorTexture then pcall(body.SetColorTexture, body, 0.60, 0.80, 1.00, 0.36)
  elseif body.SetTexture then
    pcall(body.SetTexture, body, "Interface\\Buttons\\WHITE8X8")
    if body.SetVertexColor then pcall(body.SetVertexColor, body, 0.60, 0.80, 1.00, 0.36) end
  end
  local tex = (ns.Rested and ns.Rested.WAVE_TEX) or (MEDIA .. "Dropamine-Wave")
  if wave.SetTexture then pcall(wave.SetTexture, wave, tex) end
  if wave.SetVertexColor then pcall(wave.SetVertexColor, wave, 0.60, 0.80, 1.00, 0.80) end
  -- Taille initiale dans le clip, jamais la taille par défaut du client.
  S.PlaceClippedTex(body, parent, w or 16, 1, 0, 0)
  S.PlaceClippedTex(wave, parent, w or 16, 1, 0, 0)
  if body.Hide then body:Hide() end
  if wave.Hide then wave:Hide() end
  t._eat = { body = body, wave = wave, u = 0 }
  return t._eat
end

function S.HideRegenWave(t)
  local e = t and t._eat
  if not e then return end
  if e.body and e.body.Hide then e.body:Hide() end
  if e.wave and e.wave.Hide then e.wave:Hide() end
  S._eatOn = false
end

function S.ApplyRegenWave(dt)
  dt = N(dt) or 0
  local t = S.FlaskTile and S.FlaskTile() or (ns.Wide and ns.Wide.TotalTile and ns.Wide.TotalTile())
  if not t then return end
  local inCombatFill = S.CombatLiquidOn() and ((S.fill and S.fill.p) or 0) > 0.05
  local show = S.Want("eating") and not inCombatFill and not (S.Opt("slotDeath") and S.LiveDeath())
  if not show then
    S.HideRegenWave(t)
    return
  end
  local e = S.EnsureRegenWave(t)
  if not e then return end
  local clip, content, w, H = S.PlaceIconClip(t)
  w, H = w or 16, H or 16
  local a = content or clip or t.icon or t
  local L = math.min(H * 0.55, H)
  S.PlaceClippedTex(e.body, a, w, L, 0, 0)
  if e.body.Show then e.body:Show() end
  local R = ns.Rested
  e.u = (e.u or 0) + dt / ((R and R.LIQ and R.LIQ.charge and R.LIQ.charge.period) or 2.4)
  if e.u > 1 then e.u = e.u - math.floor(e.u) end
  local wh, wy = math.min(8, H), math.max(0, L - 5)
  if wy + wh > H then wy = math.max(0, H - wh) end
  S.PlaceClippedTex(e.wave, a, w, wh, 0, wy)
  if e.wave.SetTexCoord then
    local u = e.u * ((R and R.WAVE_U) or 0.5)
    pcall(e.wave.SetTexCoord, e.wave, u, 0, u + ((R and R.WAVE_U) or 0.5), 1)
  end
  if e.wave.Show then e.wave:Show() end
  local mask = S.IconMaskFor(t)
  if mask then
    if e.body and e.body.AddMaskTexture then pcall(e.body.AddMaskTexture, e.body, mask) end
    if e.wave and e.wave.AddMaskTexture then pcall(e.wave.AddMaskTexture, e.wave, mask) end
  end
  S._eatOn = true
end

S.OPTIONS = {
  { type = "check", key = "slotDeath", label = "Crâne à la mort", default = true,
    help = "Dans le puits de la fiole : un crâne, fiole vidée et grisée, suivi en pause jusqu'à la résurrection." },
  { type = "check", key = "slotFlight", label = "Sablier pendant le vol", default = true,
    help = "Remplace la goutte par le sablier pendant un trajet aérien. La pause du suivi reste réglée à part." },
  { type = "radio", key = "combatStyle", label = "Style de combat", default = "bubbles",
    choices = { { "bubbles", "Bulles" }, { "sword", "Épée" }, { "off", "Désactivé" } },
    cmd = "/drop combat bulles|epee|off",
    help = "Bulles (défaut) : la fiole se remplit en rouge et bleu, avec des bulles ambrées. Épée : le même liquide, plus une petite épée de bronze dans le puits. Désactivé : pas d'effet de combat.",
    get = function() return S.CombatStyle() end,
    set = function(v) S.SetCombatStyle(v) S.Refresh("option") end },
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
  { type = "check", key = "slotEating", label = "Vague au repas", default = true,
    help = "Une vague douce dans la fiole pendant que tu manges ou bois (régénération)." },
  { type = "check", key = "slotRested", label = "« z » de repos sur la fiole", default = true,
    help = "Les « z » de repos montent dans le puits de la fiole à l'auberge ou en capitale, s'il n'y a pas d'autre symbole." },
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
  if type(key) == "string" and (key:find("^slot", 1) or key == "trainerRankToast" or key == "combatStyle" or key == "quietAuto") then
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
    "PLAYER_ENTERING_WORLD", "PLAYER_UPDATE_RESTING",
    "TRAINER_SHOW", "TRAINER_CLOSED", "GOSSIP_SHOW", "GOSSIP_CLOSED",
    "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT",
    "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA",
    "SKILL_LINES_CHANGED", "CHAT_MSG_SKILL",
  }
  for i = 1, #evs do
    local ev = evs[i]
    ns.On(ev, function(...)
      if ev == "BAG_UPDATE" or ev == "BAG_UPDATE_DELAYED" or ev == "CHAT_MSG_LOOT" or ev == "LOOT_CLOSED" then
        pcall(S.OnCatch)
        pcall(S.CheckBags)
      end
      if ev == "UPDATE_INVENTORY_DURABILITY" or ev == "PLAYER_EQUIPMENT_CHANGED" then
        pcall(S.CheckDurability)
      end
      if ev == "UI_ERROR_MESSAGE" then
        pcall(S.OnInvFullError, ...)
      end
      if ev == "UNIT_AURA" then
        local unit = select(2, ...)
        if type(unit) ~= "string" then unit = select(1, ...) end
        if type(unit) == "string" and unit ~= "player" then return end
      end
      pcall(S.Refresh, ev)
    end)
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

ns.SlashExt = ns.SlashExt or {}
ns.SlashExt.combat = function(rest)
  local arg = (rest or ""):match("^%s*(%S*)") or ""
  if arg == "" then
    local cur = S.CombatStyle()
    local label = (cur == "sword" and Tr["Épée"]) or (cur == "off" and Tr["Désactivé"]) or Tr["Bulles"]
    ns.Print((Tr["style de combat"] or "style de combat") .. " : " .. (label or cur) .. ". /drop combat bulles|epee|off")
    return
  end
  local n = S.SetCombatStyle(arg)
  S.Refresh("slash")
  ns.Print((Tr["style de combat"] or "style de combat") .. " : " .. n)
end
ns.HelpExt = ns.HelpExt or {}
ns.HelpExt[#ns.HelpExt + 1] = "/drop combat bulles|epee|off : style de combat"
