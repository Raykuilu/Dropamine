-- 3.13.0 : guichet Dropamine.app — la ligne envoyée porte le préfixe DROP:HS2:, et un seul lecteur accepte
-- le code combiné du site (DROP:SYNC1: chasse + sorties), les nouveaux codes isolés et les anciens (DROP-CH1, DROP-RUN1).
_G.UnitName = function() return "Ray" end
_G.UnitLevel = function() return 37 end
_G.GetGuildInfo = function() return "Everybody Knows" end
_G.GetCurrentRegion = function() return 3 end
_G.time = function() return 1795600000 end
local ns = { VERSION = "3.13.0", N = tonumber }
ns.L = setmetatable({}, { __index = function(_, k) return k end })
ns.SkillsForCharSheet = function() return {}, { { id = "staves", rank = 110 } }, { id = "defense", rank = 185 } end
ns.DebugWindow = { Show = function() end }
_G.GetLocale = function() return "frFR" end
local hunt, outs = {}, {}
ns.Hunt = {
  List = function() return { { id = 274599, name = "Brassards féaux", attempts = 3, drops = 0 }, { id = 7756, name = "Gants de dressage de chien", attempts = 2, drops = 0 } } end,
  ImportCode = function(code)
    local body = tostring(code):match("DROP%-CH1:([%w%.]+)") if not body then return nil end
    local added, dup = 0, 0
    for tok in body:gmatch("%w+") do local id = tonumber(tok, 36) if hunt[id] then dup = dup + 1 else hunt[id] = true added = added + 1 end end
    return added, dup, false
  end,
  AddOuting = function(code)
    local at36, dun = tostring(code):match("DROP%-RUN1:(%w+)~([^~]*)~")
    if not at36 then return nil end
    local k = at36 .. dun
    if outs[k] then return outs[k], "dup" end
    outs[k] = { at = tonumber(at36, 36), dun = dun } return outs[k]
  end,
}
assert(loadfile("Hiscores.lua"))("Dropamine", ns)
local HS = ns.Hiscores

local line = HS.Build()
assert(line and line:sub(1, 9) == "DROP:HS2:", "préfixe DROP:HS2 : " .. tostring(line and line:sub(1, 12)))
assert(line:find("hu=274599~Brassards féaux~3~0,7756~2~0", 1, true), "objet propre à Forever : nom traduit ; les autres : numéro seul")
assert(line:find(";lc=frFR;", 1, true), "langue du client")

-- code combiné, tel que le site le produit (/drop DROP:SYNC1:ch=…;run=…|…)
local function b36(n) local s, d = "", "0123456789abcdefghijklmnopqrstuvwxyz" repeat local r = n % 36 s = d:sub(r + 1, r + 1) .. s n = math.floor(n / 36) until n == 0 return s end
local code = "/drop DROP:SYNC1:ch=" .. b36(7755) .. "." .. b36(19508) .. ";run=" .. b36(1795700000) .. "~Gnomeregan~Ray_Kuilu|" .. b36(1795800000) .. "~Uldaman~Patience"
local msg = HS.ApplyCode(code)
assert(msg and hunt[7755] and hunt[19508], "chasse : 2 objets ajoutés")
assert(outs[b36(1795700000) .. "Gnomeregan"] and outs[b36(1795800000) .. "Uldaman"], "2 sorties notées")
assert(msg:find("2 objets ajoutés à la chasse", 1, true) and msg:find("2 sorties notées", 1, true), "résumé : " .. msg)
-- recoller le même code : rien de nouveau, tout est « déjà »
local again = HS.ApplyCode(code)
assert(again:find("2 déjà suivis", 1, true) and again:find("2 sorties déjà notées", 1, true), "deuxième fois : " .. again)
-- anciens codes, encore lus
assert(HS.ApplyCode("/drop DROP-CH1:" .. b36(1234)) and hunt[1234], "ancien DROP-CH1")
assert(HS.ApplyCode("/drop DROP-RUN1:" .. b36(1795900000) .. "~Maraudon~Ray") and outs[b36(1795900000) .. "Maraudon"], "ancien DROP-RUN1")
-- n'importe quoi : rien
assert(HS.ApplyCode("bonjour") == nil and HS.ApplyCode("DROP:SYNC1:zz=1") == nil, "code inconnu refusé")
print("OK : guichet Dropamine.app — ligne DROP:HS2, code combiné du site (chasse + sorties), anciens codes")
