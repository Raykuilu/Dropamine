-- Sac de couchage (3.14.0) : macro, annonce /dire sobre, invitations auto sur « inv ».
-- Usage, depuis la racine de l'addon : lua tests/sleep_bag.lua   (code de retour 1 en cas d'échec)
local T = 100
local said, invited, macros, cursor = {}, {}, {}, nil
local combat, cd, casting, group, leader, raid = false, { 0, 0 }, nil, 0, false, false
local BAG = 99001
_G.GetTime = function() return T end
_G.time = function() return 1700000000 + T end
_G.UnitName = function() return "Ray" end
_G.C_Container = {
  GetContainerNumSlots = function(b) return b == 0 and 2 or 0 end,
  GetContainerItemID = function(b, s) if b == 0 and s == 2 then return BAG end return s == 1 and 123 or nil end,
  GetItemCooldown = function() return cd[1], cd[2] end,
}
_G.GetItemInfo = function(id) return id == BAG and "Sac de couchage douillet" or "Pain" end
_G.GetItemSpell = function(id) return id == BAG and "Dérouler le sac" or nil end
_G.UnitCastingInfo = function() return casting end
_G.UnitChannelInfo = function() return nil end
local targeting = false
_G.SpellIsTargeting = function() return targeting end
_G.GetItemIcon = function() return 134400 end
_G.SendChatMessage = function(msg, ch) said[#said + 1] = { msg, ch } end
_G.InviteUnit = function(who) invited[#invited + 1] = who end
_G.IsInRaid = function() return raid end
_G.GetNumGroupMembers = function() return group end
_G.UnitIsGroupLeader = function() return leader end
_G.GetMacroIndexByName = function(n) for i, m in ipairs(macros) do if m.name == n then return i end end return 0 end
_G.GetNumMacros = function() return 0, #macros end
_G.CreateMacro = function(name, icon, body) macros[#macros + 1] = { name = name, icon = icon, body = body } return #macros end
_G.EditMacro = function(i, name, icon, body) macros[i] = { name = name, icon = icon, body = body } return i end
_G.PickupMacro = function(i) cursor = i end
local handlers = {}
local prints = {}
local ns = { db = {}, L = setmetatable({}, { __index = function(_, k) return k end }), SlashExt = {}, HelpExt = {},
  On = function(ev, fn) handlers[ev] = fn return true end, Print = function(m) prints[#prints + 1] = m end,
  InCombat = function() return combat end, Unsecret = function(...) return ... end }
assert(loadfile("SleepBag.lua"))("Dropamine", ns)
local SB = ns.SleepBag
local fail = 0
local function check(ok, what) if not ok then fail = fail + 1 print("ÉCHEC :", what) end end
local function whisper(msg, who) handlers.CHAT_MSG_WHISPER("CHAT_MSG_WHISPER", msg, who) end

-- macro : identifiant de l'objet trouvé dans les sacs, annonce par /drop sac annonce, posée sur le curseur
ns.SlashExt.sac("")
check(#macros == 1 and macros[1].body == "/use [@player] item:99001\n/drop sac annonce", "corps de la macro : " .. tostring(macros[1] and macros[1].body))
check(macros[1].name == "Sac Dropamine" and macros[1].icon == 134400 and cursor == 1, "nom, icône automatique (celle du sac), curseur")
check(ns.db.sleepBagItem == BAG, "identifiant gardé")
ns.SlashExt.bag("")
check(#macros == 1, "deuxième fois : la même macro est mise à jour")
combat = true
ns.SlashExt.sac("") check(prints[#prints] == "Hors combat seulement.", "pas de macro en combat")
combat = false

-- annonce : seulement si le sac vient d'être posé
whisper("inv", "Bob-Forever") check(#invited == 0, "pas d'invitation avant l'annonce")
cd = { 50, 600 } ns.SlashExt.sac("annonce")
check(#said == 0, "recharge commencée il y a longtemps : rien n'est dit")
casting = "Dérouler le sac" ns.SlashExt.sac("annonce") casting = nil
check(#said == 1 and said[1][2] == "SAY", "pendant le déroulement du sac : annonce en /dire")
check(said[1][1] == "Sleeping bag down, group XP bonus! /w Ray inv to join · auto-invite by Dropamine", "message sobre, en anglais pour tous : " .. tostring(said[1] and said[1][1]))
T = 110 cd = { 109.5, 600 } ns.SlashExt.sac("annonce")
check(#said == 1, "une annonce par minute au plus")

-- invitations
whisper("  INV ", "Bob-Forever") check(invited[1] == "Bob-Forever", "« inv » (casse et espaces ignorés) : invité")
whisper("inv", "Bob-Forever") check(#invited == 1, "une seule invitation par joueur")
whisper("salut, inv ?", "Zed") check(#invited == 1, "phrase : pas d'invitation")
whisper("123", "Kim") check(invited[2] == "Kim", "« 123 » marche aussi")
group, leader = 3, false whisper("invite", "Lou") check(#invited == 2, "dans un groupe sans être chef : rien")
leader = true whisper("invite", "Lou") check(invited[3] == "Lou", "chef : invité")
group = 5 whisper("inv", "Max") check(#invited == 3, "groupe plein : rien")
group, raid = 2, true whisper("inv", "Max") check(#invited == 3, "raid : rien")
raid = false T = 110 + 301 whisper("inv", "Max") check(#invited == 3, "après 5 minutes : fini")

check(ns.HelpExt[1]:find("/drop sac", 1, true) == 1, "ligne d'aide")
-- client sans [@player] : cercle de placement ; l'annonce part au clic suivant sur la macro (dans les 2 minutes)
T = 1000 cd = { 0, 0 } said = {} prints = {}
targeting = true ns.SlashExt.sac("annonce")
check(#said == 0 and prints[1] == "Pose le sac au sol, puis reclique sur la macro pour l'annoncer.", "cercle ouvert : on explique, rien n'est dit")
ns.SlashExt.sac("annonce") check(#prints == 1, "explication une seule fois")
targeting = false T = 1010 cd = { 1004, 600 }   -- posé au sol 6 s plus tôt
ns.SlashExt.sac("annonce") check(#said == 1, "clic suivant : annoncé")
T = 1200 cd = { 1180, 600 } said = {} ns.SlashExt.sac("annonce") check(#said == 0, "sans cercle en attente : seulement à l'instant")
-- nom interne différent de l'infobulle (objet du serveur) : reconnu par le nom affiché dans son lien
_G.GetItemInfo = function(id) return id == BAG and "Cozy Bedding" or "Pain" end
check(SB.FindItem() == nil, "nom interne inconnu, rien d'autre : pas trouvé")
_G.C_Container.GetContainerItemLink = function(b, s) return (b == 0 and s == 2) and "|cffffffff|Hitem:99001::::|h[Sac de couchage douillet]|h|r" or nil end
check(SB.FindItem() == BAG, "reconnu par le nom du lien")
_G.C_Container.GetContainerItemLink = nil
_G.GetItemSpell = function(id) return id == BAG and "Sleeping Bag" or nil end
check(SB.FindItem() == BAG, "reconnu par le nom du sort")
prints = {} ns.SlashExt.sac("debug") check(#prints >= 2 and prints[1]:find("<= sac", 1, true) and ns.db.sleepBagDebug == true, "debug : liste, marque le sac, traces activées")
ns.SlashExt.sac("debug") check(ns.db.sleepBagDebug == false, "debug : deuxième fois, traces coupées")
-- premier clic ([@player]) : sac prêt, immobile, hors combat → annonce tout de suite ; en mouvement → rien
_G.IsUsableItem = function() return true end
local speed = 0 _G.GetUnitSpeed = function() return speed end
T = 2000 cd = { 0, 0 } said = {} targeting = false casting = nil
ns.SlashExt.sac("annonce") check(#said == 1, "prêt : annoncé dans le même clic")
T = 3000 said = {} speed = 7 ns.SlashExt.sac("annonce") check(#said == 0, "en mouvement : rien") speed = 0
-- nom du déroulement dans la langue du client (lu sur l'objet), ou mots de secours
check(SB.IsCast("Déroulement de sac", nil) and SB.IsCast("Unroll Bedroll", nil) and not SB.IsCast("Pain", "Dérouler le sac"), "noms du déroulement")
-- fin du déroulement sans annonce : rappel, puis le clic suivant annonce même hors fenêtre de recharge
T = 4000 cd = { 3985, 600 } said = {} prints = {}
_G.GetSpellInfo = function(sid) return sid == 777 and "Déroulement de sac" or "Autre" end
SB.OnCast("player", 777) check(prints[1] == "Sac posé : reclique sur la macro pour l'annoncer.", "rappel à la fin du déroulement")
SB.OnCast("party1", 777) check(#prints == 1, "un autre joueur : rien")
T = 4030 ns.SlashExt.sac("annonce") check(#said == 1, "clic après le déroulement : annoncé")
-- invitation bloquée par le jeu (clic exigé) : retenu, file d'attente, le clic suivant sur la macro invite tout le monde
_G.ERR_INVITE_PLAYER_S = "Vous avez invité %s à rejoindre votre groupe."
T = 5000 cd = { 4999, 600 } said = {} prints = {} invited = {} group, leader, raid = 0, false, false
ns.SlashExt.sac("annonce") check(#said == 1, "annonce (fenêtre d'invitation ouverte)")
whisper("inv", "Ana") check(prints[#prints] == "Ana demande une invitation." and invited[1] == "Ana", "tentée tout de suite, signalée")
SB.OnSystem("Vous avez invité Ana à rejoindre votre groupe.") check(#SB.state.queue == 0, "confirmée par le jeu : sortie de la file")
whisper("inv", "Bea") SB.OnBlocked("Dropamine", "InviteUnit()")
check(ns.db.sleepBagClick == true and prints[#prints]:find("clique sur ta macro sac pour inviter Bea", 1, true), "bloquée : mode clic, message")
whisper("inv", "Cid") check(#invited == 2 and #SB.state.queue == 2, "en mode clic : Cid attend sans tentative")
T = 5100 cd = { 5099, 600 } ns.SlashExt.sac("annonce")
check(invited[3] == "Bea" and invited[4] == "Cid" and #SB.state.queue == 0, "clic sur la macro : Bea et Cid invités")
SB.OnBlocked("AutreAddon", "InviteUnit()") SB.OnBlocked("Dropamine", "CastSpell()")
-- /reload : la mémoire de l'addon repart à zéro, mais la fenêtre (heure réelle, dans DropamineDB) reste ouverte
T = 6000 cd = { 5999, 600 } ns.db.sleepBagClick = nil said = {} invited = {}
ns.SlashExt.sac("annonce") check(#said == 1, "annonce avant /reload")
SB.state.until_ = 0 SB.state.lastAnnounce = -1e9 SB.state.invited = {} SB.state.queue = {}
T = 6100 whisper("inv", "Dan") check(invited[1] == "Dan", "après /reload : toujours invité")
T = 6000 + 301 whisper("inv", "Eve") check(#invited == 1, "5 minutes passées : fini")
T = 9000 invited = {} ns.SlashExt.sac("ouvrir") whisper("inv", "Fay") check(invited[1] == "Fay", "/drop sac ouvrir : invitations ouvertes sans annonce")
-- message Battle.net (ami BattleTag) : on invite le personnage qu'il joue
_G.GetRealmName = function() return "Forever" end
local acc = { [42] = { gameAccountInfo = { characterName = "Framby", realmName = "Forever", clientProgram = "WoW" } },
  [43] = { gameAccountInfo = { characterName = "Zoe", realmName = "Autre Royaume", clientProgram = "WoW" } },
  [44] = { gameAccountInfo = { clientProgram = "App" } } }
_G.C_BattleNet = { GetAccountInfoByID = function(id) return acc[id] end }
check(SB.BNetCharacter(42) == "Framby" and SB.BNetCharacter(43) == "Zoe-AutreRoyaume" and SB.BNetCharacter(44) == nil, "personnage d'un ami Battle.net")
T = 9100 invited = {} ns.SlashExt.sac("ouvrir")
handlers.CHAT_MSG_BN_WHISPER("CHAT_MSG_BN_WHISPER", "inv", "|Kq1|k", "", "", "", "", 0, 0, "", 0, 7, "", 42)
check(invited[1] == "Framby", "chuchotement Battle.net « inv » : Framby invité")
handlers.CHAT_MSG_BN_WHISPER("CHAT_MSG_BN_WHISPER", "inv", "|Kq2|k", "", "", "", "", 0, 0, "", 0, 8, "", 44)
check(#invited == 1, "ami pas en jeu : rien")
-- rappel automatique, une seule fois, quand le sac est dans les sacs ; bouton de la fenêtre Progression = macro
prints = {} ns.db.sleepBagHint = nil
check(SB.HintOnce() == true and prints[1]:find("/drop sac", 1, true), "rappel la première fois")
check(SB.HintOnce() == false and #prints == 1, "puis plus jamais")
check(SB.Has() == true, "possède le sac")
check(SB.Give() == true and cursor ~= nil, "bouton Sac : macro sur le curseur")
print(fail == 0 and "OK : sac de couchage" or (fail .. " échec(s)"))
os.exit(fail == 0 and 0 or 1)
