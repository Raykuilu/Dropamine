-- 3.11.2 : le toast « Nouvelle recette ! » part aussi sur le message du chat (« Vous avez appris à … un nouvel objet : X. »),
-- et un seul toast quand l'événement NEW_RECIPE_LEARNED arrive en plus pour la même recette.
_G.time = os.time
local clock = 100
_G.GetTime = function() return clock end
_G.GetSpellInfo = function(id) return id == 2152 and "Light Leather Armor" or nil end   -- nom anglais : le chat, lui, est en français
_G.ERR_LEARN_RECIPE_S = "Vous avez appris à fabriquer un nouvel objet : %s."
local handlers, toasts = {}, {}
local ui = {}
local ns; ns = { db = { ui = ui }, N = tonumber, On = function(e, f) handlers[e] = handlers[e] or {} table.insert(handlers[e], f) end, Print = function() end,
  CharDB = function() return { hunt = { items = {} } } end, SlashExt = {}, HelpExt = {}, Progress = { Toast = function() end },
  Fold = function(x) return tostring(x):lower() end, SetOpt = function(k, v) ui[k] = v end,
  UI = { SpawnDrop = function(_, icon, title, sub) toasts[#toasts + 1] = title return {} end } }
ns.Opt = function(k) return ui[k] ~= false end
local function fire(e, ...) for _, f in ipairs(handlers[e] or {}) do f(e, ...) end end
assert(loadfile("Hunt.lua"))("Dropamine", ns)
local H = ns.Hunt

-- message du client français, avec le lien de la recette
fire("CHAT_MSG_SYSTEM", "Vous avez appris à fabriquer un nouvel objet : |cffffffff|Henchant:2152|h[Armure en cuir léger]|h|r.")
assert(#toasts == 1, "message du chat : un toast")
assert(toasts[1]:find("Armure en cuir léger", 1, true), "nom de la recette : " .. tostring(toasts[1]))
-- l'événement du jeu pour la même recette, juste après : pas de second toast
fire("NEW_RECIPE_LEARNED", 2152)
assert(#toasts == 1, "même recette annoncée deux fois : un seul toast")
-- un autre message système : rien
fire("CHAT_MSG_SYSTEM", "Vous êtes maintenant absent.")
assert(#toasts == 1, "autre message : pas de toast")
-- client anglais sans le texte officiel : le texte anglais connu suffit
_G.ERR_LEARN_RECIPE_S = nil
clock = clock + 60
fire("CHAT_MSG_SYSTEM", "You have learned how to create a new item: Embossed Leather Gloves.")
assert(#toasts == 2 and toasts[2]:find("Embossed Leather Gloves", 1, true), "client anglais")
-- réglage coupé : rien
ui.recipeToast = false
clock = clock + 60
fire("CHAT_MSG_SYSTEM", "You have learned how to create a new item: Fine Leather Belt.")
assert(#toasts == 2, "réglage coupé : pas de toast")
print("OK : toast « Nouvelle recette ! » sur le message du chat, sans doublon")
