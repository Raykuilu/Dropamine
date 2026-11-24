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
