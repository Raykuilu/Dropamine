-- Dropamine 3.8.0 — commandes de contrôle et de partage (texte seulement).
--   /drop check    : diagnostic de l'addon (fenêtre copiable)
--   /drop resume   : résumé du total sur une ligne, prêt à coller (Ctrl+C)
--   /drop paliers  : prochain palier du total et compétences au plafond
--   /drop records  : meilleurs scores et rythme de l'heure en cours
--   /drop collection : ce que le scanner a appris (créatures, nœuds, recettes)
-- Aucune écriture dans les données, aucun événement, aucun nouveau cadre :
-- tout passe par pcall et par la fenêtre de texte existante (DebugWindow).
local ADDON, ns = ...
local Tr = ns.L or setmetatable({}, { __index = function(_, k) return k end })

local function N(v) return (ns.N and ns.N(v)) or tonumber(v) or 0 end
local function Safe(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a, b, c = pcall(fn, ...)
  if ok then return a, b, c end
  return nil
end

local function Snap()
  local ui = ns.UI
  local s = ui and ui.snapshot
  if type(s) ~= "table" and ns.Collect then
    local ok, r = pcall(ns.Collect)
    s = ok and r or nil
  end
  return type(s) == "table" and s or nil
end

local function Out(lines, summary)
  local DW = ns.DebugWindow
  if DW and DW.Show then
    local ok = pcall(DW.Show, lines)
    if ok then
      if summary and ns.Print then ns.Print(summary) end
      return
    end
  end
  if ns.Print then for _, l in ipairs(lines) do ns.Print(l) end end
end

-- Paliers du total : fixes, puis le maximum de la classe affiché par l'addon.
local MILESTONES = { 500, 1000, 1500, 2000, 2250 }

local function Milestones(total, tmax)
  local passed, nextM = {}, nil
  local list = {}
  for _, m in ipairs(MILESTONES) do if m < tmax then list[#list + 1] = m end end
  list[#list + 1] = tmax
  for _, m in ipairs(list) do
    if total >= m then passed[#passed + 1] = m
    elseif not nextM then nextM = m end
  end
  return passed, nextM
end

ns.Milestones = Milestones -- réutilisé par la Vue d'ensemble

local function CappedSkills(snap)
  local capped, count = 0, 0
  for _, t in ipairs(snap.tiles or {}) do
    if t.inTotal and t.kind ~= "level" then
      local cap = N(t.apiMax)
      if cap > 0 then
        count = count + 1
        if N(t.current) >= cap then capped = capped + 1 end
      end
    end
  end
  return capped, count
end

ns.SlashExt = ns.SlashExt or {}

-- /drop paliers
local function slashMilestones()
  local s = Snap()
  if not s then
    if ns.Print then ns.Print(Tr["Aucune donnée de total disponible pour l'instant."]) end
    return
  end
  local total, tmax = N(s.total or s.ficTotal), N(s.totalMax or s.ficMax or ns.TOTAL_MAX)
  local passed, nextM = Milestones(total, tmax)
  local capped, count = CappedSkills(s)
  local lines = {
    Tr["Niveau total : "] .. total .. " / " .. tmax,
    nextM and (Tr["Prochain palier : "] .. nextM .. " (+" .. (nextM - total) .. ")") or Tr["Tous les paliers sont atteints."],
    Tr["Paliers atteints : "] .. ((#passed > 0) and table.concat(passed, ", ") or "—"),
    Tr["Compétences au plafond : "] .. capped .. " / " .. count,
  }
  Out(lines)
end

-- /drop resume : une ligne pour Discord, puis le détail
local function slashSummary()
  local s = Snap()
  if not s then
    if ns.Print then ns.Print(Tr["Aucune donnée de total disponible pour l'instant."]) end
    return
  end
  local total, tmax = N(s.total or s.ficTotal), N(s.totalMax or s.ficMax or ns.TOTAL_MAX)
  local parts = {}
  for _, b in ipairs(s.breakdown or {}) do
    if b and b.name then parts[#parts + 1] = tostring(b.name) .. " " .. N(b.value) end
  end
  local who = tostring(s.playerName or "?")
  local lvl = N(s.level)
  local line = who .. " (" .. Tr["niv. "] .. lvl .. ") — " .. Tr["Niveau total "] .. total .. "/" .. tmax
  if #parts > 0 then line = line .. " — " .. table.concat(parts, " · ") end
  Out({ line }, Tr["Résumé copié dans la fenêtre (Ctrl+C pour copier, Échap pour fermer)."])
end

-- /drop check
local MODULES = { "UI", "Slot", "Progress", "ProgressUI", "Compact", "Wide", "Scanner", "Efficiency",
  "Rested", "Options", "Window", "Notif", "RankToast", "Activity", "Gather", "Target", "DebugWindow" }

-- 3.9.0 : le contrôle rend ses lignes (réutilisées par /drop bug)
local function CheckLines()
  local lines, bad = {}, 0
  local function add(ok, label, extra)
    if not ok then bad = bad + 1 end
    lines[#lines + 1] = (ok and "OK   " or "ERREUR ") .. label .. (extra and (" : " .. tostring(extra)) or "")
  end
  local function info(label, extra) lines[#lines + 1] = "     " .. label .. " : " .. tostring(extra) end

  local getMeta = (_G.C_AddOns and _G.C_AddOns.GetAddOnMetadata) or _G.GetAddOnMetadata
  info("version", Safe(getMeta, ADDON, "Version") or "?")
  add(ns.DEV_TEST ~= true, "build public (DEV_TEST désactivé)")

  local missing = {}
  for _, m in ipairs(MODULES) do if type(ns[m]) ~= "table" then missing[#missing + 1] = m end end
  add(#missing == 0, "modules chargés", (#missing > 0) and ("manquants : " .. table.concat(missing, ", ")) or (#MODULES .. "/" .. #MODULES))

  add(type(ns.IsSecret) == "function" and type(ns.Unsecret) == "function", "protection des valeurs secrètes")

  local t0 = _G.debugprofilestop and _G.debugprofilestop() or nil
  local okC, snap = pcall(ns.Collect or function() return nil end)
  local ms = (t0 and _G.debugprofilestop) and string.format("%.1f ms", _G.debugprofilestop() - t0) or nil
  add(okC and type(snap) == "table", "collecte du total", (okC and type(snap) == "table") and (N(snap.total) .. " / " .. N(snap.totalMax) .. (ms and (", " .. ms) or "")) or tostring(snap))

  local S = ns.Slot
  local okA, act = pcall(S and S.Active or function() return nil end)
  add(okA, "état de l'icône (Slot.Active)", okA and tostring(act) or tostring(act))

  local P = ns.Progress
  local q = Safe(P and P.Quiet)
  if type(q) == "table" then
    info("mode calme", "actif=" .. tostring(q.active) .. " raison=" .. tostring(q.why) .. " réglage=" .. tostring(q.mode))
  end

  local okI, inInst, kind = pcall(_G.IsInInstance or function() return nil end)
  if okI and not (ns.IsSecret and ns.IsSecret(inInst)) then
    info("instance", tostring(inInst) .. " " .. ((ns.IsSecret and ns.IsSecret(kind)) and "?" or tostring(kind)))
  end
  info("pause vol", tostring(Safe(ns.PausedForFlight) and true or false))

  local rows = Safe(ns.MemBreakdown)
  if type(rows) == "table" and rows[1] and rows[1].bytes then
    info("données sauvegardées", string.format("%.0f Ko", N(rows[1].bytes) / 1024))
  end

  local ok, sev = pcall(_G.GetCVar, "scriptErrors")
  if ok and sev ~= "1" then
    lines[#lines + 1] = "     conseil : /console scriptErrors 1 pour voir les erreurs Lua"
  end

  lines[#lines + 1] = " "
  lines[#lines + 1] = (bad == 0) and "Résultat : tout est OK." or ("Résultat : " .. bad .. " problème(s).")
  return lines, bad
end
local function slashCheck()
  local lines, bad = CheckLines()
  Out(lines, (bad == 0) and Tr["Contrôle : tout est OK."] or (Tr["Contrôle : problèmes détectés : "] .. bad))
end

ns.SlashExt.check = slashCheck

-- /drop bug (3.9.0) : rapport complet à copier dans une issue GitHub
-- (version, jeu, langue, thème, contrôle, dernières erreurs gardées, addons chargés). Rien n'est envoyé.
ns.BUG_URL = "https://github.com/Raykuilu/Dropamine/issues/new?template=bug_report.yml"
function ns.BugReportLines()
  local L = {}
  local getMeta = (_G.C_AddOns and _G.C_AddOns.GetAddOnMetadata) or _G.GetAddOnMetadata
  L[#L + 1] = "Dropamine " .. tostring(Safe(getMeta, ADDON, "Version") or "?") .. " — rapport de bug"
  L[#L + 1] = "Copie tout (Ctrl+C) et colle-le dans : " .. ns.BUG_URL
  L[#L + 1] = " "
  local okB, ver, build, date, iface = pcall(_G.GetBuildInfo or function() return nil end)
  if okB then L[#L + 1] = "jeu : " .. tostring(ver) .. " (" .. tostring(build) .. ", " .. tostring(date) .. ", interface " .. tostring(iface) .. ")" end
  L[#L + 1] = "client : " .. tostring(Safe(_G.GetLocale) or "?") .. " ; langue de l'addon : " .. tostring(ns.LangCode and ns.LangCode() or "?")
  L[#L + 1] = "thème : " .. tostring(ns.Theme and ns.Theme.Choice and Safe(ns.Theme.Choice) or "?")
  L[#L + 1] = " "
  L[#L + 1] = "— Contrôle —"
  local okC, lines = pcall(CheckLines)
  if okC then for _, l in ipairs(lines) do L[#L + 1] = l end else L[#L + 1] = "contrôle impossible : " .. tostring(lines) end
  L[#L + 1] = " "
  L[#L + 1] = "— Erreurs gardées par l'addon —"
  local n = 0
  for label, err in pairs((ns.UI and ns.UI.errors) or {}) do n = n + 1 L[#L + 1] = "  " .. tostring(label) .. " : " .. tostring(err) end
  local SO = ns.SafeOpen
  if SO and SO.lastError then n = n + 1 L[#L + 1] = "  ouverture : " .. tostring(SO.lastError) end
  if n == 0 then L[#L + 1] = "  aucune" end
  L[#L + 1] = " "
  L[#L + 1] = "— Addons chargés —"
  local A = _G.C_AddOns
  local num = Safe((A and A.GetNumAddOns) or _G.GetNumAddOns) or 0
  local names = {}
  for i = 1, num do
    local nm = Safe((A and A.GetAddOnInfo) or _G.GetAddOnInfo, i)
    local loaded = Safe((A and A.IsAddOnLoaded) or _G.IsAddOnLoaded, i)
    if nm and loaded then names[#names + 1] = tostring(nm) end
  end
  table.sort(names)
  L[#L + 1] = "  " .. ((#names > 0) and table.concat(names, ", ") or "?")
  return L
end
ns.SlashExt.bug = function() Out(ns.BugReportLines(), Tr["Rapport de bug prêt : Ctrl+C pour copier, puis colle-le sur GitHub (lien en tête du rapport)."]) end
ns.HelpExt = ns.HelpExt or {}
ns.HelpExt[#ns.HelpExt + 1] = "/drop bug : rapport complet à copier pour signaler un bug sur GitHub"
ns.SlashExt.paliers = slashMilestones
ns.SlashExt.resume = slashSummary
ns.SlashExt["résumé"] = slashSummary

-- /drop records : meilleurs scores, avec le rythme de l'heure en cours comparé au meilleur.
local function slashRecords()
  local P = ns.Progress
  local R = Safe(P and P.Records)
  if type(R) ~= "table" then
    if ns.Print then ns.Print(Tr["Aucune donnée de total disponible pour l'instant."]) end
    return
  end
  local hour = N(Safe(P.HourPoints))
  local function vs(cur, best)
    if best <= 0 then return "" end
    return string.format(" (%d%%)", math.floor(cur / best * 100 + 0.5))
  end
  local best30 = 0
  if P and P.DayOffset and P.DayPoints and P.Today then
    local today = P.Today()
    for i = 0, 29 do
      local day = P.DayOffset(today, -i)
      if day then best30 = math.max(best30, N(Safe(P.DayPoints, day))) end
    end
  end
  local lines = {
    Tr["Meilleur jour (30 derniers jours) : +"] .. best30 .. " pts",
    Tr["Meilleure session : +"] .. N(R.bestSession) .. " pts",
    Tr["Meilleure heure : +"] .. N(R.bestHour) .. " pts · " .. Tr["heure en cours : +"] .. hour .. vs(hour, N(R.bestHour)),
    Tr["Meilleur jour : +"] .. N(R.bestDay) .. " pts" .. (R.bestDayKey and (" · " .. tostring(R.bestDayKey)) or ""),
    Tr["Plus long combo : "] .. N(R.longestCombo),
    Tr["Objectifs atteints : "] .. N(R.goalsHit) .. " · " .. Tr["sessions : "] .. N(R.sessions),
  }
  Out(lines)
end

-- /drop collection : ce que le scanner a appris (X, et X / Y quand la base le permet).
local function slashCollection()
  local Sc = ns.Scanner
  local db = Sc and Safe(Sc.DB)
  if type(db) ~= "table" then
    if ns.Print then ns.Print(Tr["Le scanner n'a encore rien appris."]) end
    return
  end
  local sdb = ns.ScannerDB
  local meta = sdb and sdb.meta or {}
  local function xy(x, y)
    y = tonumber(y)
    return (y and y > 0) and (x .. " / " .. y) or tostring(x)
  end
  local nc, skin, nodes, bySkill = 0, 0, 0, {}
  for _, c in pairs(db.creatures or {}) do
    nc = nc + 1
    if type(c.skills) == "table" and (N(c.skills.skinning) > 0) then skin = skin + 1 end
  end
  for _, nd in pairs(db.nodes or {}) do
    nodes = nodes + 1
    local k = type(nd) == "table" and nd.skill or "?"
    bySkill[k] = (bySkill[k] or 0) + 1
  end
  local lines = {
    Tr["Créatures apprises : "] .. xy(nc, meta.nDropNpcs),
    Tr["Dépeçables apprises : "] .. xy(skin, meta.nSkinNpcs),
    Tr["Nœuds appris : "] .. nodes,
  }
  local keys = {}
  for k in pairs(bySkill) do keys[#keys + 1] = k end
  table.sort(keys)
  for _, k in ipairs(keys) do lines[#lines + 1] = "   " .. tostring(k) .. " : " .. bySkill[k] end
  local totals = {}
  if sdb and type(sdb.recipes) == "table" then
    for _, raw in pairs(sdb.recipes) do
      local code = tostring(raw):match("^([^|]*)")
      if code then totals[code] = (totals[code] or 0) + 1 end
    end
  end
  local cdb = ns.CharDB and Safe(ns.CharDB)
  local names = { cooking = { "Cuisine", "c" }, firstaid = { "Secourisme", "f" } }
  local rec = cdb and cdb.recipes
  if type(rec) == "table" then
    for id, r in pairs(rec) do
      local n = type(r) == "table" and r.list and #r.list or 0
      local nm = names[id]
      lines[#lines + 1] = Tr["Recettes "] .. ((nm and nm[1]) or tostring(id)) .. " : " .. xy(n, nm and totals[nm[2]])
    end
  end
  Out(lines)
end

ns.HelpExt = ns.HelpExt or {}
ns.HelpExt[#ns.HelpExt + 1] = "/drop check · resume · paliers · records · collection (sans on|off : relevé ; avec on|off : interrupteur)"
-- « /drop records on|off » et « /drop collection on|off » existent déjà (Dopamine.lua : interrupteurs).
-- Avec on / off on garde ce comportement ; sans argument, on affiche le relevé.
local function WithToggle(prev, show)
  return function(rest)
    local w = tostring(rest or ""):lower():match("^%s*(%S+)")
    if w and (w == "on" or w == "off" or w == "1" or w == "0" or w == "oui" or w == "non") and prev then return prev(rest) end
    return show(rest)
  end
end
ns.SlashExt.records = WithToggle(ns.SlashExt.records, slashRecords)
ns.SlashExt.collection = WithToggle(ns.SlashExt.collection, slashCollection)
