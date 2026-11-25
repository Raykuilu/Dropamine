-- Dropamine 3.10.0 : maîtres d'armes des capitales.
-- Où apprendre une arme qui manque : ajouté à /drop armes (/drop weapons) et au rappel « arme non apprise »
-- (QoL.CheckUnlearnedWeapon), à défaut d'un maître déjà vu en jeu.
local ADDON, ns = ...
local Tr = ns.L
local WM = {}
ns.WeaponMasters = WM

local function N(v) return ns.N(v) end
local function Call(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a, b, c, d, e, f, g, h, i, j, k = pcall(fn, ...)
  if not ok then return nil end
  return ns.Unsecret(a, b, c, d, e, f, g, h, i, j, k)
end
local function Str(v) if type(v) ~= "string" or v == "" or (ns.IsSecret and ns.IsSecret(v)) then return nil end return v end

WM.TRAINERS = {
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
WM.CLASS_WEAPONS = {
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
function WM.MastersFor(id, faction)
  local out = {}
  local Q = ns.QoL
  local seen = Q and Q.Global and Q.Global().weaponMasters and Q.Global().weaponMasters[id]
  if seen and seen.npc then out[#out + 1] = { npc = seen.npc, zone = seen.zone } end
  for _, m in ipairs(WM.TRAINERS[faction or Faction() or ""] or {}) do
    for _, w in ipairs(m.weapons) do
      if w == id and not (seen and seen.npc == m.npc) then out[#out + 1] = { npc = m.npc, zone = ZoneName(m.zone) } end
    end
  end
  return out
end
-- premier maître connu des capitales (sans ceux vus en jeu)
function WM.StaticMaster(id)
  for _, m in ipairs(WM.TRAINERS[Faction() or ""] or {}) do
    for _, w in ipairs(m.weapons) do if w == id then return { npc = m.npc, zone = ZoneName(m.zone) } end end
  end
  return nil
end
-- armes apprenables par la classe mais pas encore apprises
function WM.MissingWeapons()
  local _, cls = Call(_G.UnitClass, "player")
  local list = WM.CLASS_WEAPONS[cls or ""]
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
function WM.MissingLines()
  local out = {}
  for _, w in ipairs(WM.MissingWeapons()) do
    local parts = {}
    for _, m in ipairs(WM.MastersFor(w.id)) do parts[#parts + 1] = m.npc .. " (" .. tostring(m.zone or "?") .. ")" end
    if #parts > 0 then out[#out + 1] = string.format(Tr["  %s : %s"], tostring(w.name), table.concat(parts, ", ")) end
  end
  return out
end
do
  local base = ns.SlashExt and ns.SlashExt.armes
  if base then
    ns.SlashExt.armes = function(...)
      base(...)
      local lines = WM.MissingLines()
      if #lines > 0 then
        ns.Print(Tr["Armes pas encore apprises (maître d'armes) :"])
        for _, l in ipairs(lines) do ns.Print(l) end
      end
    end
    ns.SlashExt.weapons = ns.SlashExt.armes
  end
end
