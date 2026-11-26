-- Dropamine 3.11.0 : export pour les Hiscores de dropamine.app.
-- « /drop hiscores » ouvre la fenêtre de copie avec une ligne à coller sur le site :
-- les compétences d'armes (absentes de l'armurerie Blizzard), la Défense, le niveau,
-- les métiers et la guilde. Le site recoupe niveau, métiers et Défense avec l'armurerie.
-- 3.11.1 : en plus, tout ce que l'armurerie n'a pas, groupe par groupe, chacun avec sa case à cocher
-- (décoché = absent de la ligne = absent du site) : /played, collection log, succès, records, chasse.
-- Le JcJ n'est pas exporté : le site prend celui de l'armurerie (non falsifiable).
-- Rien n'est envoyé par l'addon : le joueur copie et colle lui-même.
local ADDON, ns = ...
local Tr = ns.L

local HS = {}
ns.Hiscores = HS
HS.PREFIX = "DROPAMINE-HS1:"

local function N(v) return ns.N and ns.N(v) or tonumber(v) end
local function Call(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a, b, c, d = pcall(fn, ...)
  if not ok then return nil end
  if ns.Unsecret then return ns.Unsecret(a, b, c, d) end
  return a, b, c, d
end
-- champs : rien d'autre que lettres, chiffres, espace, tiret et apostrophe (pas de séparateur)
local function clean(s) return (tostring(s or ""):gsub("[|;:,=~%.%c]", " "):gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")) end
HS.clean = clean
local function int(v) return math.max(0, math.floor(N(v) or 0)) end
-- entier en base 36 (0-9, a-z) : des identifiants d'objets plus courts dans la ligne
function HS.B36(n)
  n = math.floor(N(n) or 0)
  if n <= 0 then return "0" end
  local d, o = "0123456789abcdefghijklmnopqrstuvwxyz", ""
  while n > 0 do local r = n % 36 o = d:sub(r + 1, r + 1) .. o n = (n - r) / 36 end
  return o
end

-- somme de contrôle simple (détecte une ligne tronquée ou modifiée à la main, ce n'est pas une signature)
function HS.Checksum(s)
  local h = 5381
  for i = 1, #s do h = (h * 33 + s:byte(i)) % 4294967296 end
  return string.format("%08x", h)
end

local REGION = { [1] = "us", [2] = "kr", [3] = "eu", [4] = "tw", [5] = "cn" }

-- 3.11.1 : temps de jeu (/played). Le jeu ne le donne qu'en réponse à /played (TIME_PLAYED_MSG) :
-- on garde la dernière réponse (par personnage) et on ajoute le temps écoulé depuis.
local function Now() return N(Call(_G.time)) or 0 end
local function Played()
  local c = ns.CharDB and ns.CharDB()
  local p = type(c) == "table" and c.played
  if type(p) ~= "table" or not N(p.t) then return nil end
  return N(p.t) + math.max(0, Now() - (N(p.at) or Now()))
end
HS.Played = Played
function HS.FormatPlayed(sec)
  sec = math.floor(N(sec) or 0)
  local d, h, m = math.floor(sec / 86400), math.floor(sec % 86400 / 3600), math.floor(sec % 3600 / 60)
  if d > 0 then return string.format(Tr["%d j %d h"], d, h) end
  return string.format(Tr["%d h %d min"], h, m)
end
if ns.On then
  ns.On("TIME_PLAYED_MSG", function(_, total)
    local c = ns.CharDB and ns.CharDB()
    if type(c) == "table" and N(total) then c.played = { t = N(total), at = Now() } end
    -- la fenêtre attendait la réponse : on la met à jour si elle est encore ouverte
    local f = ns.DebugWindow and ns.DebugWindow.frame
    if HS.waiting then HS.waiting = nil if f and f.IsShown and f:IsShown() then HS.Open() end end
  end)
end

-- 3.11.1 : les groupes de données en plus. key = réglage (coché par défaut), get() = champ(s) de la ligne ou nil.
local function Log()
  local H = ns.Hunt
  if not (H and H.LogSections) then return nil end
  local ok, secs = pcall(H.LogSections)
  if not ok or type(secs) ~= "table" then return nil end
  local parts, x, y = {}, 0, 0
  for _, s in ipairs(secs) do
    for _, e in ipairs(s.entries or {}) do
      if e.bosses and type(e.key) == "string" then   -- donjons et raids (pas les lignes de statistiques)
        x, y = x + int(e.x), y + int(e.y)
        if int(e.x) > 0 then parts[#parts + 1] = clean(e.key:gsub("^dj:", "")) .. "~" .. int(e.x) .. "~" .. int(e.y) end
      end
    end
  end
  if y == 0 then return nil end
  -- 3.11.1 : la liste des objets obtenus (en base 36, séparés par des points) : le site les affiche en icônes
  local ids = {}
  if H.OwnedIds then
    local ok, list = pcall(H.OwnedIds)
    if ok and type(list) == "table" then for i, id in ipairs(list) do if i > 3000 then break end ids[#ids + 1] = HS.B36(id) end end
  end
  local f = { "ct=" .. x .. "~" .. y, "cl=" .. table.concat(parts, ",") }
  if #ids > 0 then f[#f + 1] = "ci=" .. table.concat(ids, ".") end
  return f, string.format("%d / %d", x, y)
end
local function Ach()
  local P = ns.Progress
  if not (P and P.Achievements) then return nil end
  local ok, list = pcall(P.Achievements)
  if not ok or type(list) ~= "table" or #list == 0 then return nil end
  local ids, n = {}, 0
  for _, a in ipairs(list) do
    if a.unlocked then n = n + 1 ids[#ids + 1] = clean(a.id) end
  end
  return { "ac=" .. n .. "~" .. #list .. "~" .. table.concat(ids, ".") }, string.format("%d / %d", n, #list)
end
local function Rec()
  local P = ns.Progress
  if not (P and P.Records) then return nil end
  local ok, R = pcall(P.Records)
  if not ok or type(R) ~= "table" then return nil end
  local v = { R.bestSession, R.bestHour, R.bestDay, R.longestCombo, R.sessions, R.goalsHit, R.playtime }
  for i = 1, 7 do v[i] = int(v[i]) end
  return { "rc=" .. table.concat(v, "~") }, string.format(Tr["session %d · heure %d · jour %d"], v[1], v[2], v[3])
end
local function Hunt()
  local H = ns.Hunt
  if not (H and H.List) or (H.On and not H.On()) then return nil end
  local ok, list = pcall(H.List)
  if not ok or type(list) ~= "table" or #list == 0 then return nil end
  local parts = {}
  for i, it in ipairs(list) do
    if i > 20 then break end
    -- 3.12.0 : codes seuls (numéro~essais~drops) : le site affiche le nom officiel dans la langue du visiteur,
    -- et aucun nom traduit (russe, allemand…) ne passe par le copier-coller
    parts[#parts + 1] = int(it.id) .. "~" .. int(it.attempts) .. "~" .. int(it.drops)
  end
  return { "hu=" .. table.concat(parts, ",") }, tostring(#parts)
end
HS.GROUPS = {
  { key = "hsPlayed", label = "Temps de jeu (/played)", get = function()
      local tp = Played()
      if not tp then return nil end
      return { "tp=" .. math.floor(tp) }, HS.FormatPlayed(tp)
    end },
  { key = "hsLog", label = "Collection log", get = Log },
  { key = "hsAch", label = "Succès", get = Ach },
  { key = "hsRec", label = "Records", get = Rec },
  { key = "hsHunt", label = "Chasse", get = Hunt },
}
local function Want(key)
  local ui = ns.db and ns.db.ui
  return not (ui and ui[key] == false)   -- coché par défaut
end
HS.Want = Want

-- Construit la ligne. Renvoie texte, détails (pour l'affichage), ou nil + raison.
function HS.Build()
  local profs, weapons, defense = {}, {}, nil
  if ns.SkillsForCharSheet then
    local ok, p, w, d = pcall(ns.SkillsForCharSheet)
    if ok then profs, weapons, defense = p or {}, w or {}, d end
  end
  if #weapons == 0 and not defense then return nil, Tr["Compétences pas encore lues : ouvre le panneau (/drop) puis réessaie."] end
  local name = clean(Call(_G.UnitName, "player"))
  local level = N(Call(_G.UnitLevel, "player")) or 0
  local guild = clean(Call(_G.GetGuildInfo, "player"))
  local region = REGION[N(Call(_G.GetCurrentRegion)) or 0] or ""
  local wlist, wsum = {}, 0
  for _, w in ipairs(weapons) do
    local r = N(w.rank) or 0
    wsum = wsum + r
    wlist[#wlist + 1] = string.format("%s=%d", tostring(w.id or clean(w.name)), r)
  end
  local plist = {}
  for _, p in ipairs(profs) do plist[#plist + 1] = string.format("%s=%d", tostring(p.id or clean(p.name)), N(p.rank) or 0) end
  local fields = {
    "n=" .. name, "l=" .. level, "r=" .. region, "g=" .. guild,
    "d=" .. (N(defense and defense.rank) or 0), "ws=" .. wsum,
    "w=" .. table.concat(wlist, ","), "p=" .. table.concat(plist, ","),
    "v=" .. tostring(ns.VERSION or ""), "t=" .. tostring(N(Call(_G.time)) or 0),
  }
  -- 3.11.1 : groupes cochés seulement
  local extra = {}
  for _, gp in ipairs(HS.GROUPS) do
    if Want(gp.key) then
      local ok, f, summary = pcall(gp.get)
      if ok and type(f) == "table" then
        for _, x in ipairs(f) do fields[#fields + 1] = x end
        extra[#extra + 1] = { label = gp.label, summary = summary, key = gp.key }
      end
    end
  end
  local body = table.concat(fields, ";")
  local line = HS.PREFIX .. body .. ";c=" .. HS.Checksum(body)
  local tp = Want("hsPlayed") and Played() or nil
  return line, { played = tp, extra = extra, name = name, level = level, guild = guild, weapons = wsum, defense = N(defense and defense.rank) or 0, count = #weapons }
end

function HS.Open()
  local line, info = HS.Build()
  if not line then if ns.Print then ns.Print(info) end return nil end
  local DW = ns.DebugWindow
  local lines = {
    line, " ",
    string.format(Tr["%s · niveau %d · armes %d (%d) · Défense %d%s"], info.name, info.level, info.weapons, info.count, info.defense,
      info.guild ~= "" and (" · " .. info.guild) or ""),
  }
  for _, x in ipairs(info.extra) do
    lines[#lines + 1] = Tr["Inclus : "] .. Tr[x.label] .. (x.summary and (" · " .. tostring(x.summary)) or "")
  end
  lines[#lines + 1] = Tr["Copie la première ligne (Ctrl+C) et colle-la sur dropamine.app, page Inscription."]
  -- /played pas encore connu : on le demande (réponse habituelle dans le chat), la fenêtre se met à jour
  if Want("hsPlayed") and not Played() and type(_G.RequestTimePlayed) == "function" then
    HS.waiting = true
    pcall(_G.RequestTimePlayed)
    lines[#lines + 1] = Tr["Temps de jeu demandé au serveur…"]
  end
  local checks = {}
  for _, gp in ipairs(HS.GROUPS) do
    checks[#checks + 1] = {
      label = Tr[gp.label], value = Want(gp.key),
      onToggle = function(on)
        local ui = ns.db and ns.db.ui
        if ui then ui[gp.key] = on and true or false end
        HS.Open()
      end,
    }
  end
  if DW and DW.Show then DW.Show(lines, { title = Tr["Hiscores : ta ligne d'export (Ctrl+C pour copier)"], checks = checks }) end
  HS.MarkExported()
  return line
end

-- 3.11.1 : rappel discret (une fois par jour, au plus) quand le carnet a de nouveaux objets depuis le dernier export :
-- sans ligne à jour, le site ne peut pas te mettre en relation avec ceux qui ont besoin des mêmes donjons
local function Owned() local H = ns.Hunt return (H and H.OwnedIds and #H.OwnedIds()) or 0 end
function HS.MarkExported(now)
  local c = ns.CharDB and ns.CharDB()
  if c then c.hsExport = { at = now or ((type(time) == "function" and time()) or 0), owned = Owned() } end
end
function HS.CheckReminder(today)
  local c = ns.CharDB and ns.CharDB()
  if not (c and c.hsExport) then return nil end           -- jamais exporté : pas de rappel (la visite et le site s'en chargent)
  today = today or ((type(date) == "function" and date("%Y%m%d")) or "")
  if c.hsNagDay == today then return nil end
  local new = Owned() - (tonumber(c.hsExport.owned) or 0)
  if new <= 0 then return nil end
  c.hsNagDay = today
  local msg = string.format(Tr["%d nouvel(s) objet(s) dans ton carnet depuis ton dernier export : /drop hiscores, puis colle la ligne sur dropamine.app pour que ceux qui font les mêmes donjons te trouvent."], new)
  if ns.Print then ns.Print(msg) end
  return msg
end
if ns.On and _G.C_Timer and _G.C_Timer.After then
  ns.On("PLAYER_LOGIN", function() _G.C_Timer.After(90, function() pcall(HS.CheckReminder) end) end)
end

ns.SlashExt = ns.SlashExt or {}
ns.SlashExt.hiscores = function() HS.Open() end
ns.SlashExt.scores = ns.SlashExt.hiscores
ns.HelpExt = ns.HelpExt or {}
ns.HelpExt[#ns.HelpExt + 1] = "/drop hiscores : ligne d'export pour les classements de dropamine.app"
