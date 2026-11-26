_G.time=os.time
local handlers={}
_G.GetItemInfo=function(x) return nil,nil,3 end
_G.UnitName=function() return "Ray" end
_G.UnitClass=function() return "Druide","DRUID" end
_G.ForeverDungeonJournal_NS={DB={["Dungeon"]={level="20-30",bosses={
 {name="Reth",loot={{1,"Rugged Spaulders","Shoulder, Leather",3},{2,"Shoulder B","Shoulder, Plate",4}}},
 {name="Lok",loot={{3,"Dog Whistle","Trinket",3},{4,"Trink2","Trinket",3},{5,"Trink3","Trinket",4}}}}}}}
local store={}
local ns; ns={db={ui={}},N=tonumber,On=function(e,f) handlers[e]=f end,Print=print,CharDB=function() return store end,SlashExt={},HelpExt={},
 Progress={Toast=function() end}, Fold=function(s) return s:lower() end}
assert(loadfile("Hunt.lua"))("Dropamine",ns)
local H=ns.Hunt
for _,i in ipairs{1,3,4,5,2} do H.Add("item:"..i) end
local bt=H.ByTile()
for k,v in pairs(bt) do print(k,v.name,v.id) end
-- 3.12.1 : objet inconnu du Journal (ajouté depuis le site) : sa case vient du code d'équipement donné par le jeu
_G.GetItemInfoInstant = function(id) if id == 9240 then return 9240, "Weapon", "Two-Handed Maces", "INVTYPE_2HWEAPON" end end
store.hunt.items[#store.hunt.items + 1] = { id = 9240, name = "Mallet of Zul'Farrak", attempts = 0, drops = 0 }
local bt2 = H.ByTile()
assert(bt2.weapon and bt2.weapon.id == 9240, "le maillet trouve la case Arme")
print("OK : objet inconnu du Journal rangé par son code d'équipement")
-- … et sans l'addon Dungeon Journal du tout : l'objet ajouté par lien trouve sa case et la garde
_G.ForeverDungeonJournal_NS = nil
local gi = _G.GetItemInfoInstant
_G.GetItemInfoInstant = function(id) if id == 7754 then return 7754, "Armor", "Leather", "INVTYPE_FEET" end return gi(id) end
H.Add("item:7754")
local bt3 = H.ByTile()
assert(bt3.feet and bt3.feet.id == 7754, "sans le Journal : case Pieds")
local saved
for _, it in ipairs(store.hunt.items) do if it.id == 7754 then saved = it.tile end end
assert(saved == "feet", "la case est enregistrée avec l'objet")
assert(H.ByTile().weapon and H.ByTile().weapon.id == 9240, "le maillet garde sa case")
print("OK : sans le Journal des donjons, l'objet garde sa case")
