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
version = "1.0.3"

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

configuration_options = CH and 
{
	{
		name = "SHOWPLAYERSOPTIONS",
		label = "玩家指针",
		hover = "经过屏幕边缘显示玩家的指针。",
		options =	{
						{description = "总是", data = 3},
						{description = "记分板", data = 2},
						{description = "从不", data = 1},
					},
		default = 2,
	},
	{
		name = "SHOWPLAYERICONS",
		label = "玩家图标",
		hover = "地图上的玩家图标。",
		options =	{
						{description = "显示", data = true},
						-- {description = "隐藏", data = false},
					},
		default = true,
	},
	{
		name = "FIREOPTIONS",
		label = "显示篝火",
		hover = "用类似玩家的指示器显示篝火。" ..
				"\n当它们以这种方式可见时，它们会冒烟。",
		options =	{
						{description = "总是", data = 1},
						{description = "木炭", data = 2},
						{description = "禁用", data = 3},
					},
		default = 2,
	},
	{
		name = "SHOWFIREICONS",
		label = "篝火图标",
		hover = "在地图上全局显示篝火(这只会在篝火设置为显示时工作)。" ..
				"\n当它们以这种方式可见时，它们会冒烟。",
		options =	{
						{description = "显示", data = true},
						{description = "隐藏", data = false},
					},
		default = true,
	},
	{
		name = "SHAREMINIMAPPROGRESS",
		label = "共享地图",
		hover = "在玩家之间共享地图探索。只有当" .. 
				"\n“玩家指针”和“玩家图标”没有同时禁用的情况下才会有效。",
		options =	{
						{description = "启用", data = true},
						{description = "禁用", data = false},
					},
		default = true,
	},
	{
		name = "COMPLETESYNC",
		label = "共享地图(完全同步)",
		hover = "完全同步地图，将玩家不在主世界/洞穴世界/当前服务器时被探索的地图也共享给该玩家。也对瓶中信的地图进行同步\n" .. 
				"\n“共享地图”启用的时候才会有效。",
		options =	{
						{description = "启用", data = true},
						-- {description = "禁用", data = false},
					},
		default = true,
	},
	{
		name = "STOPSAVEMAPEXPLORER",
		label = "减少卡顿",
		hover = "实验性功能，尝试减少上下洞穴时的卡顿。通过修改人物存档来实现，我不确定这是否安全",
		options =	{
						{description = "启用", data = true},
						{description = "禁用", data = false},
					},
		default = true,
	},
	{
		name = "OVERRIDEMODE",
		label = "荒野覆盖",
		hover = "如果启用，它将使用你在荒野模式中设置的其他选项。" ..
				"\n否则，它将不会显示玩家，但所有的篝火都会冒烟并可见。",
		options =	{
						{description = "启用", data = true},
						{description = "禁用", data = false},
					},
		default = false,
	},
	{
		name = "ENABLEPINGS",
		label = "标记",
		hover = "是否允许玩家标记(alt+click)地图。",
		options =	{
						{description = "启用", data = true},
						{description = "禁用", data = false},
					},
		default = true,
	},
} or
{
	{
		name = "SHOWPLAYERSOPTIONS",
		label = "Player Indicators",
		hover = "The arrow things that show players past the edge of the screen.",
		options =	{
						{description = "Always", data = 3},
						{description = "Scoreboard", data = 2},
						{description = "Never", data = 1},
					},
		default = 2,
	},
	{
		name = "SHOWPLAYERICONS",
		label = "Player Icons",
		hover = "The player icons on the map.",
		options =	{
						{description = "Show", data = true},
						-- {description = "Hide", data = false},
					},
		default = true,
	},
	{
		name = "FIREOPTIONS",
		label = "Show Fires",
		hover = "Show fires with indicators like players." ..
				"\nThey will smoke when they are visible this way.",
		options =	{
						{description = "Always", data = 1},
						{description = "Charcoal", data = 2},
						{description = "Disabled", data = 3},
					},
		default = 2,
	},
	{
		name = "SHOWFIREICONS",
		label = "Fire Icons",
		hover = "Show fires globally on the map (this will only work if fires are set to show)." ..
				"\nThey will smoke when they are visible this way.",
		options =	{
						{description = "Show", data = true},
						{description = "Hide", data = false},
					},
		default = true,
	},
	{
		name = "SHAREMINIMAPPROGRESS",
		label = "Share Map",
		hover = "Share map exploration between players. This will only work if" .. 
				"\n'Player Indicators' and 'Player Icons' are not both disabled.",
		options =	{
						{description = "Enabled", data = true},
						{description = "Disabled", data = false},
					},
		default = true,
	},
	{
		name = "COMPLETESYNC",
		label = "Share Map (CompleteSync)",
		hover = "Completely sync the map, sharing the area explored when players are not in the master world/cave world/current server to them. Also syncs maps of messages in bottles" .. 
				"\nOnly works if 'Share Map' is enabled.",
		options =	{
						{description = "Enabled", data = true},
						-- {description = "Disabled", data = false},
					},
		default = true,
	},
	{
		name = "STOPSAVEMAPEXPLORER",
		label = "Reduce Lag",
		hover = "Experimental feature, trying to reduce lag when going up and down caves. It works by modifying the save files of characters, and I'm not sure if it's safe",
		options =	{
			{description = "Enabled", data = true},
			{description = "Disabled", data = false},
		},
		default = false,
	},
	{
		name = "OVERRIDEMODE",
		label = "Wilderness Override",
		hover = "If enabled, it will use the other options you set in Wilderness mode." ..
				"\nOtherwise, it will not show players, but all fires will smoke and be visible.",
		options =	{
						{description = "Enabled", data = true},
						{description = "Disabled", data = false},
					},
		default = false,
	},
	{
		name = "ENABLEPINGS",
		label = "Pings",
		hover = "Whether to allow players to ping (alt+click) the map.",
		options =	{
						{description = "Enabled", data = true},
						{description = "Disabled", data = false},
					},
		default = true,
	},
}