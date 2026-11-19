-- Dropamine 2.6.0 : « scanner discret ».
-- Apprend ce que les créatures donnent vraiment (butin observé), lit les recettes
-- connues et leurs couleurs de difficulté, puis signale discrètement une créature
-- utile (petite icône au-dessus de la barre de nom) et les nœuds de récolte
-- (ligne d'info-bulle). Aucune table de butin inventée, jamais en combat, secret-safe.
local ADDON, ns = ...
local Tr = ns.L   -- 3.5.19 : textes traduits (Locales/)
local Scanner = {}
ns.Scanner = Scanner

local function N(v) return ns.N(v) end
local function Call(fn, ...)
  if type(fn) ~= "function" then return nil end
  local r = { pcall(fn, ...) }
  if not r[1] then return nil end
  return unpack(r, 2)
end
local function Str(v)
  if type(v) ~= "string" then return nil end
  if ns.IsSecret(v) then return nil end
  return v
end
local function InCombat()
  if type(InCombatLockdown) == "function" and Call(InCombatLockdown) then return true end
  if type(UnitAffectingCombat) == "function" and Call(UnitAffectingCombat, "player") then return true end
  return false
end
Scanner.InCombat = InCombat

-- Compétences suivies par le scanner : id du catalogue.
Scanner.LOOT_SKILLS = { cooking = true, firstaid = true }
-- Couleurs natives de difficulté (TradeSkillTypeColor du client si présent).
local DIFF_ORDER = { optimal = 3, medium = 2, easy = 1, trivial = 0 }
local DIFF_FR = { optimal = "orange", medium = "jaune", easy = "vert", trivial = "gris", neutral = "à dépecer" }
local DIFF_FALLBACK = {
  optimal = { 1.00, 0.50, 0.25 }, medium = { 1.00, 1.00, 0.00 },
  easy = { 0.25, 0.75, 0.25 }, trivial = { 0.50, 0.50, 0.50 },
}
Scanner.NEUTRAL_RING = { 0.72, 0.56, 0.32 }   -- bronze neutre (dépeçage, sans difficulté)
function Scanner.DiffColor(diff)
  if diff == "neutral" then return Scanner.NEUTRAL_RING end
  local t = _G.TradeSkillTypeColor
  if type(t) == "table" and type(t[diff]) == "table" and N(t[diff].r) then
    return { t[diff].r, t[diff].g, t[diff].b }
  end
  return DIFF_FALLBACK[diff] or DIFF_FALLBACK.trivial
end
Scanner.DIFF_FR = DIFF_FR

-- SV --------------------------------------------------------------------------
function Scanner.DB()
  local db = ns.EnsureDB()
  db.scanner = db.scanner or {}
  local s = db.scanner
  s.creatures = s.creatures or {}   -- [npcID] = { name, ctype, items = {[itemID]=n}, skills = {cooking=n...}, loots = n }
  s.nodes = s.nodes or {}           -- [nom du nœud] = { skill, req, gainRank }
  s.fishing = s.fishing or {}       -- 2.7.0 : prises par zone
  return s
end

-- 3.3.7 : lecture ROBUSTE des identifiants d'unité (GUID).
-- CAUSE du bug en jeu : « local kind, …, id = strsplit and strsplit("-", guid) »
-- — en Lua, « a and f() » ne garde que la 1re valeur de f() : kind = "Creature",
-- id = nil. Dans le jeu (strsplit existe) AUCUN npcID n'était lu ; seuls les
-- noms déjà mémorisés (ex. une créature dépecée une fois) fonctionnaient.
-- Formats reconnus :
--   * tirets (6.0+, Classic, Forever) : « Creature-0-srv-inst-zone-npcID-spawn »,
--     aussi « Vehicle- », « Pet- » ; casse indifférente ; champ 6, sinon
--     l'avant-dernier champ s'il manque des champs ;
--     « Player- », « GameObject- », « Item- »… : reconnus et REJETÉS ;
--   * hexadécimal ancien (« 0xF130000FAD0012C1 », avec ou sans « 0x », 16
--     chiffres, complété à gauche) : type = 3 premiers chiffres (F13 créature,
--     F15 véhicule, F14 familier, F11 objet, F10/F12 autre, 000… joueur, 4…
--     objet d'inventaire) ; npcID = chiffres 5-10 (serveurs 1.12 / 2.x / 3.x :
--     entrée en bits 24-47) ou 4-8 (4.x : bits 32-51) ; la disposition dont
--     le npcID existe dans la base est choisie, sinon 1.12-3.x.
Scanner.GUID_KINDS = { creature = "Creature", vehicle = "Vehicle", pet = "Pet", player = "Player", gameobject = "GameObject",
  item = "Item", corpse = "Corpse", areatrigger = "AreaTrigger", vignette = "Vignette", cast = "Cast", battlepet = "BattlePet" }
Scanner.NPC_KINDS = { Creature = true, Vehicle = true, Pet = true }
Scanner.HEX_KINDS = { F13 = "Creature", F15 = "Vehicle", F14 = "Pet", F11 = "GameObject", F10 = "Autre", F12 = "Transport" }
Scanner._guidCache = {}
Scanner._guidN = 0
local function SDB() return ns.ScannerDB end
local function KnownNpc(id)
  if not id or id <= 0 then return false end
  if Scanner.StaticCreature and Scanner.StaticCreature(id) then return true end
  local db = SDB()
  if db and db.npcs and db.npcs[id] then return true end
  return Scanner.DB().creatures[id] ~= nil
end
function Scanner.ParseGUIDRaw(guid)
  if guid:find("-", 1, true) then
    local parts = {}
    for p in string.gmatch(guid, "[^%-]+") do parts[#parts + 1] = p end
    local raw = parts[1] or ""
    local kind = Scanner.GUID_KINDS[raw:lower()] or raw
    if not Scanner.NPC_KINDS[kind] then return { kind = kind, path = "tirets (" .. raw .. ", rejeté)" } end
    local id = tonumber(parts[6])
    if id and id > 0 then return { kind = kind, npc = id, path = "tirets (" .. raw .. ", champ 6)" } end
    local alt = #parts >= 3 and tonumber(parts[#parts - 1]) or nil
    if alt and alt > 0 then return { kind = kind, npc = alt, path = "tirets (" .. raw .. ", avant-dernier champ, " .. #parts .. " champs)" } end
    return { kind = kind, path = "tirets (" .. raw .. ", npcID illisible)" }
  end
  local hex = guid:match("^0[xX](%x+)$") or guid:match("^(%x+)$")
  if hex and #hex <= 16 and #hex >= 8 then
    hex = string.rep("0", 16 - #hex) .. hex:upper()
    local hi = hex:sub(1, 3)
    local kind = Scanner.HEX_KINDS[hi]
    if not kind then
      if hex:sub(1, 1) == "0" then kind = "Player" elseif hex:sub(1, 1) == "4" then kind = "Item" else kind = "Inconnu" end
    end
    if not Scanner.NPC_KINDS[kind] then return { kind = kind, path = "hexadécimal (" .. hi .. " = " .. kind .. ", rejeté)" } end
    local a = tonumber(hex:sub(5, 10), 16)
    local b = tonumber(hex:sub(4, 8), 16)
    if KnownNpc(a) then return { kind = kind, npc = a, path = "hexadécimal 1.12-3.x (chiffres 5-10, PNJ de la base)" } end
    if KnownNpc(b) then return { kind = kind, npc = b, path = "hexadécimal 4.x (chiffres 4-8, PNJ de la base)" } end
    if a and a > 0 then return { kind = kind, npc = a, path = "hexadécimal 1.12-3.x (chiffres 5-10, PNJ hors base)" } end
    return { kind = kind, path = "hexadécimal (npcID nul)" }
  end
  return { path = "format inconnu" }
end
function Scanner.ParseGUID(guid)
  guid = Str(guid)
  if not guid then return nil end
  local c = Scanner._guidCache[guid]
  if c then return c end
  c = Scanner.ParseGUIDRaw(guid)
  Scanner._guidN = Scanner._guidN + 1
  if Scanner._guidN > 512 then Scanner._guidCache, Scanner._guidN = {}, 1 end
  Scanner._guidCache[guid] = c
  return c
end
function Scanner.NpcID(guid)
  local g = Scanner.ParseGUID(guid)
  return g and g.npc or nil
end

-- Repli par NOM localisé (FR et EN, accents / tirets / apostrophes / casse
-- ignorés) : base Forever (ScannerDB.npcs) + créatures apprises. Index construit
-- une seule fois. Plusieurs PNJ du même nom : celui dont la fourchette de niveau
-- contient le niveau de l'unité.
function Scanner.NpcNameIndex()
  if Scanner._npcNames then return Scanner._npcNames end
  local idx = {}
  local db = SDB()
  for id, raw in pairs(db and db.npcs or {}) do
    local en, fr, lmin, lmax = raw:match("^([^|]*)|([^|]*)|([^|]*)|([^|]*)")
    local e = { id = id, lmin = tonumber(lmin), lmax = tonumber(lmax) }
    for _, nm in ipairs({ fr, en }) do
      if nm and nm ~= "" then
        local k = ns.Fold(nm)
        idx[k] = idx[k] or {}
        local dup = false
        for _, x in ipairs(idx[k]) do if x.id == id then dup = true end end
        if not dup then table.insert(idx[k], e) end
      end
    end
  end
  for id, c in pairs(Scanner.DB().creatures) do
    if c.name then
      local k = ns.Fold(c.name)
      idx[k] = idx[k] or {}
      local dup = false
      for _, x in ipairs(idx[k]) do if x.id == id then dup = true end end
      if not dup then table.insert(idx[k], { id = id, learned = true }) end
    end
  end
  for _, l in pairs(idx) do table.sort(l, function(x, y) return x.id < y.id end) end
  Scanner._npcNames = idx
  return idx
end
function Scanner.NpcByName(name, level)
  name = Str(name)
  if not name then return nil, "sans nom" end
  local list = Scanner.NpcNameIndex()[ns.Fold(name)]
  if not list or #list == 0 then return nil, "nom absent de la base" end
  level = N(level)
  if level and level > 0 then
    for _, e in ipairs(list) do
      if e.lmin and e.lmax and level >= e.lmin and level <= e.lmax then return e.id, "nom + niveau " .. level .. " (PNJ " .. e.id .. ")" end
    end
    for _, e in ipairs(list) do
      if e.lmin and e.lmax and level >= e.lmin - 2 and level <= e.lmax + 2 then return e.id, "nom + niveau proche (PNJ " .. e.id .. ")" end
    end
  end
  return list[1].id, "nom (PNJ " .. list[1].id .. (#list > 1 and (", " .. #list .. " homonymes") or "") .. ")"
end

-- Clé de corps stable quand le GUID ne se lit pas (lue ensuite par NpcID).
function Scanner.UnitKey(unit, id)
  local raw = Str(Call(UnitGUID, unit))
  if raw and Scanner.NpcID(raw) == id then return raw end
  local tail = raw and (raw:gsub("[^%w]", "")) or ""
  if tail == "" and raw then tail = (raw:gsub(".", function(ch) return string.format("%02x", ch:byte()) end)) end
  if tail == "" then tail = (ns.Fold(Call(UnitName, unit) or "?"):gsub("[^%w]", "")) end
  return "Creature-0-0-0-0-" .. id .. "-" .. tail
end

-- npcID d'une unité : GUID, sinon (ni joueur, ni objet) nom localisé.
-- 2e valeur : { raw, path, kind, how } pour /drop scanner pourquoi et /drop debug.
Scanner.lastUnitParse = {}
-- Joueur : UnitIsPlayer, ou GUID de type Player (Classic « Player-… » / 0x0…).
-- Un joueur n'a pas de type de créature : on ne le traite jamais comme un PNJ,
-- même si le GUID a été lu trop loin et qu'un nombre en sort.
function Scanner.IsPlayerUnit(unit)
  if Call(UnitIsPlayer, unit) then return true end
  local g = Scanner.ParseGUID(Call(UnitGUID, unit))
  return (g and g.kind == "Player") and true or false
end
function Scanner.UnitNpcID(unit)
  local raw = Call(UnitGUID, unit)
  local g = Scanner.ParseGUID(raw)
  local info = { unit = unit, raw = (type(raw) == "string" and not (ns.IsSecret and ns.IsSecret(raw))) and raw or (raw == nil and "nil" or "protégé"),
    path = g and g.path or "aucun GUID", kind = g and g.kind }
  Scanner.lastUnitParse[unit or "?"] = info
  if Call(UnitIsPlayer, unit) then info.how, info.kind = "rejeté (UnitIsPlayer)", "Player" return nil, info end
  if g and g.kind == "Player" then info.how, info.kind = "rejeté (GUID Player)", "Player" return nil, info end
  if g and g.npc then info.how = "GUID" return g.npc, info end
  if g and g.kind and not Scanner.NPC_KINDS[g.kind] and g.kind ~= "Inconnu" then info.how = "rejeté (" .. g.kind .. ")" return nil, info end
  if not Call(UnitExists, unit) and raw == nil then info.how = "aucune unité" return nil, info end
  local id, how = Scanner.NpcByName(Call(UnitName, unit), Call(UnitLevel, unit))
  info.how = id and ("repli " .. how) or ("introuvable (" .. tostring(how) .. ")")
  return id, info
end

-- Mémoire courte : npcID → type / nom (vu en cible, survol ou barre de nom).
Scanner.seen = {}
function Scanner.NoteUnit(unit)
  if not unit then return nil end
  local id = Scanner.UnitNpcID(unit)
  if not id then return nil end
  local ctype = Str(Call(UnitCreatureType, unit))
  local family = Str(Call(_G.UnitCreatureFamily, unit))
  local name = Str(Call(UnitName, unit))
  local e = Scanner.seen[id] or {}
  e.ctype = ctype or e.ctype
  e.family = family or e.family
  e.name = name or e.name
  Scanner.seen[id] = e
  local c = Scanner.DB().creatures[id]
  if c then
    c.ctype = c.ctype or e.ctype
    c.family = c.family or e.family
    c.name = c.name or e.name
  end
  return id, e
end

-- Classe d'objet : Enum du client si présent, sinon sous-type texte.
local SUBTYPE_SKILL = { viande = "cooking", meat = "cooking", tissu = "firstaid", cloth = "firstaid", cuir = "skinning", leather = "skinning" }
-- v2.8.0 : base précalculée WoW Forever (Data/ScannerDB.lua), lue à la demande.
local KIND = { c = "cooking", f = "firstaid", s = "skinning" }
Scanner.KIND = KIND
local function SDB() return ns.ScannerDB end
local function Split(str, sep)
  local out = {}
  for part in string.gmatch(str or "", "[^" .. sep .. "]+") do out[#out + 1] = part end
  return out
end
Scanner._itemCache = {}
function Scanner.StaticItem(itemID)
  local db = SDB()
  if not db or not itemID then return nil end
  local c = Scanner._itemCache[itemID]
  if c ~= nil then return c or nil end
  local raw = db.items and db.items[itemID]
  if not raw then Scanner._itemCache[itemID] = false return nil end
  local p = Split(raw, "|")
  c = { skill = KIND[p[1]], en = p[2], fr = p[3] }
  Scanner._itemCache[itemID] = c
  return c
end

-- Créature de la base : objets (chance en %) et compétences. Cache par npcID,
-- construit seulement quand une barre de nom apparaît (aucun parcours global).
Scanner._npcCache = {}
function Scanner.StaticCreature(npcID)
  local db = SDB()
  if not db or not npcID then return nil end
  local c = Scanner._npcCache[npcID]
  if c ~= nil then return c or nil end
  local drops = db.drops and db.drops[npcID]
  local skin = db.skin and db.skin[npcID]
  if not drops and not skin then Scanner._npcCache[npcID] = false return nil end
  c = { items = {}, skills = {}, chance = {}, fromDB = true, loots = 0 }
  for _, pair in ipairs(Split(drops, ";")) do
    local id, pm = pair:match("^(%d+):(%d+)$")
    id, pm = tonumber(id), tonumber(pm)
    if id then
      c.items[id] = 1
      c.chance[id] = pm and pm / 10 or nil
      local it = Scanner.StaticItem(id)
      if it and it.skill and it.skill ~= "skinning" then c.skills[it.skill] = (c.skills[it.skill] or 0) + 1 end
    end
  end
  if skin then
    c.skills.skinning = 1
    c.skinItems = {}
    for _, id in ipairs(Split(skin, ",")) do c.skinItems[#c.skinItems + 1] = tonumber(id) end
  end
  local nm = db.npcs and db.npcs[npcID]
  if nm then
    local p = Split(nm, "|")
    c.en, c.fr = p[1], p[2]
    c.name = p[2] or p[1]
  end
  Scanner._npcCache[npcID] = c
  return c
end

function Scanner.ItemSkill(itemID)
  if not itemID then return nil end
  local st = Scanner.StaticItem(itemID)
  if st and st.skill then return st.skill end
  local okI, _, _, subType, _, _, classID, subclassID = pcall(function()
    if type(_G.GetItemInfoInstant) == "function" then return _G.GetItemInfoInstant(itemID) end
    if type(_G.C_Item) == "table" and type(_G.C_Item.GetItemInfoInstant) == "function" then return _G.C_Item.GetItemInfoInstant(itemID) end
  end)
  if not okI then return nil end
  local E = _G.Enum
  local tg = E and E.ItemClass and E.ItemClass.Tradegoods
  local sub = E and E.ItemTradeGoodsSubclass
  if tg and N(classID) == tg and sub then
    if sub.Meat and N(subclassID) == sub.Meat then return "cooking" end
    if sub.Cloth and N(subclassID) == sub.Cloth then return "firstaid" end
    if sub.Leather and N(subclassID) == sub.Leather then return "skinning" end
  end
  subType = Str(subType)
  if subType then return SUBTYPE_SKILL[ns.Fold(subType)] end
  return nil
end

function Scanner.ItemIDFromLink(link)
  link = Str(link)
  if not link then return nil end
  return N(link:match("item:(%d+)"))
end

-- Enregistre un butin observé (créature → objet).
function Scanner.Learn(npcID, itemID, qty, wasSkin)
  if not npcID or not itemID then return false end
  local skill = Scanner.ItemSkill(itemID)
  local db = Scanner.DB()
  local c = db.creatures[npcID]
  if not c then
    local s = Scanner.seen[npcID] or {}
    c = { name = s.name, ctype = s.ctype, family = s.family, items = {}, skills = {}, loots = 0 }
    db.creatures[npcID] = c
    Scanner._nameIndex = nil
  end
  c.items[itemID] = (c.items[itemID] or 0) + (N(qty) or 1)
  -- Peau : seulement si le butin vient d'un dépeçage réussi.
  if skill == "skinning" and not wasSkin then skill = nil end
  if skill then c.skills[skill] = (c.skills[skill] or 0) + 1 end
  Scanner._learnVer = (Scanner._learnVer or 0) + 1
  return skill
end

Scanner._lootedGUIDs = {}
Scanner._lootOpens = {}      -- [guid] = heure de la 1re ouverture du butin
Scanner.CORPSE_TTL = 10      -- s : un message de butin reste associé au dernier corps

local function Now() return N(Call(GetTime)) or 0 end
local function SkinCastRecent() return Scanner._skinCast and (Now() - Scanner._skinCast) < 5 end

-- Corps looté : source du butin (GetLootSourceInfo), sinon cible morte, sinon survol mort.
function Scanner.CorpseGUID()
  local g = Call(GetLootSourceInfo, 1)
  if Str(g) and Scanner.NpcID(g) then return g, "GetLootSourceInfo" end
  for _, u in ipairs({ "target", "mouseover" }) do
    if Call(UnitIsDead, u) then
      local id = Scanner.UnitNpcID(u)
      if id then return Scanner.UnitKey(u, id), (u == "target") and "cible morte" or "survol mort" end
    end
  end
  return nil, "aucune source"
end

-- Deuxième ouverture du butin d'un même corps : c'est un dépeçage (le cuir
-- obtenu alors compte comme une peau), même sans sort de dépeçage détecté.
local function IsReopen(guid)
  local t0 = guid and Scanner._lootOpens[guid]
  return t0 ~= nil and (Now() - t0) > 1.5
end

function Scanner.OnLootOpened()
  local n = N(Call(GetNumLootItems)) or 0
  local corpse, src = Scanner.CorpseGUID()
  if corpse then
    Scanner.lastCorpse = { guid = corpse, t = Now(), src = src }
  end
  if n <= 0 then return 0 end
  local learned = 0
  local reopen = IsReopen(corpse)
  local skinning = SkinCastRecent() or reopen
  for slot = 1, n do
    local link = Call(GetLootSlotLink, slot)
    local itemID = Scanner.ItemIDFromLink(link)
    if itemID then
      local sources = { Call(GetLootSourceInfo, slot) }
      if #sources == 0 and corpse then sources = { corpse, 1 } end
      for i = 1, #sources, 2 do
        local guid = sources[i]
        local id = Scanner.NpcID(guid)
        -- 3.3.7 : source illisible, un seul corps : celui de la cible / du survol
        if not id and corpse and #sources <= 2 then id = Scanner.NpcID(corpse) guid = corpse end
        if id then
          local key = tostring(guid) .. ":" .. itemID .. (skinning and ":peau" or "")
          if not Scanner._lootedGUIDs[key] then
            Scanner._lootedGUIDs[key] = true
            local sk = Scanner.Learn(id, itemID, sources[i + 1], skinning)
            if sk then learned = learned + 1 end
            Scanner.lastAssoc = string.format("butin %d → PNJ %d (%s)%s", itemID, id, tostring(src), sk and (" : " .. sk) or "")
          end
        end
      end
    end
  end
  if corpse and not Scanner._lootOpens[corpse] then Scanner._lootOpens[corpse] = Now() end
  return learned
end

-- CHAT_MSG_LOOT (repli) : « Vous recevez le butin : [Cuir léger] x2 ».
-- Seulement nos propres butins ; associé à la cible morte, sinon au dernier corps.
Scanner.SELF_LOOT = { "^Vous recevez le butin", "^Vous recevez", "^You receive loot", "^You receive" }
function Scanner.ParseChatLoot(msg)
  msg = Str(msg)
  if not msg then return nil end
  local mine = false
  if not Scanner._selfLootG then   -- 3.5.19 : préfixes du client (toute langue)
    Scanner._selfLootG = true
    for _, g in ipairs({ "LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_SELF", "LOOT_ITEM_PUSHED_SELF_MULTIPLE", "LOOT_ITEM_PUSHED_SELF" }) do
      local p = ns.GlobalPrefix and ns.GlobalPrefix(g)
      if p then Scanner.SELF_LOOT[#Scanner.SELF_LOOT + 1] = p end
    end
  end
  for _, pat in ipairs(Scanner.SELF_LOOT) do if msg:find(pat) then mine = true break end end
  if not mine then return nil end
  local itemID = Scanner.ItemIDFromLink(msg)
  if not itemID then return nil end
  local qty = N(msg:match("|r%s*[xX×](%d+)")) or N(msg:match("%]%s*[xX×](%d+)")) or 1
  return itemID, qty
end

function Scanner.OnChatLoot(msg)
  local itemID, qty = Scanner.ParseChatLoot(msg)
  if not itemID then return nil end
  local guid, src
  if Call(UnitIsDead, "target") then
    local tid = Scanner.UnitNpcID("target")
    if tid then guid, src = Scanner.UnitKey("target", tid), "cible morte" end
  end
  local lc = Scanner.lastCorpse
  if not guid and lc and (Now() - (lc.t or 0)) <= Scanner.CORPSE_TTL then guid, src = lc.guid, "dernier corps (" .. tostring(lc.src) .. ")" end
  if not guid then Scanner.lastAssoc = "message de butin " .. itemID .. " sans corps associé" return nil end
  local id = Scanner.NpcID(guid)
  local skinning = SkinCastRecent() or IsReopen(guid)
  local key = tostring(guid) .. ":" .. itemID .. (skinning and ":peau" or "")
  if id and not Scanner._lootedGUIDs[key] then
    Scanner._lootedGUIDs[key] = true
    local sk = Scanner.Learn(id, itemID, qty, skinning)
    Scanner.lastAssoc = string.format("message %d x%d → PNJ %d (%s)%s", itemID, qty, id, src, sk and (" : " .. sk) or "")
    return id, sk
  end
  return id
end

-- Recettes (métier ouvert) : API classique, puis C_TradeSkillUI. -----------------
local DIFF_NAMES = { optimal = "optimal", medium = "medium", easy = "easy", trivial = "trivial", difficult = "optimal" }
-- 3.0.1 : nom de recette nettoyé (« Bandage épais en laine [3] » → sans le compte).
local function CleanRecipeName(n)
  n = Str(n)
  if not n then return nil end
  n = string.gsub(n, "%s*%[%d+%]%s*$", "")
  n = string.gsub(n, "%s*%(%d+%)%s*$", "")
  return n ~= "" and n or nil
end
Scanner.CleanRecipeName = CleanRecipeName

-- 3.0.1 : nom du métier ouvert, toutes sources en LECTURE seule.
function Scanner.TradeLineName()
  local nm = Str(Call(_G.GetTradeSkillLine))
  if nm and nm ~= "UNKNOWN" then return nm, "GetTradeSkillLine" end
  local T = _G.C_TradeSkillUI
  if type(T) == "table" then
    if type(T.GetTradeSkillLine) == "function" then
      local a, b = Call(T.GetTradeSkillLine)
      nm = Str(b) or Str(a)
      if nm then return nm, "C_TradeSkillUI.GetTradeSkillLine" end
    end
    for _, fn in ipairs({ "GetBaseProfessionInfo", "GetChildProfessionInfo" }) do
      if type(T[fn]) == "function" then
        local info = Call(T[fn])
        if type(info) == "table" then
          nm = Str(info.parentProfessionName) or Str(info.professionName)
          if nm then return nm, "C_TradeSkillUI." .. fn end
        end
      end
    end
  end
  for _, g in ipairs({ "TradeSkillFrameTitleText", "ProfessionsFrameTitleText" }) do
    local fs = _G[g]
    if type(fs) == "table" and fs.GetText then
      nm = Str(Call(fs.GetText, fs))
      if nm then return nm, g end
    end
  end
  -- 3.5.8 : fenêtre Métiers des clients récents (titre dans TitleContainer)
  local pf = rawget(_G, "ProfessionsFrame")
  if type(pf) == "table" and pf.IsShown and Call(pf.IsShown, pf) then
    local fs
    if type(pf.GetTitleText) == "function" then fs = Call(pf.GetTitleText, pf) end
    if type(fs) ~= "table" then
      local tc = rawget(pf, "TitleContainer")
      fs = type(tc) == "table" and rawget(tc, "TitleText") or nil
    end
    if type(fs) == "table" and fs.GetText then
      nm = Str(Call(fs.GetText, fs))
      if nm then return nm, "ProfessionsFrame (titre)" end
    end
  end
  return nil
end

-- 3.5.8 : client sans GetTradeSkillInfo (WoW Forever, moteur récent) : la
-- fenêtre Métiers se lit par C_TradeSkillUI. Avant, le travail de lecture
-- (ProfJob, 3.5.0) ne connaissait que l'API classique : sur ce client il ne
-- lisait RIEN (pas de « N prêts », « ouvrir la fenêtre du métier » sans fin).
function Scanner.ModernTrade()
  if type(_G.GetTradeSkillInfo) == "function" and type(_G.GetNumTradeSkills) == "function" then
    local n = N(Call(_G.GetNumTradeSkills))
    if n and n > 0 then return false end
  end
  local T = _G.C_TradeSkillUI
  return type(T) == "table" and type(T.GetAllRecipeIDs) == "function"
end
-- fenêtre d'un autre joueur / de guilde / d'un PNJ : jamais mémorisée
function Scanner.ModernForeign()
  local T = _G.C_TradeSkillUI
  if type(T) ~= "table" then return false end
  for _, fn in ipairs({ "IsTradeSkillLinked", "IsTradeSkillGuild", "IsNPCCrafting", "IsRuneforging" }) do
    if type(T[fn]) == "function" and Call(T[fn]) then return true, fn end
  end
  return false
end
function Scanner.ModernIdentity()
  local T = _G.C_TradeSkillUI
  if type(T) ~= "table" then return nil, 0, 0, nil end
  local names, rank = {}, nil
  local function add(v) if v then names[#names + 1] = v end end
  for _, fn in ipairs({ "GetBaseProfessionInfo", "GetChildProfessionInfo" }) do
    if type(T[fn]) == "function" then
      local info = Call(T[fn])
      if type(info) == "table" then
        add(Str(info.parentProfessionName))
        add(Str(info.professionName))
        rank = rank or N(info.skillLevel)
      end
    end
  end
  local lineName = Scanner.TradeLineName()
  add(lineName)
  local id, name
  for _, nm in ipairs(names) do
    if not id then
      id = ns.Style and ns.Style.SkillIdForText and ns.Style.SkillIdForText(nm) or nil
      if id then name = nm end
    end
  end
  -- nombre de recettes APPRISES (GetAllRecipeIDs liste aussi les non apprises)
  local ids = Call(T.GetAllRecipeIDs)
  local n = 0
  if type(ids) == "table" and type(T.GetRecipeInfo) == "function" then
    for _, rid in ipairs(ids) do
      local info = Call(T.GetRecipeInfo, rid)
      if type(info) == "table" and info.learned ~= false and not info.isRecipeHeader then n = n + 1 end
    end
  end
  if id and Scanner.RankOf then rank = Scanner.RankOf(id) or rank end
  return id, n, rank or 0, name or lineName
end

-- 3.0.1 : métier déduit des noms de recettes (base Forever : Cuisine / Secourisme).
function Scanner.InferSkillFromRecipes(list)
  local db = SDB()
  if not db or not db.recipes or not list or #list == 0 then return nil end
  Scanner._recipeCode = Scanner._recipeCode or nil
  if not Scanner._recipeCode then
    local idx = {}
    for _, raw in pairs(db.recipes) do
      local p = Split(raw, "|")
      if p[5] then idx[ns.Fold(p[5])] = p[1] end
      if p[6] then idx[ns.Fold(p[6])] = p[1] end
    end
    Scanner._recipeCode = idx
  end
  local votes = {}
  for _, r in ipairs(list) do
    local code = Scanner._recipeCode[ns.Fold(r.name or "")]
    if code then votes[code] = (votes[code] or 0) + 1 end
  end
  local best, bn = nil, 0
  for code, n in pairs(votes) do if n > bn then best, bn = code, n end end
  if best == "c" then return "cooking" elseif best == "f" then return "firstaid" end
  return nil
end

local REL_DIFF_FALLBACK = { [0] = "optimal", [1] = "medium", [2] = "easy", [3] = "trivial" }
-- Une tranche de la liste classique (ProfJob la découpe par ~25). partial = en-tête replié.
function Scanner.ReadTradeRange(i0, i1, list)
  local partial = false
  list = list or {}
  i0, i1 = i0 or 1, i1 or i0
  for i = i0, i1 do
    local name, kind, nAvail, expanded = Call(_G.GetTradeSkillInfo, i)
    name, kind = CleanRecipeName(name), Str(kind)
    if kind == "header" or kind == "subheader" then
      if expanded == false or expanded == 0 then partial = true end
    elseif name and kind then
      local r = { name = name, diff = DIFF_NAMES[kind] or kind, reagents = {}, avail = N(nAvail),
        icon = Str(Call(_G.GetTradeSkillIcon, i)) or N(Call(_G.GetTradeSkillIcon, i)) }
      local nr = N(Call(_G.GetTradeSkillNumReagents, i)) or 0
      for j = 1, nr do
        local rn, _, cnt = Call(_G.GetTradeSkillReagentInfo, i, j)
        local id = Scanner.ItemIDFromLink(Call(_G.GetTradeSkillReagentItemLink, i, j))
        r.reagents[#r.reagents + 1] = { id = id, name = Str(rn), count = N(cnt) or 1 }
      end
      list[#list + 1] = r
    end
  end
  return list, partial
end
function Scanner.TradeFiltersPartial()
  if type(_G.GetTradeSkillSubClassFilter) == "function" and Call(_G.GetTradeSkillSubClassFilter, 0) == false then return true end
  if type(_G.GetTradeSkillInvSlotFilter) == "function" and Call(_G.GetTradeSkillInvSlotFilter, 0) == false then return true end
  return false
end
-- Rang + nombre de lignes, sans lire les recettes (clé de cache).
function Scanner.TradeIdentity()
  local name, rank = Call(_G.GetTradeSkillLine)
  name = Str(name)
  if name == "UNKNOWN" then name = nil end
  local n = N(Call(_G.GetNumTradeSkills)) or 0
  local id = name and ns.Style and ns.Style.SkillIdForText and ns.Style.SkillIdForText(name) or nil
  if not id and ns.Activity and ns.Activity.SkillInText then id = ns.Activity.SkillInText(name) end
  local rnk = N(rank)
  if not rnk and id and Scanner.RankOf then rnk = Scanner.RankOf(id) end
  return id, n, rnk or 0, name
end
function Scanner.CommitTradeList(list, partial, lineName, lineSrc, source)
  Scanner.lastReadInfo = { line = lineName, lineSrc = lineSrc, source = source, n = list and #list or 0, partial = partial }
  if not list or #list == 0 then return nil, "aucune recette lue" end
  local id = lineName and ns.Style and ns.Style.SkillIdForText(lineName) or nil
  if not id then id = Scanner.InferSkillFromRecipes(list) end
  if not id then return nil, "métier inconnu : " .. tostring(lineName) end
  local inferred = Scanner.InferSkillFromRecipes(list)
  if inferred and inferred ~= id then
    Scanner.lastReadInfo.rejected = tostring(id) .. " ≠ " .. tostring(inferred)
    return nil, "liste d'un autre métier (" .. tostring(inferred) .. ")"
  end
  local c = ns.CharDB()
  local prev = c.recipes and c.recipes[id]
  if ns.Craft and ns.Craft.Store then return ns.Craft.Store(id, list, source) end
  if prev and prev.list then
    local seen = {}
    for _, r in ipairs(list) do seen[r.name] = true end
    for _, r in ipairs(prev.list) do if r.name and not seen[r.name] then list[#list + 1] = r end end
  end
  c.recipes = c.recipes or {}
  c.recipes[id] = { when = (type(time) == "function" and time()) or 0, list = list, source = source }
  return id, #list
end
function Scanner.ReadRecipes()
  if InCombat() then return nil, "combat" end
  local lineName, lineSrc = Scanner.TradeLineName()
  local list = {}
  local partial = false
  local nTS = N(Call(_G.GetNumTradeSkills))
  local source
  if nTS and nTS > 0 and type(_G.GetTradeSkillInfo) == "function" then
    source = "GetTradeSkillInfo"
    list, partial = Scanner.ReadTradeRange(1, nTS, list)
    if Scanner.TradeFiltersPartial() then partial = true end
  elseif type(_G.C_TradeSkillUI) == "table" and type(_G.C_TradeSkillUI.GetAllRecipeIDs) == "function" then
    source = "C_TradeSkillUI"
    local T = _G.C_TradeSkillUI
    if type(T.IsTradeSkillReady) == "function" and Call(T.IsTradeSkillReady) == false then return nil, "métier pas prêt" end
    local rd = _G.Enum and _G.Enum.TradeskillRelativeDifficulty
    local map = {}
    for k, v in pairs(REL_DIFF_FALLBACK) do map[k] = v end
    if rd then
      if rd.Optimal then map[rd.Optimal] = "optimal" end
      if rd.Medium then map[rd.Medium] = "medium" end
      if rd.Easy then map[rd.Easy] = "easy" end
      if rd.Trivial then map[rd.Trivial] = "trivial" end
    end
    if Scanner.ModernForeign() then return nil, "fenêtre d'un autre joueur" end
    if not lineName then
      local _, _, _, nm = Scanner.ModernIdentity()
      if nm then lineName, lineSrc = nm, "C_TradeSkillUI (profession)" end
    end
    local ids = Call(T.GetAllRecipeIDs)
    for _, rid in ipairs(type(ids) == "table" and ids or {}) do
      local info = Call(T.GetRecipeInfo, rid)
      local nm = type(info) == "table" and CleanRecipeName(info.name) or nil
      if nm and info.learned ~= false and not info.isRecipeHeader and not info.disabled then
        local diff = map[N(info.relativeDifficulty) or -1] or (type(info.difficulty) == "string" and DIFF_NAMES[info.difficulty]) or nil
        -- 3.5.8 : « ne fait plus progresser » dit par le jeu = gris
        if info.canSkillUp == false then diff = "trivial" end
        local r = { name = nm, diff = diff, reagents = {}, icon = info.icon, avail = N(info.numAvailable), recipeID = N(rid) }
        local sch = type(T.GetRecipeSchematic) == "function" and Call(T.GetRecipeSchematic, rid, false)
        if type(sch) == "table" then
          for _, slotS in ipairs(type(sch.reagentSlotSchematics) == "table" and sch.reagentSlotSchematics or {}) do
            local first = type(slotS) == "table" and type(slotS.reagents) == "table" and slotS.reagents[1]
            -- composants obligatoires seulement (emplacements optionnels ignorés)
            if first and N(first.itemID) and slotS.required ~= false then
              r.reagents[#r.reagents + 1] = { id = N(first.itemID), count = N(slotS.quantityRequired) or 1 }
            end
          end
        elseif type(T.GetRecipeNumReagents) == "function" then
          for j = 1, (N(Call(T.GetRecipeNumReagents, rid)) or 0) do
            local rn, _, cnt = Call(T.GetRecipeReagentInfo, rid, j)
            local link = type(T.GetRecipeReagentItemLink) == "function" and Call(T.GetRecipeReagentItemLink, rid, j) or nil
            r.reagents[#r.reagents + 1] = { id = Scanner.ItemIDFromLink(link), name = Str(rn), count = N(cnt) or 1 }
          end
        end
        list[#list + 1] = r
      end
    end
  end
  return Scanner.CommitTradeList(list, partial, lineName, lineSrc, source)
end

-- Meilleure difficulté utile d'une créature pour une compétence (recettes connues).
-- Recettes de la base (enseignées par le maître, apprises au rang actuel) :
-- repli tant que la fenêtre du métier n'a jamais été lue. Difficulté d'après
-- les seuils de couleur Forever (orange < jaune < vert < gris).
Scanner._dbRecipes = {}
function Scanner.DBRecipes(skill)
  local db = SDB()
  if not db or not db.recipes then return nil end
  local rank = Scanner.RankOf(skill)
  if not rank or rank <= 0 then return nil end
  local cache = Scanner._dbRecipes[skill]
  if cache and cache.rank == rank then return cache end
  local code = (skill == "cooking") and "c" or ((skill == "firstaid") and "f" or nil)
  if not code then return nil end
  local list = {}
  for _, raw in pairs(db.recipes) do
    local p = Split(raw, "|")
    if p[1] == code and (p[7] == "t" or p[7] == "b") then
      local learn = tonumber(p[2]) or 9999
      if learn <= rank then
        local col = Split(p[3], ",")
        local y, g, gr = tonumber(col[2]) or 0, tonumber(col[3]) or 0, tonumber(col[4]) or 0
        local diff = (rank < y) and "optimal" or ((rank < g) and "medium" or ((rank < gr) and "easy" or "trivial"))
        local r = { name = ns.GameName(p[5], p[6]), diff = diff, reagents = {} }
        for _, rg in ipairs(Split(p[4], ",")) do
          local id, n = rg:match("^(%d+)x(%d+)$")
          if id then r.reagents[#r.reagents + 1] = { id = tonumber(id), count = tonumber(n) } end
        end
        list[#list + 1] = r
      end
    end
  end
  cache = { rank = rank, list = list, source = "base Forever" }
  Scanner._dbRecipes[skill] = cache
  return cache
end

function Scanner.CreatureDiff(c, skill)
  if not c or not c.items then return nil end
  if ns.Craft and ns.Craft.Match then
    local m, best = ns.Craft.Match(c, skill)
    if best then return best, m[1].recipe, m end
    return nil
  end
  local rec = ns.CharDB().recipes and ns.CharDB().recipes[skill]
  if not rec then rec = Scanner.DBRecipes(skill) end
  if not rec then return nil end
  local best, bestR
  for _, r in ipairs(rec.list or {}) do
    local o = DIFF_ORDER[r.diff or ""] or 0
    if o > 0 then
      for _, rg in ipairs(r.reagents or {}) do
        if rg.id and c.items[rg.id] and Scanner.ItemSkill(rg.id) == skill then
          if not best or o > DIFF_ORDER[best] then best, bestR = r.diff, r end
        end
      end
    end
  end
  return best, bestR
end

-- Données d'une créature : npcID exact, sinon même nom ET même famille / type
-- (index par nom construit une seule fois, O(1) ensuite).
function Scanner.FindCreature(npcID, name, family, ctype)
  local db = Scanner.DB()
  local c = npcID and db.creatures[npcID]
  if c then return c, "npcID" end
  if not name then return nil end
  if not Scanner._nameIndex then
    local idx = {}
    for id, cc in pairs(db.creatures) do
      if cc.name then idx[cc.name] = idx[cc.name] or {} table.insert(idx[cc.name], id) end
    end
    Scanner._nameIndex = idx
  end
  for _, id in ipairs(Scanner._nameIndex[name] or {}) do
    local cc = db.creatures[id]
    local fam, typ = true, true
    if cc and family and cc.family and cc.family ~= family then fam = false end
    if cc and ctype and cc.ctype and cc.ctype ~= ctype then typ = false end
    if cc and fam and typ then return cc, "nom + famille (PNJ " .. id .. ")" end
  end
  return nil
end

-- Base d'abord, apprentissage en complément (vue fusionnée, cache par PNJ).
Scanner._viewCache = {}
function Scanner.CreatureFor(npcID, info)
  info = info or {}
  local base = Scanner.StaticCreature(npcID)
  local learned, how = Scanner.FindCreature(npcID, info.name, info.family, info.ctype)
  if not base then return learned, how and ("appris : " .. how) or nil end
  if not learned then return base, "base Forever" end
  local key = npcID
  local v = Scanner._viewCache[key]
  if v and v._ver == (Scanner._learnVer or 0) then return v, v._how end
  v = { items = {}, skills = {}, chance = base.chance, skinItems = base.skinItems, name = base.name, fromDB = true, loots = learned.loots or 0 }
  for id, n in pairs(base.items) do v.items[id] = n end
  for id, n in pairs(learned.items or {}) do v.items[id] = (v.items[id] or 0) + n end
  for k, n in pairs(base.skills) do v.skills[k] = n end
  for k, n in pairs(learned.skills or {}) do v.skills[k] = (v.skills[k] or 0) + n end
  v._ver, v._how = Scanner._learnVer or 0, "base Forever + appris (" .. tostring(how) .. ")"
  Scanner._viewCache[key] = v
  return v, v._how
end

function Scanner.HasSkill(id)
  local rank = Scanner.RankOf(id)
  return rank and rank > 0
end

-- Compétence la plus intéressante pour ce PNJ (couleur orange > jaune > vert).
-- Repli : bête vivante déjà dépecée → icône Dépeçage (anneau bronze neutre).
function Scanner.BestFor(npcID, info)
  info = info or {}
  local c = Scanner.CreatureFor(npcID, info)
  if not c then return nil end
  local bestSkill, bestDiff, bestRecipe, bestMatches
  -- v2.8.1 : seulement si un objet lâché sert à une recette CONNUE non grise.
  for skill in pairs(Scanner.LOOT_SKILLS) do
    local d, r, m = Scanner.CreatureDiff(c, skill)
    if d and (not bestDiff or DIFF_ORDER[d] > DIFF_ORDER[bestDiff]) then bestSkill, bestDiff, bestRecipe, bestMatches = skill, d, r, m end
  end
  if bestSkill then return bestSkill, bestDiff, bestRecipe, bestMatches end
  if not bestSkill and info.alive and (c.skills.skinning or 0) > 0 and Scanner.HasSkill("skinning") then
    return "skinning", "neutral", nil
  end
  return bestSkill, bestDiff, bestRecipe
end

-- Barres de nom ----------------------------------------------------------------
Scanner.plates = {}
Scanner.toasted = {}
-- v2.7.1 : aucun champ posé sur les barres de nom natives (table faible).
Scanner.marks = setmetatable({}, { __mode = "k" })
local ICON = 14

local function MakeMarker(plate)
  local f = CreateFrame("Frame", nil, plate)
  f:SetSize(ICON + 2, ICON + 2)
  f:SetPoint("BOTTOM", plate, "TOP", 0, 2)
  f.icon = f:CreateTexture(nil, "ARTWORK")
  f.icon:SetPoint("TOPLEFT", 1, -1)
  f.icon:SetPoint("BOTTOMRIGHT", -1, 1)
  if f.icon.SetTexCoord then pcall(f.icon.SetTexCoord, f.icon, 0.07, 0.93, 0.07, 0.93) end
  f.ring = {}
  for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
    local t = f:CreateTexture(nil, "OVERLAY")
    pcall(t.SetTexture, t, "Interface\\Buttons\\WHITE8X8")
    if side == "TOP" or side == "BOTTOM" then
      t:SetPoint(side .. "LEFT", f, side .. "LEFT", 0, 0)
      t:SetPoint(side .. "RIGHT", f, side .. "RIGHT", 0, 0)
      t:SetHeight(1)
    else
      t:SetPoint("TOP" .. side, f, "TOP" .. side, 0, 0)
      t:SetPoint("BOTTOM" .. side, f, "BOTTOM" .. side, 0, 0)
      t:SetWidth(1)
    end
    f.ring[side] = t
  end
  return f
end

function Scanner.Enabled()
  return ns.Opt("scanner")
end

function Scanner.OnPlateAdded(unit)
  if not Scanner.Enabled() or not ns.Opt("scannerIcons") or InCombat() then return nil end
  if Scanner.IsPlayerUnit(unit) then
    local plate = type(_G.C_NamePlate) == "table" and Call(_G.C_NamePlate.GetNamePlateForUnit, unit)
    local m = plate and Scanner.marks[plate]
    if m then m:Hide() end
    return nil
  end
  local plate = type(_G.C_NamePlate) == "table" and Call(_G.C_NamePlate.GetNamePlateForUnit, unit)
  if type(plate) ~= "table" then return nil end
  local id, seen = Scanner.NoteUnit(unit)
  local info = { name = seen and seen.name, family = seen and seen.family, ctype = seen and seen.ctype,
    alive = not Call(UnitIsDead, unit) }
  local skill, diff, recipe, matches = Scanner.BestFor(id, info)
  local m = Scanner.marks[plate]
  if not skill then
    if m then m:Hide() end
    return nil
  end
  local e = ns.CATALOG_BY_ID and ns.CATALOG_BY_ID[skill]
  -- 3.3.8 : repère UNIQUE par barre (Gather.lua : une icône par métier, centrée
  -- au-dessus du nom) ; l'ancien repère du scanner n'est plus dessiné.
  if not Scanner.UnifiedMarkers then
    m = m or MakeMarker(plate)
    Scanner.marks[plate] = m
    pcall(m.icon.SetTexture, m.icon, e and e.icon or ns.FALLBACK_ICON)
    local col = Scanner.DiffColor(diff)
    for _, t in pairs(m.ring) do pcall(t.SetVertexColor, t, col[1], col[2], col[3], 1) end
    m._skill, m._diff = skill, diff
    m:Show()
  elseif m then m:Hide() end
  Scanner.plates[unit] = plate
  -- Toast facultatif, une fois par créature (npcID) et par session :
  -- « <créature> → <ingrédient> → <recette> (+1) », jusqu'à 3 recettes.
  local tkey = id or (seen and seen.name) or "?"
  if diff ~= "neutral" and ns.OptOff("scannerToast") and not Scanner.toasted[tkey] and ns.UI and ns.UI.SpawnDrop then
    Scanner.toasted[tkey] = true
    local lines = ns.Craft and ns.Craft.MatchLines(seen and seen.name, matches) or {}
    ns.UI:SpawnDrop(e and e.icon, lines[1] or ((e and ns.CatalogDisplayName(e) or skill) .. Tr[" : "] .. tostring(seen and seen.name)), lines[2], nil, nil, nil,
      { kind = "scanner", hint = lines[3], hintRaw = true })
    if ((ns.SoundOk and ns.SoundOk("scannerSound")) or (not ns.SoundOk and ns.OptOff("scannerSound"))) and type(PlaySound) == "function" then
      local kit = _G.SOUNDKIT and _G.SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON
      if kit then pcall(PlaySound, kit) end
    end
  end
  return skill, diff
end

function Scanner.OnPlateRemoved(unit)
  local plate = Scanner.plates[unit]
  local m = plate and Scanner.marks[plate]
  if m then m:Hide() end
  Scanner.plates[unit] = nil
end

function Scanner.HideAll()
  for unit, plate in pairs(Scanner.plates) do
    local m = Scanner.marks[plate]
    if m then m:Hide() end
  end
end

function Scanner.RescanPlates()
  if InCombat() or not Scanner.Enabled() then return end
  local plates = type(_G.C_NamePlate) == "table" and Call(_G.C_NamePlate.GetNamePlates) or {}
  for _, p in ipairs(plates) do
    local unit = p.namePlateUnitToken or (p.UnitFrame and p.UnitFrame.unit)
    if unit then Scanner.OnPlateAdded(unit) end
  end
end

-- Info-bulle des nœuds : « Requiert Minage 75 » / « Requiert Minage (75) ». ---
Scanner.GATHER = { mining = true, herbalism = true, skinning = true }
function Scanner.ParseRequirement(text)
  text = Str(text)
  if not text then return nil end
  local okM, sk, req = true, nil, nil
  if ns.MatchGlobal then sk, req = ns.MatchGlobal("ITEM_MIN_SKILL", text) end   -- 3.5.19 : « Requires %s (%d) » du client
  if not sk then okM, sk, req = pcall(string.match, text, "^Requiert (.-) %(?(%d+)%)?$") end
  if not okM or not sk then okM, sk, req = pcall(string.match, text, "^Requires (.-) %(?(%d+)%)?$") end
  if not okM or not sk then return nil end
  local id = ns.Style and ns.Style.SkillIdForText(sk)
  if not id or not Scanner.GATHER[id] then return nil end
  return id, N(req), sk
end

function Scanner.RankOf(id)
  local snap = (ns.SkillRankSnapshotCached and ns.SkillRankSnapshotCached()) or (ns.SkillRankSnapshot and ns.SkillRankSnapshot()) or {}
  local e = ns.CATALOG_BY_ID and ns.CATALOG_BY_ID[id]
  if not e then return nil end
  local s = snap[ns.Fold(e.name)]
  if not s then
    for _, a in ipairs(e.aliases or {}) do s = s or snap[ns.Fold(a)] end
  end
  return s and N(s.rank) or nil, e
end

-- 3.3.8 : plafond actuel d'une compétence (rang max lu dans les compétences)
function Scanner.MaxOf(id)
  local snap = (ns.SkillRankSnapshotCached and ns.SkillRankSnapshotCached()) or (ns.SkillRankSnapshot and ns.SkillRankSnapshot()) or {}
  local e = ns.CATALOG_BY_ID and ns.CATALOG_BY_ID[id]
  if not e then return nil end
  local s = snap[ns.Fold(e.name)]
  if not s then for _, a in ipairs(e.aliases or {}) do s = s or snap[ns.Fold(a)] end end
  return s and N(s.max) or nil
end

function Scanner.TooltipLine(tooltip)
  if not Scanner.Enabled() or InCombat() or type(tooltip) ~= "table" then return nil end
  -- 3.5.3 : nos propres infobulles (cases, barre, toasts) n'ont jamais de « Requiert »
  local okO, owner = false, nil
  if tooltip.GetOwner then okO, owner = pcall(tooltip.GetOwner, tooltip) end
  if okO and type(owner) == "table" and (owner._osrsOwn or owner._osrsTile or owner._dropOwn) then return nil end
  local tname = (tooltip.GetName and tooltip:GetName()) or "GameTooltip"
  local nLines = N(Call(tooltip.NumLines, tooltip)) or 0
  local title = Str(Call(function() local fs = _G[tname .. "TextLeft1"] return fs and fs:GetText() end))
  -- Ligne déjà ajoutée (info-bulle rafraîchie) : pas de doublon.
  for i = 2, nLines do
    local fs = _G[tname .. "TextLeft" .. i]
    local txt = fs and Str(Call(fs.GetText, fs))
    if txt and (txt:find(Tr[" : +1 possible"], 1, true) or txt:find(Tr[" requis (actuel "], 1, true)) then return nil end
  end
  for i = 1, nLines do
    local fs = _G[tname .. "TextLeft" .. i]
    local txt = fs and Str(Call(fs.GetText, fs))
    local id, req, label = Scanner.ParseRequirement(txt)
    if id and req then
      local rank, e = Scanner.RankOf(id)
      if not rank or rank <= 0 then return nil end
      local nm = e and ns.CatalogDisplayName(e) or label
      local line, r, g, b
      if rank >= req then
        line = nm .. Tr[" : +1 possible"]
        r, g, b = 0.85, 0.85, 0.85
        local node = title and Scanner.DB().nodes[title]
        if node and node.gainRank then line = line .. Tr[" · gain vu au rang "] .. tostring(node.gainRank) end
      else
        line = nm .. Tr[" : "] .. tostring(req) .. Tr[" requis (actuel "] .. tostring(rank) .. ")"
        r, g, b = 1, 0.3, 0.3
      end
      if title then
        local db = Scanner.DB()
        db.nodes[title] = db.nodes[title] or {}
        db.nodes[title].skill, db.nodes[title].req = id, req
        Scanner.lastNode = { name = title, skill = id, t = Call(GetTime) or 0 }
      end
      pcall(tooltip.AddLine, tooltip, line, r, g, b)
      pcall(tooltip.Show, tooltip)
      return line
    end
  end
  return nil
end

-- Gain observé juste après une récolte → mémorisé pour le nœud.
function Scanner.OnSkillUp(name, rank)
  local ln = Scanner.lastNode
  if not ln then return end
  local id = ns.Style and ns.Style.SkillIdForText(name)
  if id ~= ln.skill then return end
  if ((Call(GetTime) or 0) - (ln.t or 0)) > 30 then return end
  local db = Scanner.DB()
  db.nodes[ln.name] = db.nodes[ln.name] or {}
  db.nodes[ln.name].gainRank = rank
end

function Scanner.HookTooltip()
  if Scanner._ttHooked then return end
  local tt = _G.GameTooltip
  if type(tt) ~= "table" then return end
  Scanner._ttHooked = true
  if type(_G.TooltipDataProcessor) == "table" and type(_G.TooltipDataProcessor.AddTooltipPostCall) == "function"
    and _G.Enum and _G.Enum.TooltipDataType and _G.Enum.TooltipDataType.Object then
    pcall(_G.TooltipDataProcessor.AddTooltipPostCall, _G.Enum.TooltipDataType.Object, function(t)
      if t == tt then pcall(Scanner.TooltipLine, t) end
    end)
    Scanner.ttMode = "TooltipDataProcessor"
  end
  if tt.HookScript then
    pcall(tt.HookScript, tt, "OnShow", function(t) pcall(Scanner.TooltipLine, t) end)
    Scanner.ttMode = (Scanner.ttMode and (Scanner.ttMode .. " + ") or "") .. "OnShow"
  end
end

-- Événements -------------------------------------------------------------------
if ns.On then
  ns.On("PLAYER_LOGIN", function() Scanner.HookTooltip() end)
  ns.On("LOOT_OPENED", function() if Scanner.Enabled() then pcall(Scanner.OnLootOpened) end end)
  ns.On("CHAT_MSG_LOOT", function(_, msg) if Scanner.Enabled() then pcall(Scanner.OnChatLoot, msg) end end)
  ns.On("UNIT_SPELLCAST_SUCCEEDED", function(_, unit, _, spellID)
    if unit ~= "player" then return end
    local nm = Str(Call(_G.GetSpellInfo, spellID)) or (type(_G.C_Spell) == "table" and Str(Call(function() local i = _G.C_Spell.GetSpellInfo(spellID) return i and i.name end)))
    if nm and ns.Style and ns.Style.SkillIdForText(nm) == "skinning" then Scanner._skinCast = Call(GetTime) or 0 end
  end)
  ns.On("PLAYER_TARGET_CHANGED", function() pcall(Scanner.NoteUnit, "target") end)
  ns.On("UPDATE_MOUSEOVER_UNIT", function() pcall(Scanner.NoteUnit, "mouseover") end)
  ns.On("NAME_PLATE_UNIT_ADDED", function(_, unit) pcall(Scanner.OnPlateAdded, unit) end)
  ns.On("NAME_PLATE_UNIT_REMOVED", function(_, unit) pcall(Scanner.OnPlateRemoved, unit) end)
  ns.On("PLAYER_REGEN_DISABLED", function() Scanner.HideAll() end)
  ns.On("PLAYER_REGEN_ENABLED", function() pcall(Scanner.RescanPlates) end)
  -- v2.8.1 : TRADE_SKILL_UPDATE tombe à chaque fabrication → une lecture
  -- regroupée (0,3 s) au lieu d'une par événement.
  -- 3.5.0 : SHOW / UPDATE / LIST_UPDATE / OnShow passent par UN seul travail
  -- différé (ProfJob). L'ancien délai propre au scanner en faisait un de plus.
  local function readRecipes(ev)
    if ns.ProfJob and ns.ProfJob.Schedule then ns.ProfJob.Schedule(ev or "recipes") return end
    if InCombat() then Scanner._recipesPending = true return end
    local ok, id, n = pcall(Scanner.ReadRecipes)
    Scanner.lastRead = ok and (tostring(id) .. " : " .. tostring(n)) or tostring(id)
    Scanner.reads = (Scanner.reads or 0) + 1
  end
  ns.On("PLAYER_REGEN_ENABLED", function() if Scanner._recipesPending then Scanner._recipesPending = false readRecipes() end end)
  ns.On("TRADE_SKILL_SHOW", readRecipes)
  ns.On("TRADE_SKILL_UPDATE", readRecipes)
  ns.On("TRADE_SKILL_LIST_UPDATE", readRecipes)
  ns.On("TRADE_SKILL_DATA_SOURCE_CHANGED", readRecipes)
  -- 3.0.1 : la fenêtre du métier (chargée à la demande) relance aussi la
  -- lecture à l'affichage et à chaque mise à jour native (post-crochets, lecture seule).
  Scanner.ReadRecipesSoon = readRecipes
  function Scanner.HookTradeFrames()
    for _, nm in ipairs({ "TradeSkillFrame", "ProfessionsFrame" }) do
      local fr = _G[nm]
      if type(fr) == "table" and fr.HookScript and not Scanner["_hooked" .. nm] then
        if pcall(fr.HookScript, fr, "OnShow", readRecipes) then Scanner["_hooked" .. nm] = true end
      end
    end
    if type(hooksecurefunc) == "function" and type(_G.TradeSkillFrame_Update) == "function" and not Scanner._hookedTSUpdate then
      if pcall(hooksecurefunc, "TradeSkillFrame_Update", readRecipes) then Scanner._hookedTSUpdate = true end
    end
  end
  ns.On("ADDON_LOADED", function() pcall(Scanner.HookTradeFrames) end)
  ns.On("PLAYER_LOGIN", function() pcall(Scanner.HookTradeFrames) end)
  ns.On("TRADE_SKILL_SHOW", function() pcall(Scanner.HookTradeFrames) end)
  ns.On("CHAT_MSG_SKILL", function(_, msg)
    local name, rank
    if ns.UI and ns.UI.ParseSkillMessage then name, rank = ns.UI:ParseSkillMessage(msg) end
    if name then pcall(Scanner.OnSkillUp, name, rank) end
  end)
end

-- /drop scanner pourquoi : pourquoi la cible n'a pas (ou a) d'icône. ------------
local SKILL_FR = { cooking = "Cuisine", firstaid = "Secourisme", skinning = "Dépeçage" }
function Scanner.Why(unit)
  unit = unit or "target"
  local out = {}
  local function add(t) out[#out + 1] = t end
  if not Call(UnitExists, unit) and not Str(Call(UnitGUID, unit)) then add(Tr["aucune cible."]) return out, "pas de cible" end
  local id, pi = Scanner.UnitNpcID(unit)
  add(Tr["GUID brut : "] .. tostring(pi.raw) .. Tr[" · lecture : "] .. tostring(pi.path) .. Tr[" · résultat : "] .. tostring(pi.how))
  if not id then
    if pi.how and pi.how:find("rejeté", 1, true) then add(Tr["la cible n'est pas une créature ("] .. tostring(pi.kind or "joueur") .. Tr[") : pas d'icône."]) return out, "pas une créature" end
    add(Tr["créature non identifiée : GUID illisible et nom absent de la base Forever."])
    return out, "non identifiée"
  end
  local _, seen = Scanner.NoteUnit(unit)
  seen = seen or {}
  local alive = not Call(UnitIsDead, unit)
  add(string.format(Tr["cible : %s · PNJ %d · type %s · famille %s · %s"], tostring(seen.name or "?"), id,
    tostring(seen.ctype or "?"), tostring(seen.family or "?"), alive and Tr["vivante"] or Tr["morte"]))
  local verdict
  if not Scanner.Enabled() then verdict = Tr["scanner désactivé (/drop scanner on)."] end
  if not verdict and not ns.Opt("scannerIcons") then verdict = Tr["icônes désactivées (/drop scanner icones on)."] end
  if not verdict and InCombat() then verdict = Tr["en combat : icônes masquées jusqu'à la fin du combat."] end
  local plate = type(_G.C_NamePlate) == "table" and Call(_G.C_NamePlate.GetNamePlateForUnit, unit)
  add(Tr["barre de nom : "] .. (type(plate) == "table" and Tr["affichée"] or Tr["absente (active les barres de nom ennemies, V)"]))
  local c, how = Scanner.CreatureFor(id, { name = seen.name, family = seen.family, ctype = seen.ctype })
  if not c then
    add(Tr["base Forever : rien pour ce PNJ ; butin appris : aucun (ni créature du même nom et de la même famille)."])
    verdict = verdict or Tr["rien connu : loote-la une fois (viande / tissu) ou dépèce-la, l'icône apparaîtra ensuite."]
  else
    local parts = {}
    for k, v in pairs(c.skills or {}) do if v > 0 then parts[#parts + 1] = (SKILL_FR[k] and ns.SkillDisplayName(k) or k) .. " ×" .. v end end
    local ni = 0 for _ in pairs(c.items or {}) do ni = ni + 1 end
    add(string.format(Tr["source (%s) : %d objet(s) ; %s"], tostring(how), ni, #parts > 0 and table.concat(parts, ", ") or Tr["aucun objet de métier (viande, tissu, cuir)"]))
    if c.chance then
      local ch = {}
      for iid, pct in pairs(c.chance) do
        local it = Scanner.StaticItem(iid)
        ch[#ch + 1] = string.format("%s %.1f %%", tostring(it and ns.GameName(it.en, it.fr) or iid), pct)
      end
      table.sort(ch)
      if #ch > 0 then add(Tr["chances (Wowhead Forever) : "] .. table.concat(ch, ", ")) end
    end
    for skill in pairs(Scanner.LOOT_SKILLS) do
      for _, l in ipairs(ns.Craft and ns.Craft.WhyLines(c, skill, seen.name) or {}) do add(l) end
    end
    if (c.skills.skinning or 0) > 0 then
      if not Scanner.HasSkill("skinning") then add(Tr["Dépeçage : déjà dépecée, mais tu n'as pas la compétence."])
      elseif not alive then add(Tr["Dépeçage : icône seulement sur une bête vivante (barre de nom)."])
      else add(Tr["Dépeçage : déjà dépecée → icône Dépeçage (anneau bronze)."]) end
    end
  end
  local skill, diff = Scanner.BestFor(id, { name = seen.name, family = seen.family, ctype = seen.ctype, alive = alive })
  if not verdict then
    if skill then verdict = Tr["icône attendue : "] .. (SKILL_FR[skill] and ns.SkillDisplayName(skill) or skill) .. " (" .. Tr[DIFF_FR[diff]] .. ")."
    elseif c then verdict = Tr["pas d'icône : aucune recette utile (orange / jaune / vert) pour ce butin."] end
  end
  add(Tr["verdict : "] .. tostring(verdict))
  if Scanner.lastAssoc then add(Tr["dernier butin associé : "] .. Scanner.lastAssoc) end
  return out, verdict
end

-- Commandes -------------------------------------------------------------------
ns.SlashExt.scanner = function(rest)
  local sub, arg = (rest or ""):lower():match("^(%S*)%s*(%S*)")
  if sub == "toast" then
    ns.SetOpt("scannerToast", ns.ParseOnOff(arg, ns.OptOff("scannerToast")))
    ns.Print(Tr["scanner : toast "] .. (ns.OptOff("scannerToast") and Tr["activé."] or Tr["désactivé."]))
  elseif sub == "son" or sub == "sound" then
    ns.SetOpt("scannerSound", ns.ParseOnOff(arg, ns.OptOff("scannerSound")))
    ns.Print(Tr["scanner : son "] .. (ns.OptOff("scannerSound") and Tr["activé."] or Tr["désactivé."]))
  elseif sub == "icones" or sub == "icônes" or sub == "icons" then
    ns.SetOpt("scannerIcons", ns.ParseOnOff(arg, ns.Opt("scannerIcons")))
    ns.Print(Tr["scanner : icônes "] .. (ns.Opt("scannerIcons") and Tr["activées."] or Tr["désactivées."]))
    if not ns.Opt("scannerIcons") then Scanner.HideAll() end
  elseif sub == "pourquoi" or sub == "why" then
    local lines = Scanner.Why("target")
    ns.Print(Tr["scanner — pourquoi :"])
    for _, l in ipairs(lines) do ns.Print("  " .. l) end
  elseif sub == "reset" then
    local db = Scanner.DB()
    db.creatures, db.nodes = {}, {}
    Scanner.toasted = {}
    Scanner._viewCache, Scanner._learnVer = {}, (Scanner._learnVer or 0) + 1
    Scanner.HideAll()
    ns.Print(Tr["scanner : données apprises effacées."])
  else
    ns.SetOpt("scanner", ns.ParseOnOff(sub, ns.Opt("scanner")))
    if not ns.Opt("scanner") then Scanner.HideAll() else Scanner.RescanPlates() end
    ns.Print(Tr["scanner "] .. (ns.Opt("scanner") and Tr["activé."] or Tr["désactivé."]))
  end
end
ns.HelpExt[#ns.HelpExt + 1] = "/drop scanner on|off : icône discrète au-dessus des créatures utiles (butin appris + recettes connues)"
ns.HelpExt[#ns.HelpExt + 1] = "/drop scanner toast on|off · son on|off · icones on|off · pourquoi · reset"

ns.DebugExt[#ns.DebugExt + 1] = function()
  local db = Scanner.DB()
  local out = { "— Scanner discret (v2.8.0) —" }
  local sdb = ns.ScannerDB
  if sdb and sdb.meta then
    out[#out + 1] = string.format("  base : %s (%s) ; objets %s, PNJ butin %s, PNJ dépeçables %s, recettes %s",
      tostring(sdb.meta.source), tostring(sdb.meta.date), tostring(sdb.meta.nItems), tostring(sdb.meta.nDropNpcs), tostring(sdb.meta.nSkinNpcs), tostring(sdb.meta.nRecipes))
  else
    out[#out + 1] = "  base : absente (apprentissage seul)"
  end
  local nc, ns_ = 0, { cooking = 0, firstaid = 0, skinning = 0 }
  for _, c in pairs(db.creatures) do
    nc = nc + 1
    for k, v in pairs(c.skills or {}) do if v > 0 then ns_[k] = (ns_[k] or 0) + 1 end end
  end
  out[#out + 1] = string.format("  actif : %s ; icônes %s ; toast %s ; son %s", tostring(ns.Opt("scanner")), tostring(ns.Opt("scannerIcons")), tostring(ns.OptOff("scannerToast")), tostring(ns.OptOff("scannerSound")))
  out[#out + 1] = string.format("  créatures apprises : %d (Cuisine %d, Secourisme %d, Dépeçage %d) ; nœuds : %d", nc, ns_.cooking, ns_.firstaid, ns_.skinning, (function() local n = 0 for _ in pairs(db.nodes) do n = n + 1 end return n end)())
  local rec = ns.CharDB().recipes or {}
  for id, r in pairs(rec) do out[#out + 1] = string.format("  recettes %s : %d (%s)", id, #(r.list or {}), tostring(r.source)) end
  out[#out + 1] = "  dernière lecture : " .. tostring(Scanner.lastRead or "aucune (lecture automatique à l'ouverture d'un métier)")
  out[#out + 1] = "  API : GetTradeSkillInfo " .. tostring(type(_G.GetTradeSkillInfo) == "function") .. ", C_TradeSkillUI " .. tostring(type(_G.C_TradeSkillUI) == "table") .. ", GetCraftInfo " .. tostring(type(_G.GetCraftInfo) == "function") .. ", C_NamePlate " .. tostring(type(_G.C_NamePlate) == "table") .. ", GetLootSourceInfo " .. tostring(type(_G.GetLootSourceInfo) == "function")
  out[#out + 1] = "  info-bulle : " .. tostring(Scanner.ttMode or "non accrochée") .. " ; combat : " .. tostring(InCombat())
  local lc = Scanner.lastCorpse
  for _, u in ipairs({ "target", "mouseover" }) do
    if Call(UnitExists, u) then
      local id, pi = Scanner.UnitNpcID(u)
      out[#out + 1] = "  GUID " .. u .. " : " .. tostring(pi.raw) .. " → " .. tostring(id or "?") .. " (" .. tostring(pi.path) .. " ; " .. tostring(pi.how) .. ")"
    end
  end
  local nn = 0 for _ in pairs(Scanner.NpcNameIndex()) do nn = nn + 1 end
  out[#out + 1] = "  repli par nom : " .. nn .. " noms indexés (base Forever FR/EN + appris)"
  out[#out + 1] = "  dernier corps : " .. (lc and (tostring(Scanner.NpcID(lc.guid)) .. " via " .. tostring(lc.src)) or "aucun") .. " ; dernier butin : " .. tostring(Scanner.lastAssoc or "aucun")
  out[#out + 1] = "  correspondance : base Forever par npcID d'abord, puis appris (npcID, sinon nom + famille) ; dépeçage : 2e ouverture du corps ou sort récent"
  return out
end
