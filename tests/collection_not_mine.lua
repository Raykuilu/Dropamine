-- 3.11.1 : un objet vu dans la fenêtre de butin ou dans un jet de groupe, gagné par un autre, ne passe pas « obtenu ».
_G.time=os.time
local handlers={}
_G.LOOT_ITEM_SELF="Vous recevez le butin : %s."
_G.LOOT_ITEM="%s reçoit le butin : %s."
_G.LOOT_ROLL_GREED_SELF="Vous avez choisi Cupidité pour : %s"
_G.LOOT_ROLL_ROLLED_GREED="Jet de Cupidité - %1$d pour %2$s par %3$s"
_G.LOOT_ROLL_YOU_WON="Vous avez gagné : %s"
_G.GetItemInfo=function(x) return nil,nil,3 end
_G.UnitName=function() return "Ray" end
_G.UnitClass=function() return "Druide","DRUID" end
_G.ForeverDungeonJournal_NS={DB={["Gnomeregan"]={level="29-38",bosses={
 {name="Crowd Pummeler 9-60",loot={{9449,"Manual Crowd Pummeler","Two-Hand, Mace",3},{9450,"Gnomebot Operating Boots","Feet, Leather",3}}}}}}}
local store={}
local ns; ns={db={ui={}},N=tonumber,On=function(e,f) handlers[e]=handlers[e] or {} table.insert(handlers[e],f) end,Print=function() end,CharDB=function() return store end,SlashExt={},HelpExt={},
 Opt=function(k) return false end,
 Progress={Toast=function() end}, Fold=function(s) return s:lower() end}
local function fire(e,...) for _,f in ipairs(handlers[e] or {}) do f(e,...) end end
assert(loadfile("Hunt.lua"))("Dropamine",ns)
local H=ns.Hunt
local L="|cff0070dd|Hitem:9449::::::::|h[Manual Crowd Pummeler]|h|r"
local L2="|cff0070dd|Hitem:9450::::::::|h[Gnomebot Operating Boots]|h|r"
local function got(id)
  for _,s in ipairs(H.LogSections()) do for _,e in ipairs(s.entries) do for _,b in ipairs(e.bosses or {}) do
    for _,it in ipairs(b.items) do if it.id==id then return it.got end end end end end
end
-- fenêtre de butin du boss : l'objet y est visible
_G.GetNumLootItems=function() return 1 end
_G.GetLootSlotLink=function() return L end
fire("LOOT_OPENED")
assert(got(9449)==false, "fenêtre de butin : ne doit pas marquer obtenu")
-- messages de jet qui portent ton nom
fire("CHAT_MSG_LOOT","Vous avez choisi Cupidité pour : "..L,"Ray")
fire("CHAT_MSG_LOOT","Jet de Cupidité - 45 pour "..L.." par Ray","Ray")
assert(got(9449)==false, "jet de dés : ne doit pas marquer obtenu")
-- un autre le reçoit
fire("CHAT_MSG_LOOT","Bob reçoit le butin : "..L..".","Bob")
assert(got(9449)==false, "reçu par un autre : ne doit pas marquer obtenu")
-- toi tu reçois l'autre objet
fire("CHAT_MSG_LOOT","Vous recevez le butin : "..L2..".","Ray")
assert(got(9450)==true, "reçu par toi : obtenu")
-- clic droit : retirer puis remettre
assert(H.SetOwned(9450,false)) assert(got(9450)==false, "retiré à la main")
assert(H.SetOwned(9449,true)) assert(got(9449)==true, "marqué à la main")
assert(not H.SetOwned(123456,true), "objet hors log refusé")
print("collection_not_mine OK")
