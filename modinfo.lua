local CH = locale == "zh" or locale == "zhr"
name = CH and "(debug)全图定位(完全同步)" or "(debug)Global Positions (CompleteSync)"
description = CH and 
[[之前的全图定位模组，各个玩家之间的地图并不能完全同步，例如以下场景：
1. 玩家刚刚加入游戏，地图上的其他玩家已经探索了很多地方，但是新加入的玩家并不能看到其他玩家在他加入之前所探索的地方。
2. 玩家A位于地上，玩家B前往地下探索洞穴。当玩家A进入洞穴后，并不能看到玩家B在他进入洞穴前所探索的地方。
3. 玩家阅读了寄居蟹隐士的瓶中信，其他玩家并不会像玩家A一样更新地图。

本模组致力于解决这个问题。

本模组基于模组Global Positions -Remapped添加了同步地图的功能。和该模组一样，本模组同样没有在地图上做标记的功能。如果你有做标记的需求，考虑使用Global Pings模组。
]]
or 
[[
The previous Global Positions mod, the maps between players are not completely synchronized, for example:
1. The player just joined the game, and the other players on the map have explored many places, but the newly added player cannot see the places explored by other players before he joined.
2. Player A is on the ground, and player B goes to the cave to explore. When player A enters the cave, he cannot see the place explored by player B before he enters the cave.
3. The player read the message in the bottle of the Crabby Hermit, and other players will not update the map like player A.

This mod is committed to solving this problem. 

This mod adds the function of synchronizing the map based on the mod Global Positions -Remapped. Like that mod, this mod also does not have the function of pings on the map. If you have the need to mark on the map, consider using the Global Pings mod.
]]

author = "clearlove, Niko"
version = "1.0.2"

api_version = 10

dst_compatible = true

dont_starve_compatible = false
reign_of_giants_compatible = false
shipwrecked_compatible = false

all_clients_require_mod = true 

-- Load last in case mods what to overwrite user config data.
priority = -1000

icon_atlas = "GlobalPositionsIcon.xml"
icon = "GlobalPositionsIcon.tex"

server_filter_tags = {
    "map",
    "map share",
    "global player icons", 
    "global player indicators",
    "global positions",
}
