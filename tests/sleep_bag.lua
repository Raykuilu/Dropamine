-- Sac de couchage (3.14.0) : macro, annonce /dire sobre, invitations auto sur « inv ».
-- Usage, depuis la racine de l'addon : lua tests/sleep_bag.lua   (code de retour 1 en cas d'échec)
local T = 100
local said, invited, macros, cursor = {}, {}, {}, nil
local combat, cd, casting, group, leader, raid = false, { 0, 0 }, nil, 0, false, false
local BAG = 99001
_G.GetTime = function() return T end
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
check(#macros == 1 and macros[1].body == "/use item:99001\n/drop sac annonce", "corps de la macro : " .. tostring(macros[1] and macros[1].body))
check(macros[1].name == "Sac Dropamine" and macros[1].icon == 134400 and cursor == 1, "nom, icône, curseur")
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
check(said[1][1] == "Sac de couchage (bonus XP groupe) : /w Ray inv · auto-invite Dropamine", "message sobre : " .. tostring(said[1] and said[1][1]))
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
print(fail == 0 and "OK : sac de couchage" or (fail .. " échec(s)"))
os.exit(fail == 0 and 0 or 1)
