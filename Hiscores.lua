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
HS.PREFIX = "DROP:HS2:"          -- 3.13.0 : famille « DROP:<type><version>: » (le site lit aussi l'ancien DROPAMINE-HS1:)

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
    if HS.app and HS.app:IsShown() and HS.RefreshApp then pcall(HS.RefreshApp) end
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
    -- 3.13.0 : objets propres à Forever (numéros ≥ 250000) : l'API Blizzard ne les traduit pas ; le nom vu par le jeu,
    -- dans la langue du client (champ lc), permet au site de l'afficher en français aux visiteurs francophones
    local nm = (int(it.id) >= 250000) and clean(it.name) or ""
    if nm ~= "" then parts[#parts + 1] = int(it.id) .. "~" .. nm .. "~" .. int(it.attempts) .. "~" .. int(it.drops)
    else parts[#parts + 1] = int(it.id) .. "~" .. int(it.attempts) .. "~" .. int(it.drops) end
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
  -- 3.12.2 : JcJ de la semaine (honneur par victoire sur dropamine.app) : ce que l'armurerie ne donne pas
  { key = "hsPvp", label = "JcJ", get = function()
      local PV = ns.PvP
      if not (PV and PV.Week) then return nil end
      local okW, w = pcall(PV.Week)
      if not okW or type(w) ~= "table" then return nil end
      local S = PV.st or {}
      local hkW, honW = N(S.hkWeek) or w.hk, N(S.honorWeek) or w.honor   -- l'API d'abord si elle répond
      local v = { hkW, honW, N(S.honor) or 0, N(S.dkLife) or 0, N(S.highest) or 0, N(S.hkToday) or 0, N(S.honorToday) or 0 }
      for i = 1, 7 do v[i] = int(v[i]) end
      return { "pv=" .. table.concat(v, "~") }, string.format(Tr["%d victoires honorables, %d d'honneur cette semaine"], v[1], v[2])
    end },
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
    "v=" .. tostring(ns.VERSION or ""), "t=" .. tostring(N(Call(_G.time)) or 0), "lc=" .. tostring(Call(_G.GetLocale) or ""),
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
  local msg = string.format(Tr["%d nouvel(s) objet(s) dans ton carnet depuis ton dernier envoi : /drop app, puis colle la ligne sur dropamine.app pour que ceux qui font les mêmes donjons te trouvent."], new)
  if ns.Print then ns.Print(msg) end
  return msg
end
if ns.On and _G.C_Timer and _G.C_Timer.After then
  ns.On("PLAYER_LOGIN", function() _G.C_Timer.After(90, function() pcall(HS.CheckReminder) end) end)
end


------------------------------------------------------------------------------
-- 3.13.0 : guichet unique avec dropamine.app (/drop app) — Envoyer au site (ta ligne, prête à copier) et
-- Recevoir du site (une case où coller n'importe quel code du site : chasse, sorties). Codes « DROP:<type><version>: » ;
-- les anciens (DROP-CH1, DROP-RUN1) restent lus. Le copier-coller est le seul canal : l'addon ne parle pas au site.
------------------------------------------------------------------------------
HS.APP_NAME = "DropamineAppWindow"
local function Plural(n, one, many) return string.format(Tr[(n == 1) and one or many], n) end
-- un code du site → ce qui a été fait (texte), ou nil si rien n'est reconnu
function HS.ApplyCode(text)
  text = tostring(text or "")
  local H = ns.Hunt
  local r = { added = 0, dup = 0, full = false, run = 0, runDup = 0, seen = false }
  local function doCh(ids)
    if not (H and H.ImportCode) then return end
    local a, d, f = H.ImportCode("DROP-CH1:" .. ids)
    if a then r.seen = true r.added = r.added + a r.dup = r.dup + (d or 0) r.full = r.full or f end
  end
  local function doRun(entry)
    if not (H and H.AddOuting) then return end
    local o, why = H.AddOuting("DROP-RUN1:" .. entry)
    if o then r.seen = true if why == "dup" then r.runDup = r.runDup + 1 else r.run = r.run + 1 end end
  end
  local sync = text:match("DROP:SYNC1:(%S+)")
  if sync then
    for part in sync:gmatch("[^;]+") do
      local k, v = part:match("^(%w+)=(.*)$")
      if k == "ch" then doCh(v)
      elseif k == "run" then for e in v:gmatch("[^|]+") do doRun(e) end end
    end
  else
    local ch = text:match("DROP[%-:]CH1:([%w%.]+)")
    if ch then doCh(ch) end
    for e in text:gmatch("DROP[%-:]RUN1:([^%s|;]+)") do doRun(e) end
  end
  if not r.seen then return nil end
  local parts = {}
  if r.added > 0 then parts[#parts + 1] = Plural(r.added, "%d objet ajouté à la chasse", "%d objets ajoutés à la chasse") end
  if r.dup > 0 then parts[#parts + 1] = Plural(r.dup, "%d déjà suivi", "%d déjà suivis") end
  if r.full then parts[#parts + 1] = Tr["liste de chasse pleine"] end
  if r.run > 0 then parts[#parts + 1] = Plural(r.run, "%d sortie notée (rappel 15 min avant)", "%d sorties notées (rappel 15 min avant)") end
  if r.runDup > 0 then parts[#parts + 1] = Plural(r.runDup, "%d sortie déjà notée", "%d sorties déjà notées") end
  if #parts == 0 then parts[1] = Tr["rien de nouveau"] end
  local PU = ns.ProgressUI
  if PU and PU.RequestRefresh then pcall(PU.RequestRefresh) end
  return "dropamine.app : " .. table.concat(parts, " · ")
end
-- collé dans le chat (/drop DROP:SYNC1:…) : même lecteur, résultat dans le chat
function HS.ApplyFromChat(text)
  local msg = HS.ApplyCode(text)
  if ns.Print then ns.Print(msg or Tr["Code non reconnu : copie-le à nouveau sur dropamine.app (Moi › Synchroniser avec le jeu)."]) end
  return msg
end

local function Ago(at)
  at = N(at)
  if not at or at <= 0 then return Tr["jamais envoyé"] end
  local now = (type(time) == "function" and time()) or at
  local d = math.floor((now - at) / 86400)
  if d <= 0 then return Tr["dernier envoi : aujourd'hui"] end
  if d == 1 then return Tr["dernier envoi : hier"] end
  return string.format(Tr["dernier envoi : il y a %d jours"], d)
end

function HS.BuildApp()
  if HS.app then return HS.app end
  local okF, f = pcall(CreateFrame, "Frame", HS.APP_NAME, _G.UIParent, "PortraitFrameTemplate")
  if not (okF and f) then
    okF, f = pcall(CreateFrame, "Frame", HS.APP_NAME, _G.UIParent, "BackdropTemplate")
    if not (okF and f) then return nil end
    if f.SetBackdrop then pcall(f.SetBackdrop, f, { bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 } }) end
    local okC, c = pcall(CreateFrame, "Button", nil, f, "UIPanelCloseButton")
    if okC and c then c:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6) end
  else
    if f.SetTitle then pcall(f.SetTitle, f, "Dropamine.app") end
    local DW = ns.DebugWindow
    if DW and DW.DecoratePortrait then pcall(DW.DecoratePortrait, f) end
  end
  f:SetSize(560, 340)
  f:SetPoint("CENTER", _G.UIParent, "CENTER", 0, 60)
  f:SetFrameStrata("DIALOG")
  -- 3.13.0 : au premier plan comme le Dungeon Journal : un clic ou l'ouverture la remet devant
  f:SetToplevel(true) f:Raise() f:HookScript("OnShow", function(self) self:Raise() end)
  f:SetMovable(true) f:EnableMouse(true) f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving) f:SetScript("OnDragStop", f.StopMovingOrSizing)
  if type(_G.UISpecialFrames) == "table" then table.insert(_G.UISpecialFrames, HS.APP_NAME) end
  local function Label(text, y, font)
    local fs = f:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
    fs:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -y) fs:SetWidth(520) fs:SetJustifyH("LEFT")
    if fs.SetWordWrap then pcall(fs.SetWordWrap, fs, true) end
    fs:SetText(text or "")
    return fs
  end
  local function Box(y)
    local okE, eb = pcall(CreateFrame, "EditBox", nil, f, "InputBoxTemplate")
    if not (okE and eb) then eb = CreateFrame("EditBox", nil, f) end
    eb:SetSize(512, 22) eb:SetPoint("TOPLEFT", f, "TOPLEFT", 26, -y)
    if eb.SetAutoFocus then eb:SetAutoFocus(false) end
    if eb.SetMaxLetters then eb:SetMaxLetters(0) end
    if eb.SetFontObject then pcall(eb.SetFontObject, eb, _G.GameFontHighlightSmall or "GameFontHighlightSmall") end
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return eb
  end
  -- 1) Envoyer au site
  f.sendT = Label(Tr["Envoyer au site"], 64, "GameFontNormalLarge")
  f.send = Box(90)
  f.send:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
  f.send:SetScript("OnTextChanged", function(self, user) if user and f.line then self:SetText(f.line) self:HighlightText() end end)
  f.sendHow = Label(Tr["Ctrl+C, puis colle-la sur dropamine.app › Moi › Synchroniser avec le jeu."], 118, "GameFontHighlightSmall")
  f.sendInfo = Label("", 136, "GameFontDisableSmall")
  local okO, opts = pcall(CreateFrame, "Button", nil, f, "UIPanelButtonTemplate")
  if okO and opts then
    opts:SetSize(120, 22) opts:SetPoint("TOPRIGHT", f, "TOPRIGHT", -20, -128)
    opts:SetText(Tr["Ce qui est inclus…"])
    opts:SetScript("OnClick", function() HS.Open() end)
    f.opts = opts
  end
  -- 2) Recevoir du site
  f.recvT = Label(Tr["Recevoir du site"], 176, "GameFontNormalLarge")
  f.recv = Box(202)
  f.recv:SetWidth(420)
  f.recvHint = f.recv:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  f.recvHint:SetPoint("LEFT", f.recv, "LEFT", 4, 0) f.recvHint:SetPoint("RIGHT", f.recv, "RIGHT", -4, 0)
  f.recvHint:SetJustifyH("LEFT")
  f.recvHint:SetText(Tr["Colle ici le code copié sur dropamine.app (Ctrl+V), puis Entrée."])
  local function hint() local e = (f.recv:GetText() or "") == "" local fo = f.recv.HasFocus and f.recv:HasFocus() if e and not fo then f.recvHint:Show() else f.recvHint:Hide() end end
  f.recv:SetScript("OnEditFocusGained", hint) f.recv:SetScript("OnEditFocusLost", hint) f.recv:HookScript("OnTextChanged", hint)
  local function apply()
    local msg = HS.ApplyCode(f.recv:GetText())
    f.recvMsg:SetText(msg or Tr["Code non reconnu : copie-le à nouveau sur dropamine.app (Moi › Synchroniser avec le jeu)."])
    if msg then f.recv:SetText("") f.recv:ClearFocus() end
  end
  f.recv:SetScript("OnEnterPressed", apply)
  local okA, ap = pcall(CreateFrame, "Button", nil, f, "UIPanelButtonTemplate")
  if okA and ap then ap:SetSize(84, 22) ap:SetPoint("LEFT", f.recv, "RIGHT", 8, 0) ap:SetText(Tr["Appliquer"]) ap:SetScript("OnClick", apply) f.apply = ap end
  f.recvHow = Label(Tr["Sur dropamine.app : Moi › Synchroniser avec le jeu › Copier pour le jeu (ta chasse et tes sorties en un code)."], 230, "GameFontHighlightSmall")
  f.recvMsg = Label("", 262, "GameFontGreenSmall")
  -- SetScript remplace le HookScript posé plus haut : le Raise (devant le Dungeon Journal) est refait ici
  f:SetScript("OnShow", function(self) if self.Raise then self:Raise() end HS.RefreshApp() end)
  f:Hide()
  HS.app = f
  return f
end
function HS.RefreshApp()
  local f = HS.app
  if not f then return end
  local line, info = HS.Build()
  if line then
    f.line = line
    f.send:SetText(line) f.send:SetCursorPosition(0)
    f.send:SetFocus() f.send:HighlightText()
    HS.MarkExported()
  else
    f.line = nil
    f.send:SetText("")
  end
  local c = ns.CharDB and ns.CharDB()
  local incl = {}
  for _, x in ipairs((type(info) == "table" and info.extra) or {}) do incl[#incl + 1] = Tr[x.label] end
  f.sendInfo:SetText(line and (Ago(c and c.hsExport and c.hsExport.at) .. ((#incl > 0) and (" · " .. Tr["Inclus : "] .. table.concat(incl, ", ")) or ""))
    or tostring(info or ""))
end
function HS.OpenApp(focusRecv)
  local f = HS.BuildApp()
  if not f then return HS.Open() end
  if f:IsShown() and not focusRecv then f:Hide() return end
  f:Show()
  if focusRecv and f.recv then f.recv:SetFocus() end
end

ns.SlashExt = ns.SlashExt or {}
-- 3.13.0 : /drop hiscores ouvre le guichet Dropamine.app (le détail « Ce qui est inclus… » y reste accessible)
ns.SlashExt.hiscores = function() HS.OpenApp() end
ns.SlashExt.app = function() HS.OpenApp() end
ns.SlashExt.site = ns.SlashExt.app
ns.SlashExt.scores = ns.SlashExt.hiscores
ns.HelpExt = ns.HelpExt or {}
ns.HelpExt[#ns.HelpExt + 1] = "/drop app : échanges avec dropamine.app (envoyer ta ligne, recevoir chasse et sorties)"
