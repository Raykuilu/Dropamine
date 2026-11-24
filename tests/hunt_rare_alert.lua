_G.time=os.time
local handlers={}
_G.LOOT_ITEM_SELF="You receive loot: %s."
_G.GetItemInfo=function(x) return nil,nil,3 end
_G.UnitName=function() return "Ray" end
_G.UnitClass=function() return "Druide","DRUID" end
_G.ForeverDungeonJournal_NS={DB={["Deadmines"]={level="15-20",bosses={
 {name="Smite",loot={{5192,"Thief's Blade","One-Hand, Sword",4},{5199,"Smelting Pants","Legs, Leather",3}}}}}}}
local store={}
local ns; ns={db={ui={rareMin="rare"}},N=tonumber,On=function(e,f) handlers[e]=f end,Print=print,CharDB=function() return store end,SlashExt={},HelpExt={},
 Opt=function(k) return true end,
 Progress={Toast=function(t,s,o,k,snd,ic) print("TOAST",t,s,ic) end}, Fold=function(s) return s:lower() end}
assert(loadfile("Hunt.lua"))("Dropamine",ns)
local H=ns.Hunt
local L="|cffa335ee|Hitem:5192::::::::|h[Thief's Blade]|h|r"
handlers.CHAT_MSG_LOOT("ev","You receive loot: "..L..".","")
local L2="|cff0070dd|Hitem:5199::::::::|h[Smelting Pants]|h|r"
handlers.CHAT_MSG_LOOT("ev","You receive loot: "..L2..".","")
local secs=H.LogSections()
for _,s in ipairs(secs) do for _,e in ipairs(s.entries) do if e.bosses then for _,b in ipairs(e.bosses) do print(e.label,b.name,b.kills) end end end end
