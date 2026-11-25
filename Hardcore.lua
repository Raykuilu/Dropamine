-- Dropamine 3.10.0
--   * Paliers du niveau total annoncés en guilde (coupé par défaut).
--   * Maîtres d'armes des capitales : où apprendre une arme qui manque (/drop armes, rappel d'arme non apprise).
--   * Onglet Hardcore (pour le mode Hardcore à venir sur Forever) : liseré « danger » sur la cible.
--     Rien ne s'active hors d'un personnage Hardcore (ns.IsHardcore ; /drop hc simu pour tester).
local ADDON, ns = ...
local Tr = ns.L
local Unpack = _G.unpack or table.unpack
local H = {}
ns.Hardcore = H

local function N(v) return ns.N(v) end
local function Call(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a, b, c, d, e, f, g, h, i, j, k = pcall(fn, ...)
  if not ok then return nil end
  return ns.Unsecret(a, b, c, d, e, f, g, h, i, j, k)
end
local function Str(v) if type(v) ~= "string" or v == "" or (ns.IsSecret and ns.IsSecret(v)) then return nil end return v end
local function After(sec, fn) if _G.C_Timer and _G.C_Timer.After then _G.C_Timer.After(sec, fn) return true end fn() return false end

-- Réglages ---------------------------------------------------------------------
local function CharDB() local ok, c = pcall(ns.CharDB) return ok and type(c) == "table" and c or nil end
local function Hello(force)
  local db = CharDB()
  if db and (force or not db.hcHello) then
    db.hcHello = true
    ns.Print(Tr["Hardcore détecté : le liseré danger sur la cible est actif (Réglages > Avancé > Hardcore)."])
  end
end
-- Hardcore volontaire : par personnage
function H.SetManual(on)
  local db = CharDB()
  if not db then return end
  local was = db.hcManual == true
  db.hcManual = on and true or nil
  if on and not was then Hello(true) end
  local T = ns.Target
  if T and T.Refresh then pcall(T.Refresh, "hc") end
end
H.OPTIONS = {
  { type = "check", key = "hcManual", label = "Je joue en Hardcore (mode non officiel)", default = false, cmd = "/drop hc on|off",
    help = "Pour ce personnage seulement : active les aides Hardcore sans le mode officiel du jeu.", home = "advanced",
    get = function() return ns.HardcoreManual() end, set = function(v) H.SetManual(v) end },
  { type = "check", key = "guildMilestones", label = "Annoncer les paliers en guilde", default = false, cmd = "Réglage de ce panneau",
    help = "Message dans le canal de guilde quand ton niveau total franchit un palier (500, 1000…).", home = "progress" },
  { type = "check", key = "hcDanger", label = "Liseré danger sur la cible", default = true, cmd = "Réglage de ce panneau",
    help = "Personnage Hardcore : le liseré des cases passe au rouge vif si la cible est élite, de niveau ?? ou a 3 niveaux de plus que toi.", home = "advanced" },
}
local O = ns.Options
if O then
  O.EXTRA_HOME = O.EXTRA_HOME or {}
  for _, it in ipairs(H.OPTIONS) do O.EXTRA[#O.EXTRA + 1] = it O.EXTRA_HOME[it.key] = it.home end
  if O.GROUPS then
    if O.GROUPS.grpAnnounce then
      local items = O.GROUPS.grpAnnounce.items
      items[#items + 1] = { "guildMilestones", "Paliers du total en guilde" }
    end
    O.GROUPS.grpHardcore = { label = "Hardcore", help = "Actif seulement sur un personnage Hardcore (mode à venir sur Forever).",
      items = { { "hcManual", "Je joue en Hardcore (mode non officiel)" }, { "hcDanger", "Liseré danger sur la cible" } } }
  end
  if O.MAP and O.MAP.advanced then table.insert(O.MAP.advanced, 1, { "Hardcore", { "grpHardcore" } }) end
  if O.TEST then
    O.TEST.guildMilestones, O.TEST.hcDanger = "guildpreview", "danger"
    O.TEST.grpHardcore = "group"
  end
  O.TEST_FN = O.TEST_FN or {}
end

-- 1. Maîtres d'armes des capitales -------------------------------------------------
-- À défaut d'un maître déjà vu en jeu (QoL.weaponMasters).
H.TRAINERS = {
  Alliance = {
    { npc = "Woo Ping", zone = "Hurlevent", weapons = { "swords", "swords2h", "polearms", "staves", "crossbows" } },
    { npc = "Bixi Wobblebonk", zone = "Forgefer", weapons = { "daggers", "crossbows", "thrown" } },
    { npc = "Buliwyf Stonehand", zone = "Forgefer", weapons = { "axes", "axes2h", "maces", "maces2h", "guns", "fist" } },
    { npc = "Ilyenia Moonfire", zone = "Darnassus", weapons = { "bows", "daggers", "fist", "staves", "thrown" } },
  },
  Horde = {
    { npc = "Sayoc", zone = "Orgrimmar", weapons = { "axes", "axes2h", "bows", "daggers", "fist", "thrown" } },
    { npc = "Hanashi", zone = "Orgrimmar", weapons = { "axes", "axes2h", "bows", "staves", "thrown" } },
    { npc = "Ansekhwa", zone = "Pitons-du-Tonnerre", weapons = { "guns", "maces", "maces2h", "staves" } },
    { npc = "Archibald", zone = "Fossoyeuse", weapons = { "crossbows", "daggers", "swords", "swords2h", "polearms" } },
  },
}
-- Armes qu'une classe peut apprendre chez un maître d'armes (baguettes : maître de classe).
H.CLASS_WEAPONS = {
  WARRIOR = { "axes", "axes2h", "maces", "maces2h", "swords", "swords2h", "polearms", "staves", "fist", "daggers", "bows", "guns", "crossbows", "thrown" },
  PALADIN = { "axes", "axes2h", "maces", "maces2h", "swords", "swords2h", "polearms" },
  HUNTER = { "axes", "axes2h", "swords", "swords2h", "polearms", "staves", "fist", "daggers", "bows", "guns", "crossbows", "thrown" },
  ROGUE = { "daggers", "swords", "maces", "fist", "bows", "guns", "crossbows", "thrown" },
  PRIEST = { "maces", "staves", "daggers" },
  SHAMAN = { "axes", "axes2h", "maces", "maces2h", "staves", "fist", "daggers" },
  MAGE = { "swords", "staves", "daggers" },
  WARLOCK = { "swords", "staves", "daggers" },
  DRUID = { "maces", "maces2h", "staves", "fist", "daggers" },
}
local ZONE_EN = { ["Hurlevent"] = "Stormwind", ["Forgefer"] = "Ironforge", ["Pitons-du-Tonnerre"] = "Thunder Bluff", ["Fossoyeuse"] = "Undercity" }
local function ZoneName(z) if ns.IsFrench and not ns.IsFrench() then return ZONE_EN[z] or z end return z end
local function Faction() return Str(Call(_G.UnitFactionGroup, "player")) end
-- maîtres qui enseignent cette arme : { npc, zone } (vu en jeu d'abord)
function H.MastersFor(id, faction)
  local out = {}
  local Q = ns.QoL
  local seen = Q and Q.Global and Q.Global().weaponMasters and Q.Global().weaponMasters[id]
  if seen and seen.npc then out[#out + 1] = { npc = seen.npc, zone = seen.zone } end
  for _, m in ipairs(H.TRAINERS[faction or Faction() or ""] or {}) do
    for _, w in ipairs(m.weapons) do
      if w == id and not (seen and seen.npc == m.npc) then out[#out + 1] = { npc = m.npc, zone = ZoneName(m.zone) } end
    end
  end
  return out
end
-- premier maître connu des capitales (sans ceux vus en jeu)
function H.StaticMaster(id)
  for _, m in ipairs(H.TRAINERS[Faction() or ""] or {}) do
    for _, w in ipairs(m.weapons) do if w == id then return { npc = m.npc, zone = ZoneName(m.zone) } end end
  end
  return nil
end
-- armes apprenables par la classe mais pas encore apprises
function H.MissingWeapons()
  local _, cls = Call(_G.UnitClass, "player")
  local list = H.CLASS_WEAPONS[cls or ""]
  if not list then return {} end
  local Q = ns.QoL
  local snap = (ns.SkillRankSnapshotCached and ns.SkillRankSnapshotCached()) or (ns.SkillRankSnapshot and ns.SkillRankSnapshot()) or {}
  local out = {}
  for _, id in ipairs(list) do
    local e = ns.CatalogById and ns.CatalogById(id)
    if e then
      local v = Q and Q.SnapEntry and Q.SnapEntry(snap, e)
      if not (v and (N(v.rank) or 0) > 0) then out[#out + 1] = { id = id, name = (ns.CatalogDisplayName and ns.CatalogDisplayName(e)) or e.name } end
    end
  end
  return out
end
function H.MissingLines()
  local out = {}
  for _, w in ipairs(H.MissingWeapons()) do
    local parts = {}
    for _, m in ipairs(H.MastersFor(w.id)) do parts[#parts + 1] = m.npc .. " (" .. tostring(m.zone or "?") .. ")" end
    if #parts > 0 then out[#out + 1] = string.format(Tr["  %s : %s"], tostring(w.name), table.concat(parts, ", ")) end
  end
  return out
end
do
  local base = ns.SlashExt and ns.SlashExt.armes
  if base then
    ns.SlashExt.armes = function(...)
      base(...)
      local lines = H.MissingLines()
      if #lines > 0 then
        ns.Print(Tr["Armes pas encore apprises (maître d'armes) :"])
        for _, l in ipairs(lines) do ns.Print(l) end
      end
    end
    ns.SlashExt.weapons = ns.SlashExt.armes
  end
end

-- 2. Liseré danger (Hardcore) ----------------------------------------------------------
H.DANGER = { 1, 0.12, 0.08 }
local ELITE = { elite = true, rareelite = true, worldboss = true }
-- raison du danger (texte) ou nil
function H.DangerOf(tg)
  if not (tg and (ns.IsHardcore() or H._simDanger) and ns.Opt("hcDanger")) then return nil end
  if tg.dead or not (tg.attackable or tg.enemy) then return nil end
  local pl = N(tg.playerLevel) or N(Call(_G.UnitLevel, "player")) or 1
  local tl = N(tg.level)
  if not tl or tl <= 0 then return Tr["niveau ??"] end
  if tg.classif and ELITE[tg.classif] then return Tr["élite"] end
  if tl >= pl + 3 then return string.format(Tr["+%d niveaux"], tl - pl) end
  return nil
end
if ns.Compact and ns.Compact.TooltipModel then
  local baseModel = ns.Compact.TooltipModel
  function ns.Compact.TooltipModel(d)
    local m = baseModel(d)
    local T = ns.Target
    local why = T and T.target and H.DangerOf(T.target)
    if why and m and m.lines and m.target then
      m.lines[#m.lines + 1] = { Tr["Danger (Hardcore) : "] .. why, H.DANGER[1], H.DANGER[2], H.DANGER[3], true }
    end
    return m
  end
end
-- Test : 6 s de liseré danger sur la cible actuelle (ou rien sans cible)
function H.TestDanger()
  H._simDanger = true
  local T = ns.Target
  if T and T.Refresh then pcall(T.Refresh, "test") end
  ns.Print(Tr["Test : liseré danger pendant 6 s (prends une cible attaquable, élite ou de niveau +3)."])
  After(6, function() H._simDanger = nil if T and T.Refresh then pcall(T.Refresh, "test") end end)
  return true
end

-- 3. Paliers du total en guilde (coupé par défaut) ---------------------------
function H.GuildText(m, total, tmax)
  return string.format(Tr["[Dropamine] Niveau total %d atteint (%d / %d) !"], m, N(total) or m, N(tmax) or 0)
end
do
  local P = ns.Progress
  if P and P.TotalDing then
    local base = P.TotalDing
    function P.TotalDing(prev, cur, ...)
      local p = P.C and P.C()
      local before = {}
      if p and type(p.dinged) == "table" then for k in pairs(p.dinged) do before[k] = true end end
      local r = { base(prev, cur, ...) }
      if ns.OptOff("guildMilestones") and p and type(p.dinged) == "table" then
        local hit
        for k in pairs(p.dinged) do if not before[k] and k > (N(prev) or 0) and (not hit or k > hit) then hit = k end end
        if hit and Call(_G.IsInGuild) and type(_G.SendChatMessage) == "function" then
          local snap = ns.UI and ns.UI.snapshot
          pcall(_G.SendChatMessage, H.GuildText(hit, cur, snap and snap.totalMax or ns.TOTAL_MAX), "GUILD")
        end
      end
      return Unpack(r)
    end
  end
end

-- Tests (boutons « Tester » des réglages) --------------------------------------------------------
if O and O.TEST_FN then
  O.TEST_FN.danger = H.TestDanger
  O.TEST_FN.guildpreview = function()
    local snap = ns.UI and ns.UI.snapshot
    ns.Print(Tr["Aperçu (rien n'est envoyé) : "] .. H.GuildText(1000, 1000, snap and snap.totalMax or ns.TOTAL_MAX))
    return true
  end
end

-- /drop hc : état ; /drop hc simu : simule un personnage Hardcore (tests sur un royaume normal)
ns.SlashExt = ns.SlashExt or {}
ns.SlashExt.hc = function(rest)
  local low = tostring(rest or ""):lower()
  if low:find("simu") then
    ns._forceHC = not ns._forceHC
    ns.Print(ns._forceHC and Tr["Hardcore simulé : actif jusqu'au /reload."] or Tr["Hardcore simulé : coupé."])
    local T = ns.Target
    if T and T.Refresh then pcall(T.Refresh, "hc") end
    return
  end
  local word = low:match("^%s*(%a+)")
  if word == "on" or word == "off" then
    H.SetManual(word == "on")
    if O and O.Sync then pcall(O.Sync) end
    ns.Print(word == "on" and Tr["Hardcore manuel : activé pour ce personnage."] or Tr["Hardcore manuel : coupé pour ce personnage."])
    return
  end
  local state = ns.HardcoreOfficial() and Tr["officiel"] or (ns.HardcoreManual() and Tr["manuel"]) or Tr["non"]
  ns.Print(Tr["Hardcore : "] .. state .. Tr[" (/drop hc on|off, simu pour tester)"])
end
ns.HelpExt = ns.HelpExt or {}
ns.HelpExt[#ns.HelpExt + 1] = "/drop hc : mode Hardcore (on|off : Hardcore manuel, simu : simuler)"

if ns.On then
  ns.On("PLAYER_LOGIN", function()
    if ns.IsHardcore() then Hello(false) end
  end)
end
