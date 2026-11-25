-- Dropamine 3.10.0 : onglet Hardcore (mode Hardcore à venir sur Forever, ou Hardcore manuel par personnage).
--   Liseré « danger » sur la cible. Rien ne s'active hors d'un personnage Hardcore (ns.IsHardcore ; /drop hc simu pour tester).
local ADDON, ns = ...
local Tr = ns.L

local H = {}
ns.Hardcore = H

local function N(v) return ns.N(v) end
local function Call(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a, b, c, d, e, f, g, h, i, j, k = pcall(fn, ...)
  if not ok then return nil end
  return ns.Unsecret(a, b, c, d, e, f, g, h, i, j, k)
end
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
  { type = "check", key = "hcDanger", label = "Liseré danger sur la cible", default = true, cmd = "Réglage de ce panneau",
    help = "Personnage Hardcore : le liseré des cases passe au rouge vif si la cible est élite, de niveau ?? ou a 3 niveaux de plus que toi.", home = "advanced" },
}
local O = ns.Options
if O then
  O.EXTRA_HOME = O.EXTRA_HOME or {}
  for _, it in ipairs(H.OPTIONS) do O.EXTRA[#O.EXTRA + 1] = it O.EXTRA_HOME[it.key] = it.home end
  if O.GROUPS then
    O.GROUPS.grpHardcore = { label = "Hardcore", help = "Actif seulement sur un personnage Hardcore (mode à venir sur Forever).",
      items = { { "hcManual", "Je joue en Hardcore (mode non officiel)" }, { "hcDanger", "Liseré danger sur la cible" } } }
  end
  if O.MAP and O.MAP.advanced then table.insert(O.MAP.advanced, 1, { "Hardcore", { "grpHardcore" } }) end
  if O.TEST then
    O.TEST.hcDanger = "danger"
    O.TEST.grpHardcore = "group"
  end
  O.TEST_FN = O.TEST_FN or {}
end

-- Liseré danger ----------------------------------------------------------
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

-- Tests (boutons « Tester » des réglages) --------------------------------------------------------
if O and O.TEST_FN then
  O.TEST_FN.danger = H.TestDanger
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
