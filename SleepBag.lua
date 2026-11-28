-- Dropamine 3.14.0 : le sac de couchage (objet de vendeur de Forever, « Sac de couchage douillet ») : bonus d'XP partagé
-- avec le groupe. /drop sac crée une macro à glisser dans la barre : un clic pose le sac, l'annonce en /dire
-- (une ligne sobre : « /w <toi> inv », mention discrète de Dropamine en fin de message) et, pendant 5 minutes,
-- invite qui te chuchote « inv » (ou « invite », « 123 »).
--  * L'annonce passe par /drop sac annonce dans la macro : c'est un clic (le jeu l'exige pour /dire hors instance).
--  * Rien n'est annoncé si le sac n'a pas été posé à l'instant (recharge, combat, objet absent).
--  * Invitations : seulement si tu es seul ou chef, groupe pas plein (5), une fois par joueur, jamais en raid.
--  * Créer la macro : hors combat seulement (règle du jeu).
local _, ns = ...
local Tr = ns.L

local SB = { WINDOW = 300, ANNOUNCE_GAP = 60, PENDING = 120, MACRO = "Sac Dropamine",   -- nom français ; la macro prend le nom traduit (Tr) et retrouve l'ancien
  WORDS = { inv = true, invite = true, ["123"] = true } }
ns.SleepBag = SB
SB.state = { until_ = 0, lastAnnounce = -1e9, invited = {}, queue = {} }

local function Call(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a, b, c = pcall(fn, ...)
  if not ok then return nil end
  if ns.Unsecret then return ns.Unsecret(a, b, c) end
  return a, b, c
end
local function now() return Call(_G.GetTime) or 0 end
-- fenêtre d'invitation : heure réelle (time()), gardée dans DropamineDB, donc elle survit à un /reload
local function epoch() return Call(_G.time) or 0 end
function SB.OpenWindow() if ns.db then ns.db.sleepBagWin = epoch() end SB.state.until_ = now() + SB.WINDOW end
function SB.IsOpen()
  if now() <= SB.state.until_ then return true end
  local at = ns.db and ns.db.sleepBagWin
  return type(at) == "number" and epoch() - at >= 0 and epoch() - at < SB.WINDOW
end
local function lower(s) return (string.lower(tostring(s or ""))) end

-- noms de l'objet dans les langues des clients (recherche dans les sacs : l'identifiant est ensuite gardé)
SB.NAMES = { "sac de couchage", "couchage", "sleeping bag", "bedroll", "bed roll", "schlafsack", "saco de dormir", "sacco a pelo", "спальн" }
function SB.IsBagName(name)
  local n = lower(name)
  if n == "" then return false end
  for _, k in ipairs(SB.NAMES) do if string.find(n, k, 1, true) then return true end end
  return false
end
-- Sur Forever, un objet ajouté par le serveur peut avoir un nom interne différent de celui de l'infobulle :
-- on regarde le nom de GetItemInfo, celui du lien de l'objet (tel qu'affiché) et le nom du sort « Utiliser ».
local function linkName(link) return type(link) == "string" and link:match("|h%[(.-)%]|h") or nil end
function SB.Names(bag, slot, id)
  local C = _G.C_Container
  local getLink = (C and C.GetContainerItemLink) or _G.GetContainerItemLink
  return Call(_G.GetItemInfo, id), linkName(Call(getLink, bag, slot)), Call(_G.GetItemSpell, id)
end
function SB.Each(fn)
  local C = _G.C_Container
  local getN = (C and C.GetContainerNumSlots) or _G.GetContainerNumSlots
  local getId = (C and C.GetContainerItemID) or _G.GetContainerItemID
  if type(getN) ~= "function" or type(getId) ~= "function" then return nil end
  for bag = 0, 4 do
    for slot = 1, (Call(getN, bag) or 0) do
      local id = Call(getId, bag, slot)
      if id then local r = fn(bag, slot, id) if r then return r end end
    end
  end
  return nil
end
function SB.FindItem()
  return SB.Each(function(bag, slot, id)
    local a, b, s = SB.Names(bag, slot, id)
    if SB.IsBagName(a) or SB.IsBagName(b) or SB.IsBagName(s) then return id end
  end)
end
-- /drop sac debug : les objets utilisables des sacs (identifiant, nom interne, nom affiché, sort), pour comprendre un « pas trouvé »
function SB.Debug()
  local n = 0
  SB.Each(function(bag, slot, id)
    local a, b, s = SB.Names(bag, slot, id)
    if s or SB.IsBagName(a) or SB.IsBagName(b) then
      n = n + 1
      ns.Print(string.format("%d · %s · %s · %s%s", id, tostring(a), tostring(b), tostring(s), (SB.IsBagName(a) or SB.IsBagName(b) or SB.IsBagName(s)) and "  <= sac" or ""))
    end
  end)
  ns.Print(n == 0 and "sac debug : aucun objet utilisable dans les sacs" or ("sac debug : " .. n .. " objet(s) utilisable(s)"))
end
local function knownId()
  local db = ns.db
  local id = SB.FindItem()
  if id and db then db.sleepBagItem = id end
  return id or (db and db.sleepBagItem)
end

function SB.MacroBody(id)
  -- l'identifiant marche dans toutes les langues ; sans lui (sac pas encore vu), le nom français, seul connu.
  -- [@player] : le sac se pose à tes pieds sans cercle de placement, donc l'annonce part dans le même clic
  -- (le jeu n'autorise /dire que pendant un clic : impossible d'annoncer après un clic au sol).
  return (id and ("/use [@player] item:" .. id) or "/use [@player] Sac de couchage douillet") .. "\n/drop sac annonce"
end
-- annonce en /dire : en anglais pour tout le monde (serveurs aux langues mêlées), quelle que soit la langue du client
SB.SAY = "Sleeping bag (group XP bonus): /w %s inv · auto-invite Dropamine"
function SB.Text(name)
  return string.format(SB.SAY, name or "?")
end

-- Nom du déroulement : celui du sort de l'objet (GetItemSpell, dans la langue du client) ; en secours, ces mots
-- (« Déroulement de sac » sur un client français : environ 15 s d'incantation).
SB.CAST_WORDS = { "déroulement", "unroll", "bedroll", "sleeping bag", "schlafsack", "saco", "sacco", "спальн" }
function SB.IsCast(name, spell)
  if not name then return false end
  if spell and name == spell then return true end
  local n = lower(name)
  for _, k in ipairs(SB.CAST_WORDS) do if string.find(n, k, 1, true) then return true end end
  return SB.IsBagName(name)
end
local function cooldown(id)
  local get = (_G.C_Container and _G.C_Container.GetItemCooldown) or _G.GetItemCooldown
  return Call(get, id)
end
-- vient d'être posé : déroulement en cours, déroulement fini depuis peu sans annonce, ou recharge commencée à l'instant
-- (2 minutes si le cercle de placement attendait un clic au sol)
function SB.JustUsed(id)
  if not id then return false end
  local st, t = SB.state, now()
  local spell = Call(_G.GetItemSpell, id)
  if SB.IsCast(Call(_G.UnitCastingInfo, "player"), spell) or SB.IsCast(Call(_G.UnitChannelInfo, "player"), spell) then return true end
  if st.lastCast and t - st.lastCast < SB.PENDING and st.lastCast > st.lastAnnounce then return true end
  local start, dur = cooldown(id)
  if start and dur and dur > 0 and start > 0 then
    local p = st.pending
    return t - start < ((p and t - p < SB.PENDING) and SB.PENDING or 2)
  end
  return false
end
-- prêt à être posé à tes pieds par ce clic ([@player]) : utilisable, pas en recharge, immobile, hors combat
function SB.Ready(id)
  if not id then return false end
  local usable = Call(_G.IsUsableItem, id)
  if usable == false then return false end
  local start, dur = cooldown(id)
  if start and dur and dur > 0 and start > 0 and start + dur > now() then return false end
  local speed = Call(_G.GetUnitSpeed, "player")
  if speed and speed > 0 then return false end
  return true
end

function SB.Announce()
  local st = SB.state
  if ns.InCombat and ns.InCombat() then return false, "combat" end
  local id = knownId()
  if not SB.JustUsed(id) then
    if Call(_G.SpellIsTargeting) then   -- cercle de placement ouvert (client sans [@player]) : on attend le clic au sol
      if not (st.pending and now() - st.pending < SB.PENDING) then ns.Print(Tr["Pose le sac au sol, puis reclique sur la macro pour l'annoncer."]) end
      st.pending = now()
      return false, "à placer"
    end
    -- même clic que /use [@player] : le déroulement commence tout juste, le jeu ne le montre pas encore
    if not SB.Ready(id) then return false, "pas posé" end
  end
  local t = now()
  if t - st.lastAnnounce < SB.ANNOUNCE_GAP then SB.OpenWindow() return false, "déjà annoncé" end
  if type(_G.SendChatMessage) ~= "function" then return false, "chat" end
  local ok = pcall(_G.SendChatMessage, SB.Text(Call(_G.UnitName, "player")), "SAY")
  if not ok then return false, "chat" end
  st.lastAnnounce, st.invited, st.pending = t, {}, nil
  SB.OpenWindow()
  return true
end

function SB.CanInvite()
  if Call(_G.IsInRaid) then return false, "raid" end
  local n = Call(_G.GetNumGroupMembers) or 0
  if n >= 5 then return false, "plein" end
  if n > 0 and not Call(_G.UnitIsGroupLeader, "player") then return false, "pas chef" end
  return true
end

-- Invitation : tentée tout de suite ; si le jeu l'exige d'un clic du joueur (versions Classic), il la bloque
-- (ADDON_ACTION_BLOCKED) : on le retient (db.sleepBagClick) et les demandes attendent le prochain clic sur la macro,
-- qui invite tout le monde d'un coup. Le message système « Vous avez invité … » confirme.
local function inviteFn() return (_G.C_PartyInfo and _G.C_PartyInfo.InviteUnit) or _G.InviteUnit end
local function names(list) return table.concat(list, ", ") end
function SB.Flush()   -- appelé pendant un clic du joueur (macro) : les invitations en attente partent
  local st, out = SB.state, {}
  local invite = inviteFn()
  if type(invite) ~= "function" then return 0 end
  for _, who in ipairs(st.queue) do
    if SB.CanInvite() and pcall(invite, who) then st.invited[who] = true out[#out + 1] = who end
  end
  st.queue = {}
  return #out
end
function SB.OnWhisper(msg, sender)
  local st = SB.state
  if not SB.IsOpen() then return false end
  local word = lower(msg):gsub("^%s+", ""):gsub("%s+$", "")
  if not SB.WORDS[word] then return false end
  local who = tostring(sender or "")
  if who == "" or st.invited[who] then return false end
  for _, q in ipairs(st.queue) do if q == who then return false end end
  if not SB.CanInvite() then return false end
  st.queue[#st.queue + 1] = who
  if ns.db and ns.db.sleepBagClick then
    ns.Print(string.format(Tr["Le jeu bloque l'invitation automatique : clique sur ta macro sac pour inviter %s."], names(st.queue)))
    return false
  end
  ns.Print(string.format(Tr["%s demande une invitation."], who))
  local invite = inviteFn()
  st.trying = who
  if type(invite) == "function" then pcall(invite, who) end
  st.trying = nil
  return true
end
-- le jeu a bloqué l'invitation : on passe en mode « clic » pour la suite
function SB.OnBlocked(addon, fn)
  if tostring(addon) ~= "Dropamine" or not tostring(fn):find("InviteUnit", 1, true) then return end
  if ns.db then ns.db.sleepBagClick = true end
  if #SB.state.queue > 0 then ns.Print(string.format(Tr["Le jeu bloque l'invitation automatique : clique sur ta macro sac pour inviter %s."], names(SB.state.queue))) end
end
-- « Vous avez invité X à rejoindre votre groupe. » (texte du jeu, dans sa langue) : X sort de la file
function SB.OnSystem(msg)
  local fmt = _G.ERR_INVITE_PLAYER_S
  if type(fmt) ~= "string" or type(msg) ~= "string" then return end
  local pat = "^" .. fmt:gsub("([%^%$%(%)%.%[%]%*%+%-%?])", "%%%1"):gsub("%%s", "(.+)") .. "$"
  local who = msg:match(pat)
  if not who then return end
  local st = SB.state
  for i = #st.queue, 1, -1 do
    local q = st.queue[i]
    if q == who or q:match("^([^%-]+)") == who then st.invited[q] = true table.remove(st.queue, i) end
  end
end
if ns.On then
  ns.On("ADDON_ACTION_BLOCKED", function(_, addon, fn) SB.OnBlocked(addon, fn) end)
  ns.On("ADDON_ACTION_FORBIDDEN", function(_, addon, fn) SB.OnBlocked(addon, fn) end)
  ns.On("CHAT_MSG_SYSTEM", function(_, msg) SB.OnSystem(msg) end)
end
if ns.On then ns.On("CHAT_MSG_WHISPER", function(_, msg, sender) SB.OnWhisper(msg, sender) end) end
-- fin du déroulement : notée (le clic suivant peut annoncer) ; rappel si rien n'a été annoncé
-- (un addon ne peut pas écrire en /dire tout seul, seulement pendant un clic du joueur)
function SB.OnCast(unit, spellID)
  if unit ~= "player" then return end
  local id = ns.db and ns.db.sleepBagItem
  local name = Call(_G.GetSpellInfo, spellID)
  if not SB.IsCast(name, id and Call(_G.GetItemSpell, id)) then return end
  local st, t = SB.state, now()
  st.lastCast = t
  if t - st.lastAnnounce > 30 then ns.Print(Tr["Sac posé : reclique sur la macro pour l'annoncer."]) end
end
if ns.On then ns.On("UNIT_SPELLCAST_SUCCEEDED", function(_, unit, _, spellID) SB.OnCast(unit, spellID) end) end

-- macro « Sac Dropamine » (par personnage), créée ou mise à jour, puis posée sur le curseur pour la barre
function SB.MakeMacro()
  if ns.InCombat and ns.InCombat() then return false, Tr["Hors combat seulement."] end
  if type(_G.CreateMacro) ~= "function" then return false, Tr["Macros indisponibles."] end
  local id = knownId()
  -- icône « ? » (134400) : le jeu montre alors celle de l'objet utilisé par la macro (le vrai sac), avec sa recharge
  local body, icon = SB.MacroBody(id), 134400
  local name = Tr[SB.MACRO]
  local idx = Call(_G.GetMacroIndexByName, name) or 0
  if idx <= 0 then idx = Call(_G.GetMacroIndexByName, SB.MACRO) or 0 end
  if idx > 0 then Call(_G.EditMacro, idx, name, icon, body)
  else
    local _, perChar = Call(_G.GetNumMacros)
    if (perChar or 0) >= (_G.MAX_CHARACTER_MACROS or 18) then return false, Tr["Plus de place pour une macro de personnage."] end
    idx = Call(_G.CreateMacro, name, icon, body, true) or 0
  end
  if idx <= 0 then return false, Tr["Macros indisponibles."] end
  Call(_G.PickupMacro, idx)
  return true, id
end

ns.SlashExt = ns.SlashExt or {}
local function slash(rest)
  if lower(rest):match("^%s*annonce") or lower(rest):match("^%s*announce") then
    if #SB.state.queue > 0 then SB.Flush() end   -- clic pendant que des joueurs attendent : on les invite aussi
    SB.Announce() return
  end
  if lower(rest):match("^%s*debug") then SB.Debug() return end
  if lower(rest):match("^%s*ouvr") or lower(rest):match("^%s*open") then SB.OpenWindow() SB.state.invited = {} ns.Print(Tr["Invitations automatiques ouvertes 5 minutes : qui te chuchote « inv » est invité."]) return end
  local ok, info = SB.MakeMacro()
  if not ok then ns.Print(info) return end
  ns.Print(Tr["Macro « Sac Dropamine » sur ton curseur : pose-la dans ta barre. Un clic pose le sac, l'annonce en /dire et invite pendant 5 minutes qui te chuchote « inv »."]
    .. (info and "" or (" " .. Tr["(sac pas trouvé dans tes sacs : la macro utilise son nom)"])))
end
ns.SlashExt.sac, ns.SlashExt.bag, ns.SlashExt.sleepingbag = slash, slash, slash
ns.HelpExt = ns.HelpExt or {}
ns.HelpExt[#ns.HelpExt + 1] = "/drop sac : macro du sac de couchage (pose, annonce, invitations auto sur « inv »)"   -- traduit à l'affichage
