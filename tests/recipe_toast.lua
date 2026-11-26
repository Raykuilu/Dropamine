-- 3.11.2 : le toast « Nouvelle recette ! » part aussi sur le message du chat (« Vous avez appris à … un nouvel objet : X. »),
-- et un seul toast quand l'événement NEW_RECIPE_LEARNED arrive en plus pour la même recette.
_G.time = os.time
local clock = 100
_G.GetTime = function() return clock end
_G.GetSpellInfo = function(id) return id == 2152 and "Light Leather Armor" or nil end   -- nom anglais : le chat, lui, est en français
_G.ERR_LEARN_RECIPE_S = "Vous avez appris à fabriquer un nouvel objet : %s."
local handlers, toasts = {}, {}
lastOpts = nil
local ui = {}
local ns; ns = { db = { ui = ui }, N = tonumber, On = function(e, f) handlers[e] = handlers[e] or {} table.insert(handlers[e], f) end, Print = function() end,
  CharDB = function() return { hunt = { items = {} }, recipes = { leatherworking = { list = { { name = "Armure en cuir léger", recipeID = 2152 } } } } } end, SlashExt = {}, HelpExt = {}, Progress = { Toast = function() end },
  Fold = function(x) return tostring(x):lower() end, SetOpt = function(k, v) ui[k] = v end,
  UI = { SpawnDrop = function(_, icon, title, sub, a, b, c, opts) toasts[#toasts + 1] = title lastOpts = opts return {} end } }
ns.Opt = function(k) return ui[k] ~= false end
local function fire(e, ...) for _, f in ipairs(handlers[e] or {}) do f(e, ...) end end
assert(loadfile("Hunt.lua"))("Dropamine", ns)
local H = ns.Hunt

-- message du client français, avec le lien de la recette
fire("CHAT_MSG_SYSTEM", "Vous avez appris à fabriquer un nouvel objet : |cffffffff|Henchant:2152|h[Armure en cuir léger]|h|r.")
assert(#toasts == 1, "message du chat : un toast")
assert(toasts[1]:find("Armure en cuir léger", 1, true), "nom de la recette : " .. tostring(toasts[1]))
-- un clic ouvre le métier sur la recette (comme les toasts « recette possible »)
assert(lastOpts and lastOpts.toastData and lastOpts.toastData.skill == "leatherworking" and lastOpts.toastData.recipe.recipeID == 2152, "toast cliquable vers la recette")
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
-- 3.12.1 : message du chat sans lien (pas de numéro), puis l'événement du jeu : le toast affiché reçoit le numéro
ui.recipeToast = nil
clock = clock + 60
local shown = {}
ns.UI.SpawnDrop = function(_, icon, title, sub, a, b, c, opts) shown[#shown + 1] = title local f = { _craft = { rid = opts.toastData and opts.toastData.recipe.recipeID } } return f end
fire("CHAT_MSG_SYSTEM", "You have learned how to create a new item: Unknown Stew.")
local f = H._lastRecipe.f
assert(#shown == 1 and f and not f._craft.rid, "toast du chat sans numéro")
fire("NEW_RECIPE_LEARNED", 18241)
assert(#shown == 1, "pas de second toast")
assert(f._craft.rid == 18241, "le toast affiché reçoit le numéro de l'événement : " .. tostring(f._craft.rid))
print("OK : numéro de recette complété par l'événement du jeu")
-- 3.12.1 : recette tout juste apprise (dans aucune liste) : chat sans numéro ni métier, puis l'événement :
-- le jeu donne le métier par le numéro, le toast affiché devient cliquable vers la recette
clock = clock + 60
ns.CATALOG_BY_LINE = { [165] = { id = "leatherworking" } }
_G.C_TradeSkillUI = { GetTradeSkillLineForRecipe = function(id) if id == 3870 then return 165, "Leatherworking", 165 end end }
ns.CraftOpen = { Wire = function(f) f.wired = true end }
ns.UI.SpawnDrop = function(_, icon, title, sub, a, b, c, opts) return { td = opts.toastData } end
fire("CHAT_MSG_SYSTEM", "You have learned how to create a new item: Heavy Earthen Gloves.")
local g = H._lastRecipe.f
assert(g and not g.td and not g._craft, "chat seul : ni métier ni numéro")
fire("NEW_RECIPE_LEARNED", 3870)
assert(g._craft and g._craft.skill == "leatherworking" and g._craft.rid == 3870 and g.wired, "le toast devient cliquable vers la recette")
assert(g._craft.recipe == "Heavy Earthen Gloves", "nom du chat gardé")
print("OK : recette tout juste apprise cliquable (métier donné par le jeu)")
