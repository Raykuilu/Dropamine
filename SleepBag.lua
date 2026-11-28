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

local SB = { WINDOW = 300, ANNOUNCE_GAP = 60, MACRO = "Sac Dropamine",   -- nom français ; la macro prend le nom traduit (Tr) et retrouve l'ancien
  WORDS = { inv = true, invite = true, ["123"] = true } }
ns.SleepBag = SB
SB.state = { until_ = 0, lastAnnounce = -1e9, invited = {} }

local function Call(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a, b, c = pcall(fn, ...)
  if not ok then return nil end
  if ns.Unsecret then return ns.Unsecret(a, b, c) end
  return a, b, c
end
local function now() return Call(_G.GetTime) or 0 end
local function lower(s) return (string.lower(tostring(s or ""))) end

-- noms de l'objet dans les langues des clients (recherche dans les sacs : l'identifiant est ensuite gardé)
SB.NAMES = { "sac de couchage", "sleeping bag", "schlafsack", "saco de dormir", "sacco a pelo", "спальн" }
function SB.IsBagName(name)
  local n = lower(name)
  if n == "" then return false end
  for _, k in ipairs(SB.NAMES) do if string.find(n, k, 1, true) then return true end end
  return false
end
function SB.FindItem()
  local C = _G.C_Container
  local getN = (C and C.GetContainerNumSlots) or _G.GetContainerNumSlots
  local getId = (C and C.GetContainerItemID) or _G.GetContainerItemID
  if type(getN) ~= "function" or type(getId) ~= "function" then return nil end
  for bag = 0, 4 do
    for slot = 1, (Call(getN, bag) or 0) do
      local id = Call(getId, bag, slot)
      if id and SB.IsBagName(Call(_G.GetItemInfo, id)) then return id end
    end
  end
  return nil
end
local function knownId()
  local db = ns.db
  local id = SB.FindItem()
  if id and db then db.sleepBagItem = id end
  return id or (db and db.sleepBagItem)
end

function SB.MacroBody(id)
  -- l'identifiant marche dans toutes les langues ; sans lui (sac pas encore vu), le nom français, seul connu
  return (id and ("/use item:" .. id) or "/use Sac de couchage douillet") .. "\n/drop sac annonce"
end
function SB.Text(name)
  return string.format(Tr["Sac de couchage (bonus XP groupe) : /w %s inv · auto-invite Dropamine"], name or "?")
end

-- vient d'être posé : on est en train de le dérouler (incantation du sort de l'objet), ou sa recharge a commencé
-- à l'instant (ou l'objet n'a pas de recharge connue)
function SB.JustUsed(id)
  if not id then return false end
  local spell = Call(_G.GetItemSpell, id)
  if spell and (Call(_G.UnitCastingInfo, "player") == spell or Call(_G.UnitChannelInfo, "player") == spell) then return true end
  local get = (_G.C_Container and _G.C_Container.GetItemCooldown) or _G.GetItemCooldown
  local start, dur = Call(get, id)
  if not start or not dur or dur == 0 then return start ~= nil end
  return now() - start < 2
end

function SB.Announce()
  local st = SB.state
  if ns.InCombat and ns.InCombat() then return false, "combat" end
  local id = knownId()
  if not SB.JustUsed(id) then return false, "pas posé" end
  local t = now()
  if t - st.lastAnnounce < SB.ANNOUNCE_GAP then st.until_ = t + SB.WINDOW return false, "déjà annoncé" end
  if type(_G.SendChatMessage) ~= "function" then return false, "chat" end
  local ok = pcall(_G.SendChatMessage, SB.Text(Call(_G.UnitName, "player")), "SAY")
  if not ok then return false, "chat" end
  st.lastAnnounce, st.until_, st.invited = t, t + SB.WINDOW, {}
  return true
end

function SB.CanInvite()
  if Call(_G.IsInRaid) then return false, "raid" end
  local n = Call(_G.GetNumGroupMembers) or 0
  if n >= 5 then return false, "plein" end
  if n > 0 and not Call(_G.UnitIsGroupLeader, "player") then return false, "pas chef" end
  return true
end

function SB.OnWhisper(msg, sender)
  local st = SB.state
  if now() > st.until_ then return false end
  local word = lower(msg):gsub("^%s+", ""):gsub("%s+$", "")
  if not SB.WORDS[word] then return false end
  local who = tostring(sender or "")
  if who == "" or st.invited[who] then return false end
  if not SB.CanInvite() then return false end
  local invite = (_G.C_PartyInfo and _G.C_PartyInfo.InviteUnit) or _G.InviteUnit
  if type(invite) ~= "function" or not pcall(invite, who) then return false end
  st.invited[who] = true
  return true
end
if ns.On then ns.On("CHAT_MSG_WHISPER", function(_, msg, sender) SB.OnWhisper(msg, sender) end) end

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
  if lower(rest):match("^%s*annonce") or lower(rest):match("^%s*announce") then SB.Announce() return end
  local ok, info = SB.MakeMacro()
  if not ok then ns.Print(info) return end
  ns.Print(Tr["Macro « Sac Dropamine » sur ton curseur : pose-la dans ta barre. Un clic pose le sac, l'annonce en /dire et invite pendant 5 minutes qui te chuchote « inv »."]
    .. (info and "" or (" " .. Tr["(sac pas trouvé dans tes sacs : la macro utilise son nom)"])))
end
ns.SlashExt.sac, ns.SlashExt.bag, ns.SlashExt.sleepingbag = slash, slash, slash
ns.HelpExt = ns.HelpExt or {}
ns.HelpExt[#ns.HelpExt + 1] = "/drop sac : macro du sac de couchage (pose, annonce, invitations auto sur « inv »)"   -- traduit à l'affichage
