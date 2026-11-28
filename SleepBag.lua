-- Dropamine 3.14.0 : le sac de couchage (« Sac de couchage douillet », objet de vendeur de Forever) : bonus d'XP
-- partagé avec le groupe. /drop sac (ou le bouton Sac de la fenêtre Progression) crée une macro à glisser dans la barre :
--  * un clic pose le sac à tes pieds ([@player], sans cercle de placement) et l'annonce en /dire, en anglais pour
--    tous (serveurs aux langues mêlées) : « Sleeping bag down, group XP bonus! /w Prénom Nom inv to join · auto-invite
--    by Dropamine » ; le jeu n'autorise /dire que pendant un clic, d'où l'annonce dans la macro ;
--  * pendant 5 minutes, qui te chuchote « inv » (ou « invite », « 123 »), aussi par Battle.net, est invité :
--    seulement si tu es seul ou chef, groupe pas plein, jamais en raid, une fois par joueur ;
--  * si le jeu exigeait un clic pour inviter, les demandes attendent le prochain clic sur la macro ;
--  * rappel unique la première fois que le sac est dans les sacs.
local _, ns = ...
local Tr = ns.L

local SB = { WINDOW = 300, ANNOUNCE_GAP = 60, PENDING = 120,
  MACRO = "Sac Dropamine",   -- nom français ; la macro prend le nom traduit (Tr) et retrouve l'ancien
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
local function lower(s) return (string.lower(tostring(s or ""))) end

-- fenêtre d'invitation : aussi en heure réelle (time()) dans DropamineDB, pour survivre à un /reload
local function epoch() return Call(_G.time) or 0 end
function SB.OpenWindow() if ns.db then ns.db.sleepBagWin = epoch() end SB.state.until_ = now() + SB.WINDOW end
function SB.IsOpen()
  if now() <= SB.state.until_ then return true end
  local at = ns.db and ns.db.sleepBagWin
  return type(at) == "number" and epoch() - at >= 0 and epoch() - at < SB.WINDOW
end

-- ------------------------------------------------------------------------------------------------ l'objet
-- Sur Forever, le nom interne d'un objet du serveur peut manquer : on regarde aussi le nom affiché dans son lien
-- et celui de son sort « Utiliser ». L'identifiant trouvé est gardé.
SB.NAMES = { "sac de couchage", "couchage", "sleeping bag", "bedroll", "bed roll", "schlafsack", "saco de dormir", "sacco a pelo", "спальн" }
function SB.IsBagName(name)
  local n = lower(name)
  if n == "" then return false end
  for _, k in ipairs(SB.NAMES) do if string.find(n, k, 1, true) then return true end end
  return false
end
local function linkName(link) return type(link) == "string" and link:match("|h%[(.-)%]|h") or nil end
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
  local C = _G.C_Container
  local getLink = (C and C.GetContainerItemLink) or _G.GetContainerItemLink
  return SB.Each(function(bag, slot, id)
    if SB.IsBagName(Call(_G.GetItemInfo, id)) or SB.IsBagName(linkName(Call(getLink, bag, slot))) or SB.IsBagName(Call(_G.GetItemSpell, id)) then return id end
  end)
end
local function knownId()
  local db = ns.db
  local id = SB.FindItem()
  if id and db then db.sleepBagItem = id end
  return id or (db and db.sleepBagItem)
end
function SB.Has() return SB.FindItem() ~= nil end

-- ------------------------------------------------------------------------------------------------ l'annonce
function SB.MacroBody(id)
  -- l'identifiant marche dans toutes les langues ; sans lui (sac pas encore vu), le nom français, seul connu
  return (id and ("/use [@player] item:" .. id) or "/use [@player] Sac de couchage douillet") .. "\n/drop sac annonce"
end
SB.SAY = "Sleeping bag down, group XP bonus! /w %s inv to join · auto-invite by Dropamine"
function SB.Text(name) return string.format(SB.SAY, name or "?") end
-- sur Forever, UnitName donne le prénom puis le nom de famille : il faut les deux pour chuchoter
function SB.FullName()
  local first, last = Call(_G.UnitName, "player")
  if type(last) == "string" and last ~= "" and not last:find("%-") then return first .. " " .. last end
  return first
end

-- nom du déroulement : celui du sort de l'objet (langue du client) ; en secours, ces mots (« Déroulement de sac », ~15 s)
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
-- vient d'être posé : déroulement en cours, fini depuis peu sans annonce, ou recharge commencée à l'instant
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
-- prêt à être posé par ce clic : utilisable, pas en recharge, immobile
function SB.Ready(id)
  if not id then return false end
  if Call(_G.IsUsableItem, id) == false then return false end
  local start, dur = cooldown(id)
  if start and dur and dur > 0 and start > 0 and start + dur > now() then return false end
  local speed = Call(_G.GetUnitSpeed, "player")
  return not (speed and speed > 0)
end
function SB.Announce()
  local st = SB.state
  if ns.InCombat and ns.InCombat() then return false end
  local id = knownId()
  if not SB.JustUsed(id) then
    if Call(_G.SpellIsTargeting) then   -- cercle de placement ouvert : on attend le clic au sol
      if not (st.pending and now() - st.pending < SB.PENDING) then ns.Print(Tr["Pose le sac au sol, puis reclique sur la macro pour l'annoncer."]) end
      st.pending = now()
      return false
    end
    if not SB.Ready(id) then return false end   -- même clic que /use [@player] : le déroulement commence à peine
  end
  local t = now()
  if t - st.lastAnnounce < SB.ANNOUNCE_GAP then SB.OpenWindow() return false end
  if type(_G.SendChatMessage) ~= "function" or not pcall(_G.SendChatMessage, SB.Text(SB.FullName()), "SAY") then return false end
  st.lastAnnounce, st.invited, st.pending = t, {}, nil
  SB.OpenWindow()
  return true
end
-- fin du déroulement sans annonce : rappel (un addon ne peut pas écrire en /dire tout seul)
function SB.OnCast(unit, spellID)
  if unit ~= "player" then return end
  local id = ns.db and ns.db.sleepBagItem
  if not SB.IsCast(Call(_G.GetSpellInfo, spellID), id and Call(_G.GetItemSpell, id)) then return end
  local st, t = SB.state, now()
  st.lastCast = t
  if t - st.lastAnnounce > 30 then ns.Print(Tr["Sac posé : reclique sur la macro pour l'annoncer."]) end
end

-- ------------------------------------------------------------------------------------------------ les invitations
function SB.CanInvite()
  if Call(_G.IsInRaid) then return false end
  local n = Call(_G.GetNumGroupMembers) or 0
  if n >= 5 then return false end
  if n > 0 and not Call(_G.UnitIsGroupLeader, "player") then return false end
  return true
end
local function inviteFn() return (_G.C_PartyInfo and _G.C_PartyInfo.InviteUnit) or _G.InviteUnit end
local function blockedText() return string.format(Tr["Le jeu bloque l'invitation automatique : clique sur ta macro sac pour inviter %s."], table.concat(SB.state.queue, ", ")) end
-- pendant un clic du joueur (macro) : les invitations en attente partent
function SB.Flush()
  local st, n = SB.state, 0
  local invite = inviteFn()
  if type(invite) ~= "function" then return 0 end
  for _, who in ipairs(st.queue) do
    if SB.CanInvite() and pcall(invite, who) then st.invited[who] = true n = n + 1 end
  end
  st.queue = {}
  return n
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
  if ns.db and ns.db.sleepBagClick then ns.Print(blockedText()) return false end
  ns.Print(string.format(Tr["%s demande une invitation."], who))
  local invite = inviteFn()
  if type(invite) == "function" then pcall(invite, who) end
  return true
end
-- le jeu a bloqué l'invitation : mode « clic » pour la suite
function SB.OnBlocked(addon, fn)
  if tostring(addon) ~= "Dropamine" or not tostring(fn):find("InviteUnit", 1, true) then return end
  if ns.db then ns.db.sleepBagClick = true end
  if #SB.state.queue > 0 then ns.Print(blockedText()) end
end
-- « Vous avez invité X à rejoindre votre groupe. » (texte du jeu, dans sa langue) : X sort de la file
function SB.OnSystem(msg)
  local fmt = _G.ERR_INVITE_PLAYER_S
  if type(fmt) ~= "string" or type(msg) ~= "string" then return end
  local who = msg:match("^" .. fmt:gsub("([%^%$%(%)%.%[%]%*%+%-%?])", "%%%1"):gsub("%%s", "(.+)") .. "$")
  if not who then return end
  local st = SB.state
  for i = #st.queue, 1, -1 do
    local q = st.queue[i]
    if q == who or q:match("^([^%-]+)") == who then st.invited[q] = true table.remove(st.queue, i) end
  end
end
-- messages Battle.net : l'expéditeur est un compte ; on invite le personnage WoW qu'il joue (« Nom-Royaume » ailleurs)
function SB.BNetCharacter(bnID)
  local B = _G.C_BattleNet
  local info = B and type(B.GetAccountInfoByID) == "function" and Call(B.GetAccountInfoByID, bnID)
  local g = type(info) == "table" and info.gameAccountInfo
  if type(g) ~= "table" or not g.characterName or g.characterName == "" then return nil end
  if g.clientProgram and g.clientProgram ~= "WoW" then return nil end
  if g.wowProjectID and _G.WOW_PROJECT_ID and g.wowProjectID ~= _G.WOW_PROJECT_ID then return nil end
  local mine = (Call(_G.GetRealmName) or ""):gsub("%s", "")
  local realm = tostring(g.realmName or ""):gsub("%s", "")
  return (realm ~= "" and realm ~= mine) and (g.characterName .. "-" .. realm) or g.characterName
end
-- deux écoutes des chuchotements (l'événement et le filtre du chat) : un même message n'est traité qu'une fois
local seen = {}
local function heard(how, msg, sender)
  local key, t = tostring(sender) .. "|" .. tostring(msg), now()
  local s = seen[key]
  if s and s.how ~= how and t - s.t < 1 then return end
  seen[key] = { t = t, how = how }
  SB.OnWhisper(msg, sender)
end
if ns.On then
  ns.On("CHAT_MSG_WHISPER", function(_, msg, sender) heard("event", msg, sender) end)
  -- bnSenderID : 13e argument de l'événement (12e après le texte)
  ns.On("CHAT_MSG_BN_WHISPER", function(_, msg, ...) local who = SB.BNetCharacter((select(12, ...))) if who then heard("bnet", msg, who) end end)
  ns.On("ADDON_ACTION_BLOCKED", function(_, addon, fn) SB.OnBlocked(addon, fn) end)
  ns.On("ADDON_ACTION_FORBIDDEN", function(_, addon, fn) SB.OnBlocked(addon, fn) end)
  ns.On("CHAT_MSG_SYSTEM", function(_, msg) SB.OnSystem(msg) end)
  ns.On("UNIT_SPELLCAST_SUCCEEDED", function(_, unit, _, spellID) SB.OnCast(unit, spellID) end)
end
if type(_G.ChatFrame_AddMessageEventFilter) == "function" then
  pcall(_G.ChatFrame_AddMessageEventFilter, "CHAT_MSG_WHISPER", function(_, _, msg, sender) heard("filter", msg, sender) return false end)
end

-- ------------------------------------------------------------------------------------------------ la macro
-- « Sac Dropamine » (par personnage), créée ou mise à jour, puis posée sur le curseur pour la barre
function SB.MakeMacro()
  if ns.InCombat and ns.InCombat() then return false, Tr["Hors combat seulement."] end
  if type(_G.CreateMacro) ~= "function" then return false, Tr["Macros indisponibles."] end
  local id = knownId()
  -- icône « ? » (134400) : le jeu montre celle de l'objet utilisé par la macro (le vrai sac), avec sa recharge
  local body, icon, name = SB.MacroBody(id), 134400, Tr[SB.MACRO]
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
-- macro sur le curseur, avec l'explication (commande /drop sac et bouton Sac de la fenêtre Progression)
function SB.Give()
  local ok, info = SB.MakeMacro()
  if not ok then ns.Print(info) return false end
  ns.Print(Tr["Macro « Sac Dropamine » sur ton curseur : pose-la dans ta barre. Un clic pose le sac, l'annonce en /dire et invite pendant 5 minutes qui te chuchote « inv »."]
    .. (info and "" or (" " .. Tr["(sac pas trouvé dans tes sacs : la macro utilise son nom)"])))
  return true
end
-- rappel automatique, une seule fois : la première fois que le sac est dans les sacs
function SB.HintOnce()
  local db = ns.db
  if not db or db.sleepBagHint or not SB.Has() then return false end
  db.sleepBagHint = true
  ns.Print(Tr["Tu as un sac de couchage : /drop sac (ou le bouton Sac de la fenêtre Progression) crée une macro qui le pose, l'annonce et invite qui te chuchote « inv »."])
  return true
end
if ns.On then
  ns.On("BAG_UPDATE_DELAYED", function() SB.HintOnce() end)
  ns.On("PLAYER_ENTERING_WORLD", function() SB.HintOnce() end)
end

ns.SlashExt = ns.SlashExt or {}
local function slash(rest)
  local r = lower(rest)
  if r:match("^%s*annonce") or r:match("^%s*announce") then
    if #SB.state.queue > 0 then SB.Flush() end   -- des joueurs attendent : ce clic les invite aussi
    SB.Announce()
  elseif r:match("^%s*ouvr") or r:match("^%s*open") then   -- invitations ouvertes sans annonce (annonce faite à la main)
    SB.OpenWindow() SB.state.invited = {}
    ns.Print(Tr["Invitations automatiques ouvertes 5 minutes : qui te chuchote « inv » est invité."])
  else
    SB.Give()
  end
end
ns.SlashExt.sac, ns.SlashExt.bag, ns.SlashExt.sleepingbag = slash, slash, slash
ns.HelpExt = ns.HelpExt or {}
ns.HelpExt[#ns.HelpExt + 1] = "/drop sac : macro du sac de couchage (pose, annonce, invitations auto sur « inv »)"   -- traduit à l'affichage
