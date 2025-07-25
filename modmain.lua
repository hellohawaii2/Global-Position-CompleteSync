local TUNING = GLOBAL.TUNING
TUNING.REMAPPED_MODE = TUNING.REMAPPED_MODE or GetModConfigData("mode") -- Ignore config if already set via other mods

local lang = GetModConfigData("lang") or "auto"
if lang == "auto" then
    lang = GLOBAL.LanguageTranslator.defaultlang
end

local chinese_languages =
{
    zh = "zh", -- Chinese for Steam
    zhr = "zh", -- Chinese for WeGame
    ch = "zh", -- Chinese mod
    chs = "zh", -- Chinese mod
    sc = "zh", -- simple Chinese
    zht = "zh", -- traditional Chinese for Steam
	tc = "zh", -- traditional Chinese
	cht = "zh", -- Chinese mod
}

if chinese_languages[lang] ~= nil then
    lang = chinese_languages[lang]
else
    lang = "en"
end

TUNING.Global_Positions_CompleteSync_LANGUAGE = lang

PrefabFiles = {
	"globalposition_classified",
	"smoketrail",
	"globalmapicon_noproxy",
	-- "worldmapexplorer",
}
AddMinimapAtlas("minimap/campfire.xml")

Assets = {
	Asset( "IMAGE", "minimap/campfire.tex" ),
	Asset( "ATLAS", "minimap/campfire.xml" ),
	
	Asset( "IMAGE", "images/status_bg.tex" ),
	Asset( "ATLAS", "images/status_bg.xml" ),
	
    Asset( "IMAGE", "images/sharelocation.tex" ),
    Asset( "ATLAS", "images/sharelocation.xml" ),
    Asset( "IMAGE", "images/unsharelocation.tex" ),
    Asset( "ATLAS", "images/unsharelocation.xml" ),
}


local OVERRIDEMODE = GetModConfigData("OVERRIDEMODE")
local SHOWPLAYERICONS = GetModConfigData("SHOWPLAYERICONS")
local SERVERSHOWPLAYERSOPTIONS = GetModConfigData("SHOWPLAYERSOPTIONS", false)
local CLIENTSHOWPLAYERSOPTIONS = GetModConfigData("SHOWPLAYERSOPTIONS", true)
local SHOWPLAYERINDICATORS = SERVERSHOWPLAYERSOPTIONS > 1
local SHOWPLAYERSALWAYS = SHOWPLAYERINDICATORS and CLIENTSHOWPLAYERSOPTIONS == 3
local NETWORKPLAYERPOSITIONS = SHOWPLAYERICONS or SHOWPLAYERINDICATORS
local SHAREMINIMAPPROGRESS = NETWORKPLAYERPOSITIONS and GetModConfigData("SHAREMINIMAPPROGRESS")
local COMPLETESYNC = SHAREMINIMAPPROGRESS and GetModConfigData("COMPLETESYNC")
GLOBAL._GLOBALPOSITIONS_COMPLETESYNC_UPDADTEFREQUENCY = GetModConfigData("UPDADTEFREQUENCY")
local FIREOPTIONS = GetModConfigData("FIREOPTIONS")
local SHOWFIRES = FIREOPTIONS < 3
local NEEDCHARCOAL = FIREOPTIONS == 2
local SHOWFIREICONS = GetModConfigData("SHOWFIREICONS")
local ENABLEPINGS = GetModConfigData("ENABLEPINGS")
local GLOBAL_COURIER = GetModConfigData("GLOBAL_COURIER")
local USE_OPTIMIZER = GetModConfigData("use_optimizer")
local DISABLE_FOGREVEALER = GetModConfigData("disable_fogrevealer")
GLOBAL._GLOBALPOSITIONS_COMPLETESYNC_DISABLE_FOGREVEALER = DISABLE_FOGREVEALER
GLOBAL._GLOBALPOSITIONS_COMPLETESYNC_USE_OPTIMIZER = USE_OPTIMIZER
local REMOVE_MAPREVEALER_TAG = GetModConfigData("remove_maprevealer_tag")
GLOBAL._GLOBALPOSITIONS_COMPLETESYNC_REMOVE_MAPREVEALER_TAG = REMOVE_MAPREVEALER_TAG
local valid_ping_actions = {}
if ENABLEPINGS then --Only request loading of ping assets if pings are enabled
	table.insert(PrefabFiles, "pings")
	for _,ping in ipairs({"generic", "gohere", "explore", "danger", "omw"}) do
		table.insert(Assets, Asset("IMAGE", "minimap/ping_"..ping..".tex"))
		table.insert(Assets, Asset("ATLAS", "minimap/ping_"..ping..".xml"))
		AddMinimapAtlas("minimap/ping_"..ping..".xml")
        valid_ping_actions[ping] = true
	end
    valid_ping_actions.delete = true
	valid_ping_actions.clear = true
	for _,action in ipairs({"", "Danger", "Explore", "GoHere", "Omw", "Cancel", "Delete", "Clear"}) do
		table.insert(Assets, Asset("IMAGE", "images/Ping"..action..".tex"))
		table.insert(Assets, Asset("ATLAS", "images/Ping"..action..".xml"))
	end
end

local mode = GLOBAL.TheNet:GetServerGameMode()
if mode == "wilderness" and not OVERRIDEMODE then --by default, have different settings for wilderness
	SHOWPLAYERINDICATORS = false
	SHOWPLAYERICONS = false
	SHOWFIRES = true
	SHOWFIREICONS = false
	NEEDCHARCOAL = false
	SHAREMINIMAPPROGRESS = false
	COMPLETESYNC = false
end


-- ************************ Functions about mapdata update************************ 
local function save_to_buffer(world, player)
	print("[global position (CompleteSync)] saving to buffer")
    local maprecorder = world.components.maprecorder
	local old_data = maprecorder.mapdata
	maprecorder.is_recording = true
    local result, description = maprecorder:RecordMap(player)
	if result then
		print("[global position (CompleteSync)] success to saving to buffer")
		if old_data == nil then
			print("[global position (CompleteSync)] old_data is nil")
			world.shard.components.shard_isgpsnewlyadded:IncreaseCounter()
		end
	else
		print("[global position (CompleteSync)] failed to saving to buffer")
		print(description)
	end
	maprecorder.is_recording = false
end

local function learn_from_buffer(world, player)
	print("[global position (CompleteSync)] learning from buffer")
    -- player:AddTag("is_learning_from_buffer")
    player.is_learning_from_buffer = true
    local maprecorder = world.components.maprecorder
    local result, description = maprecorder:KeepTryingTeach(player)
    -- maprecorder.inst.DoTaskInTime(maprecorder, 0, maprecorder.TeachMap, player)
end

local function player2player_via_buffer(world, player_from, player_to)
    save_to_buffer(world, player_from)
    learn_from_buffer(world, player_to)
end

local function handleClientPlayerJoined(player)
	print("[global position (CompleteSync)] before RPC, the player.client_is_ready is "..tostring(player.client_is_ready))
	player.client_is_ready = true
end
local modname = "globalpositioncompletesync"
AddModRPCHandler(modname, "ClientPlayerJoined", handleClientPlayerJoined)


AddShardModRPCHandler(modname, "ShardIncreaseCounter", function()
	if GLOBAL.TheWorld.ismastershard then
		print("[global position (CompleteSync)] Shard want to IncreaseCounter, recieve a RPC")
		GLOBAL.TheWorld.shard.components.shard_isgpsnewlyadded:IncreaseCounter()
	else
		return
	end
end)
-- ************************ end of functions about mapdata update ************************ 


-- ************************ Try to accelerate ************************ 
local is_dedicated = GLOBAL.TheNet:IsDedicated()
local STOPSAVEMAPEXPLORER = is_dedicated
if STOPSAVEMAPEXPLORER then
require("networking")
GLOBAL.SerializeUserSession = function (player, isnewspawn)
	print("[global position (CompleteSync)]In my SerializeUserSession")
    if player ~= nil and player.userid ~= nil and player.userid:len() > 0 and (player == GLOBAL.ThePlayer or GLOBAL.TheNet:GetIsServer()) then
        --we don't care about references for player saves
        local playerinfo--[[, refs]] = player:GetSaveRecord()
        local data = GLOBAL.DataDumper(playerinfo, nil, GLOBAL.BRANCH ~= "dev")

        local metadataStr = ""

        if GLOBAL.TheNet:GetIsServer() then
            local metadata = {
                character = player.prefab,
            }
            metadataStr = GLOBAL.DataDumper(metadata, nil, GLOBAL.BRANCH ~= "dev")
        end

        -- TheNet:SerializeUserSession(player.userid, data, isnewspawn == true, player.player_classified ~= nil and player.player_classified.entity or nil, metadataStr)
        -- if player.player_classified ~= nil and player.player_classified.entity then
        --     local player_mapexplorer = player.player_classified.MapExplorer or nil
        --     if player_mapexplorer ~= nil then
		-- 		print("[global position (CompleteSync)] In my SerializeUserSession, record map")
        --         local mapdata = player_mapexplorer:RecordMap()
		-- 		print(mapdata)
        --         GLOBAL.TheSim:SetPersistentString("player_mapdata", mapdata, false)
        --     end
        -- end
        -- TODO: can I call "save to buffer" here to avoid bug produced by ctrl+C?
        -- save_to_buffer(GLOBAL.TheWorld, player)  -- This seems to bother the basic function. Do not use the shared buffer!

		if GLOBAL.TheWorld.shard.components.shard_isgpsnewlyadded:CanDeleteUserMap() then
			print("[global position (CompleteSync)] now delete map info from user")
        	GLOBAL.TheNet:SerializeUserSession(player.userid, data, isnewspawn == true, nil, metadataStr)
		else
			print("[global position (CompleteSync)] Can not delete map info from user, still, save map data")
			GLOBAL.TheNet:SerializeUserSession(player.userid, data, isnewspawn == true, player.player_classified ~= nil and player.player_classified.entity or nil, metadataStr)
		end
    end
end
end
-- ************************ End of Try to accelerate ************************ 

-- ************************ add maprecorder to world as a buffer ************************
AddPrefabPostInit("world", function(inst)
    if USE_OPTIMIZER then
        inst:AddComponent("maprevealoptimizer")
    end
    -- Copied from Global Positions Remapped
    -- Fix to account for this not being a consumable item.
    inst:AddComponent("maprecorder")
    local function GetMapExplorer(target) -- Needed for SpecialTeachMap
        return target ~= nil and target.player_classified ~= nil and target.player_classified.MapExplorer or nil
    end

    local function SpecialTeachMap(self, target)
        if not self:HasData() then
            -- self.inst:Remove()
            return false, "BLANK"
        elseif not self:IsCurrentWorld() then
            return false, "WRONGWORLD"
        end
        local MapExplorer = GetMapExplorer(target)
        if MapExplorer == nil then
            return false, "NOEXPLORER"
        end
		
        if not MapExplorer:LearnRecordedMap(self.mapdata) then
            return false, "I don not quite understand what this mean"
        end
    
        if self.onteachfn ~= nil then
            self.onteachfn(self.inst, target)
        end
        -- self.inst:Remove()
        return true
    end
    inst.components.maprecorder.TeachMap = SpecialTeachMap

    local function SpecialRecordMap(self, target)
        local MapExplorer = GetMapExplorer(target)
        if MapExplorer == nil then
            return false, "NOEXPLORER"
        end
    
        self.mapdata = MapExplorer:RecordMap()
        self.mapsession = GLOBAL.TheWorld.meta.session_identifier
        self.maplocation = GLOBAL.TheWorld.worldprefab
        self.mapauthor = target.name
        self.mapday = GLOBAL.TheWorld.state.cycles + 1
        if self:HasData() then
            if self.ondatachangedfn ~= nil then
                self.ondatachangedfn(self.inst)
            end
            return true
        end
    
        --Something went wrong, invalid data, so just clear it
		print("[global position (CompleteSync)]Something went wrong, invalid data, so just clear it")
        self:ClearMap()
        return false, "BLANK"
    end
    inst.components.maprecorder.RecordMap = SpecialRecordMap

    
    local KeepTryingTeach
    KeepTryingTeach = function(maprecorder, player, count)
        if count == nil then
            count = 0
        end
        count = count + 1
        if count > 600 then
            print("[global position (CompleteSync)]Wrong! Tried 600 times, but still failed to teach map to player")
            -- inst:RemoveTag("is_learning_from_buffer")
            player.is_learning_from_buffer = false
			player.success_to_learn_map = false
            return
        end
		if not player.client_is_ready then
			print("[global position (CompleteSync)]Client is not ready, waiting")
			-- local result, description = maprecorder:TeachMap(player)  -- I hope this can cause a merge error
			maprecorder.inst.DoTaskInTime(maprecorder, 1, KeepTryingTeach, player, count)
			return
		end
		if maprecorder.is_recording then
			-- print("[global position (CompleteSync)]the buffer is being written to, waiting. Please leave a comment in the workshop page if you see this line")
			-- print("[global position (CompleteSync)]在学习地图时，地图正在被写入，我怀疑这是导致地图丢失的bug所在。如果你发现了这一条，请在创意工坊留言")
			maprecorder.inst.DoTaskInTime(maprecorder, 1, KeepTryingTeach, player, count)
			return
		end
        local result, description = maprecorder:TeachMap(player)
        if result == false then
            -- check is the description is "BLANK", if not, try again
            if description ~= "BLANK" then
				print("[global position (CompleteSync)] failed "..description)
                maprecorder.inst.DoTaskInTime(maprecorder, 1, KeepTryingTeach, player, count)
            else
                -- inst:RemoveTag("is_learning_from_buffer")
				print("[global position (CompleteSync)] failed "..description)
                player.is_learning_from_buffer = false
				player.success_to_learn_map = true
            end
        else
            -- inst:RemoveTag("is_learning_from_buffer")
			print("[global position (CompleteSync)] succeed")
            player.is_learning_from_buffer = false
			player.success_to_learn_map = true
			-- maprecorder.inst.DoTaskInTime(maprecorder, 0, KeepTryingTeach, player, count)
        end
    end

    inst.components.maprecorder.KeepTryingTeach = KeepTryingTeach

    local old_maprecorder_onsave = inst.components.maprecorder.OnSave
    inst.components.maprecorder.OnSave = function(...)
        -- if GLOBAL.AllPlayers[1]~=nil then
        --     save_to_buffer(inst, GLOBAL.AllPlayers[1])
        -- end
		for i, v in ipairs(GLOBAL.AllPlayers) do
			if v~=nil and v.success_to_learn_map and (not v.is_learning_from_buffer) then
				save_to_buffer(inst, v)
				break
			else
				-- print("[global position (CompleteSync)] During saving, there is a player failed to learn map data, so not save to buffer. Please leave a comment in the workshop page if you see this line")
				-- print("[global position (CompleteSync)]在保存地图数据时，有玩家学习地图数据失败，所以不保存到缓冲区。如果你发现了这一条，请在创意工坊留言")
			end
		end
        return old_maprecorder_onsave(...)
    end

	-- local old_maprecorder_onload = inst.components.maprecorder.OnLoad
	-- inst.components.maprecorder.OnLoad = function(...)
	-- 	local result = old_maprecorder_onload(...)
	-- 	print("[global position (CompleteSync)] maprecorder loaded called")
	-- 	GLOBAL.maprecoder_load_func_called = true
	-- end
			

    -- local OnLoadPlayerMapdata = function(load_success, str)
    --     if load_success == true then
	-- 		print("[global position (CompleteSync)]success to load map data")
    --         inst.components.maprecorder.mapdata = str
	-- 		print(str)
	-- 	else
	-- 		print("[global position (CompleteSync)]failed to load map data")
    --     end
    -- end
	-- print("[global position (CompleteSync)]Before loading map data")
    -- GLOBAL.TheSim:GetPersistentString("player_mapdata", OnLoadPlayerMapdata)

end)
-- ************************ end of add maprecorder to world as a buffer ************************

-- GLOBAL.SetupGemCoreEnv()
print("[global position (CompleteSync)] This is a new version without GemCore")
-- GLOBAL.shardcomponent("shard_isgpsnewlyadded")
AddPrefabPostInit("shard_network", function(inst)
	inst:AddComponent("shard_isgpsnewlyadded")
end)

GLOBAL.world_data_is_empty = nil
GLOBAL.world_is_newly_created = false
-- GLOBAL.mod_newly_added_for_this_world = false
-- GLOBAL.maprecoder_load_func_called = false

-- ************************ Build event handler ************************
-- The world listen for the player spawn
AddPrefabPostInit("world", function(inst)
    -- TODO: the gap between str and map data should be resolved.
    -- TODO2: how about the migrate event?
	-- Check if the maprecorder is empty
	if inst.components.maprecorder.mapdata == nil then
		print("OLD[global position (CompleteSync)]The maprecorder is empty, are you starting a new game or adding this mod to old game?")
		GLOBAL.world_data_is_empty = true
	else
		print("OLD[global position (CompleteSync)]The maprecorder is not empty.")
		GLOBAL.world_data_is_empty = false
	end

    local OnMyPlayerJoined = function(world, player)
		print("[global position (CompleteSync)]Player joined")
        -- If empty world, learn from recorded data.
        local maprecorder = world.components.maprecorder
        if #GLOBAL.AllPlayers == 1 then
            learn_from_buffer(world, player)
        else
            for i, v in ipairs(GLOBAL.AllPlayers) do
                if v.userid == player.userid then
                    -- continue
                -- elseif v:HasTag("is_learning_from_buffer") then
                elseif v.is_learning_from_buffer or (not v.success_to_learn_map) then
                    -- continue
                    -- print("[GLOBAL POSITION(CompleteSync)] An exception happen, please leave a comment in the workshop page if you see this line")
                else
                    player2player_via_buffer(world, v, player)
                    return
                end
            end
            learn_from_buffer(world, player)
        end
    end
    inst:ListenForEvent("ms_playerjoined", OnMyPlayerJoined, GLOBAL.TheWorld)


	local OnMyPlayerActivated = function(world, player)
		print("[global position (CompleteSync)]Player activated")
		if not GLOBAL.TheNet:GetIsServer() then
			-- if player.userid == GLOBAL.ThePlayer.userid then
			print("[global position (CompleteSync)] sending RPC")
			SendModRPCToServer(GetModRPC(modname, "ClientPlayerJoined"))
			-- end
		else
			print("[global position (CompleteSync)] server also got activated event, but do nothing.")
		end
	end
	inst:ListenForEvent("playeractivated", OnMyPlayerActivated, GLOBAL.TheWorld)

    local OnMyPlayerDespawn = function(world, player)
		print("[global position (CompleteSync)]Player despawned")
		if not player.success_to_learn_map then
			print("[global position (CompleteSync)]Player failed to learn map data. so not save to buffer.")
			player.success_to_learn_map = false
			return
		else
        	save_to_buffer(world, player)
		end
    end
    local OnMyPlayerDespawnAndDelete = function(world, player)
		print("[global position (CompleteSync)]Player despawned and delete")
		if not player.success_to_learn_map then
			print("[global position (CompleteSync)]Player failed to learn map data. so not save to buffer.")
			player.success_to_learn_map = false
			return
		else
        	save_to_buffer(world, player)
		end
    end
    local OnMyPlayerDespawnAndMigrate = function(world, data)
		print("[global position (CompleteSync)]Player despawned and migrate")
		if not data.player.success_to_learn_map then
			print("[global position (CompleteSync)]Player failed to learn map data. so not save to buffer.")
			data.player.success_to_learn_map = false
			return
		else
        	save_to_buffer(world, data.player)
		end
    end
    inst:ListenForEvent("ms_playerdespawn", OnMyPlayerDespawn, GLOBAL.TheWorld)
    inst:ListenForEvent("ms_playerdespawnanddelete", OnMyPlayerDespawnAndDelete, GLOBAL.TheWorld)
    inst:ListenForEvent("ms_playerdespawnandmigrate", OnMyPlayerDespawnAndMigrate, GLOBAL.TheWorld)
end)

AddPlayerPostInit(function(player)
	print("[global position (CompleteSync)]In my AddPlayerPostInit")
	old_save_for_reroll = player.SaveForReroll
	player.SaveForReroll = function(self)
		print("[global position (CompleteSync)]In my SaveForReroll")
		-- save_to_buffer(GLOBAL.TheWorld, self)
		local rerollData = old_save_for_reroll(self)
		if GLOBAL.TheWorld.shard.components.shard_isgpsnewlyadded:CanDeleteUserMap() then
			print("[global position (CompleteSync)] now delete map info from user when rerolling")
			if rerollData then
				rerollData.maps = nil
			end
		else
			print("[global position (CompleteSync)] Can not delete map info from user, still, save map data when rolling")
		end
		return rerollData
	end
end)
-- ************************ end of build event handler ************************

-- ************************ share map codes ************************
-- This codes is inspired by the mod "Global Positions Remapped"
-- AddPlayerPostInit(function(inst)

--     if GLOBAL.TheWorld.ismastersim then
--         inst.icon = GLOBAL.SpawnPrefab("globalmapicon")
--         inst.icon:TrackEntity(inst)
--         inst:AddComponent("maprevealer")
-- 		if inst.prefab == "willow" then
--         	inst.components.maprevealer.revealperiod = 0.5
-- 		end
--     end

-- 	-- the `inst.entity:SetCanSleep(false)` will cause bugs related to wiilow's lighter

--     local OnDeath = function() 
--         inst.components.maprevealer:Stop() 
--     end
--     local OnRespawn = function()
--         inst.components.maprevealer:Start()
--      end

--     inst:ListenForEvent("ms_becameghost", OnDeath)
--     inst:ListenForEvent("ms_respawnedfromghost", OnRespawn)
-- end)
-- ************************ end of share map codes ************************

-- ************************ code for debug the maprevealer ************************

-- AddComponentPostInit("maprevealer", function(inst)
--     inst.RevealMapToPlayer = function(self, player)
-- 		if player._PostActivateHandshakeState_Server ~= GLOBAL.POSTACTIVATEHANDSHAKE.READY then
-- 			return -- Wait until the player client is ready and has received the world size info.
-- 		end

-- 		if USE_OPTIMIZER then
-- 			local x, y, z = self.inst.Transform:GetWorldPosition()
-- 			local optimizer = GLOBAL.TheWorld.components.maprevealoptimizer
			
-- 			-- If the optimizer exists and says the reveal is not necessary, skip it.
-- 			if optimizer and not optimizer:IsNecessary(x, z) then
-- 				return
-- 			end
-- 		end

--         if player.player_classified ~= nil and player.client_is_ready then
-- 			local x, y, z = self.inst.Transform:GetWorldPosition()
-- 			-- Reveal the area first.
-- 			player.player_classified.MapExplorer:RevealArea(x, y, z)
			
-- 			-- Then, if the optimizer exists, mark this area as revealed.
-- 			if USE_OPTIMIZER then
-- 				local optimizer = GLOBAL.TheWorld.components.maprevealoptimizer
-- 				if optimizer then
-- 					optimizer:MarkRevealed(x, z)
-- 				end
-- 			end
--         end
--     end
-- end)

if GLOBAL_COURIER then
	AddPlayerPostInit(function(player)
		local maprevealable = player.components.maprevealable
		if maprevealable then
			if maprevealable.task ~= nil then
				maprevealable.task:Cancel()
				maprevealable.task = nil
			end
			maprevealable:StartRevealing()
		else
			print("[global position (CompleteSync)] Why? maprevealable is nil")
		end
	end)
end
-- ************************ end of code for debug the maprevealer ************************

-- ************************ code for sharing the map from mapspotrevealer ************************
local keep_trying_reveal
keep_trying_reveal = function(player, x, y, z)
	if player.client_is_ready then
		player.player_classified.MapExplorer:RevealArea(x, y, z, true, true)
	else
		print("player.client_is_ready is false before revealing in mapspotrevealer")
		player:DoTaskInTime(1, function()
			keep_trying_reveal(player, x, y, z)
		end)
	end
end
AddComponentPostInit("mapspotrevealer", function(self)
    -- local old_revealmap = self.RevealMap
    self.RevealMap = function(self, doer)
        local FRAMES = GLOBAL.FRAMES
        if self.prerevealfn ~= nil then
            local allow_mapreveal = self.prerevealfn(self.inst, doer)
    
            if allow_mapreveal == false then
                return true
            end
        end
    
        if self.gettargetfn == nil then
            return false, "NO_TARGET"
        end
    
        local targetpos, reason = self.gettargetfn(self.inst, doer)
    
        if not targetpos then
            return targetpos, reason
        end
    
        local x, y, z = targetpos.x, targetpos.y, targetpos.z
    
        if not x then
            return false, "NO_TARGET"
        end
    
        self.inst:PushEvent("on_reveal_map_spot_pre", targetpos)
    
        if doer.player_classified ~= nil then
            if self.open_map_on_reveal then
                doer.player_classified.revealmapspot_worldx:set(x)
                doer.player_classified.revealmapspot_worldz:set(z)
                doer.player_classified.revealmapspotevent:push()
            end
    
            doer:DoStaticTaskInTime(4*FRAMES, function()
                doer.player_classified.MapExplorer:RevealArea(x, y, z, true, true)
            end)

            -- my add, reveal others map, this have some overhead.
            for i, v in ipairs(GLOBAL.AllPlayers) do
                -- print("revealing "..v.userid)
                -- doer:DoTaskInTime(1, function()
                --     player2player_via_buffer(GLOBAL.TheWorld, doer, v)
                -- end)
				if v~=nil and v.player_classified~=nil and v.player_classified.MapExplorer~=nil then
					v:DoStaticTaskInTime(4*FRAMES, function()
						-- v.player_classified.MapExplorer:RevealArea(x, y, z, true, true)
						keep_trying_reveal(v, x, y, z)
					end)
				end
            end

        else
            return false, "NO_MAP"
        end
    
        self.inst:PushEvent("on_reveal_map_spot_pst", targetpos)
    
        return true
    end
end)

-- ************************ end of code for sharing the map from mapspotrevealer ************************

-- ************************ code for dealing with glitchy mapicon ************************
local remove_ghost_icons = GetModConfigData("REMOVE_GHOST_ICONS")
if remove_ghost_icons then
	-- These corrections should be done by Klei, but they are not done yet.
	AddPrefabPostInit("bernie_big", function(inst) 
		inst.MiniMapEntity:SetCanUseCache(false) 
		if GLOBAL.TheWorld.ismastersim then
			inst:AddComponent("maprevealable")
			inst.components.maprevealable:SetIconPrefab("globalmapiconunderfog")
		end
	end)
	local function show_minimap(inst)
		inst.icon = GLOBAL.SpawnPrefab("globalmapiconunderfog")
		inst.icon:TrackEntity(inst)
	end
	AddPrefabPostInit("bernie_inactive", function(inst)
		if GLOBAL.TheWorld.ismastersim then
			inst:DoTaskInTime(0, show_minimap)
		end
	end)
	AddPrefabPostInit("bernie_active", function(inst)
		if GLOBAL.TheWorld.ismastersim then
			inst:DoTaskInTime(0, show_minimap)
		end
	end)

	-- TODO: perhaps only disable cache for domesticated beefalo, current may conflict with other mods (like those add icons for beefalo herds)
	AddPrefabPostInit("beefalo", function(inst) inst.MiniMapEntity:SetCanUseCache(false) end)
	-- AddPrefabPostInit("beefalo", function(inst)
	-- 	local old_updatedomestication = inst.UpdateDomestication
	-- 	inst.UpdateDomestication = function(self)
	-- 		print("updating domestication")
	-- 		if inst.components.domesticatable:IsDomesticated() then
	-- 			print("Do not cache")
	-- 			inst.MiniMapEntity:SetEnabled(false)
	-- 			inst.MiniMapEntity:SetCanUseCache(false)
	-- 			inst.MiniMapEntity:SetEnabled(true)
	-- 		else
	-- 			print("Can cache")
	-- 			inst.MiniMapEntity:SetEnabled(false)
	-- 			inst.MiniMapEntity:SetCanUseCache(false)
	-- 			inst.MiniMapEntity:SetEnabled(true)
	-- 		end
	-- 		old_updatedomestication(self)
	-- 	end
	-- end)
	-- need to add icon for beef_bell, this is the canonical way to do it, like chester.
	-- TODO: only add icon for linked beef bell
	table.insert(Assets, Asset("IMAGE", "minimap/beef_bell_linked.tex"))
	table.insert(Assets, Asset("ATLAS", "minimap/beef_bell_linked.xml"))
	AddMinimapAtlas("minimap/beef_bell_linked.xml")
	table.insert(Assets, Asset("IMAGE", "minimap/shadow_beef_bell_linked.tex"))
	table.insert(Assets, Asset("ATLAS", "minimap/shadow_beef_bell_linked.xml"))
	AddMinimapAtlas("minimap/shadow_beef_bell_linked.xml")
	AddPrefabPostInit("beef_bell", function(inst)
		if inst.MiniMapEntity == nil then
			inst.entity:AddMiniMapEntity()
		end
		inst.MiniMapEntity:SetIcon("beef_bell_linked.tex")
		inst.MiniMapEntity:SetPriority(7)
	end)
	AddPrefabPostInit("shadow_beef_bell", function(inst) 
		if inst.MiniMapEntity == nil then
			inst.entity:AddMiniMapEntity()
		end
		inst.MiniMapEntity:SetIcon("shadow_beef_bell_linked.tex")
		inst.MiniMapEntity:SetPriority(7)
	end)
end
-- ************************ end of code for dealing with glitchy mapicon ************************

--#rezecib this makes this available outside of the modmain
-- (it will be checked in globalposition_classified)
GLOBAL._GLOBALPOSITIONS_SHAREMINIMAPPROGRESS = SHAREMINIMAPPROGRESS
GLOBAL._GLOBALPOSITIONS_SHOWPLAYERICONS = SHOWPLAYERICONS
GLOBAL._GLOBALPOSITIONS_SHOWFIREICONS = SHOWFIREICONS
GLOBAL._GLOBALPOSITIONS_SHOWPLAYERINDICATORS = SHOWPLAYERINDICATORS

--#rezecib this is needed to make sure the normal ones disappear when you get far enough
-- (don't want to be clogging the screen with arrows, so only show the global ones
--  on the scoreboard screen)
local oldmaxrange = GLOBAL.TUNING.MAX_INDICATOR_RANGE
local oldmaxrangesq = (oldmaxrange*1.5)*(oldmaxrange*1.5)

--#rezecib this actually only affects the scaling/transparency of the badges
-- so I set it fairly low so you can see approximately how far they are from you
-- when in reasonable ranges
GLOBAL.TUNING.MAX_INDICATOR_RANGE = 2000

AddPrefabPostInit("forest_network", function(inst) inst:AddComponent("globalpositions") end)
AddPrefabPostInit("cave_network", function(inst) inst:AddComponent("globalpositions") end)

AddComponentPostInit("pointofinterest", function(inst)
	local new_distance_checker = function(inst, distsq)
    	return distsq >= TUNING.MIN_INDICATOR_RANGE and distsq <= oldmaxrange
	end
	inst.ShouldShowHudIndicator = new_distance_checker
end)

local function NewPlayerShouldTrackfn(inst, viewer)
    return  inst:IsValid() and
        not inst:HasTag("noplayerindicator") and
        not inst:HasTag("hiding") and
        inst:IsNear(viewer, oldmaxrange * 1.5) and
        not inst.entity:FrustumCheck() and
        GLOBAL.CanEntitySeeTarget(viewer, inst)
end

AddPlayerPostInit(function(inst)
    if not GLOBAL.TheNet:IsDedicated() then
        inst.components.hudindicatable:SetShouldTrackFunction(NewPlayerShouldTrackfn)
    end
end)

local function NewWagStaffNPCShouldTrackfn(inst, viewer)
    return inst:IsValid() and
        viewer:HasTag("wagstaff_detector") and
        inst:IsNear(inst, oldmaxrange * 1.5) and
        not inst.entity:FrustumCheck() and
        GLOBAL.CanEntitySeeTarget(viewer, inst)
end

AddPrefabPostInit("wagstaff_npc", function(inst)
	if not GLOBAL.TheNet:IsDedicated() then
        inst.components.hudindicatable:SetShouldTrackFunction(NewWagStaffNPCShouldTrackfn)
    end
end)

AddPrefabPostInit("wagstaff_npc_pstboss", function(inst)
	if not GLOBAL.TheNet:IsDedicated() then
        inst.components.hudindicatable:SetShouldTrackFunction(NewWagStaffNPCShouldTrackfn)
    end
end)

if NETWORKPLAYERPOSITIONS then
	--#rezecib this is an alternative to AddPlayerPostInit that avoids the overhead added to all prefabs
	-- note that it only runs on the server, but for our purposes this is what we want
	local is_dedicated = GLOBAL.TheNet:IsDedicated()
	local function PlayerPostInit(TheWorld, player)
		player:ListenForEvent("setowner", function()
			player:AddComponent("globalposition")
		end)
	end
	AddPrefabPostInit("world", function(inst)
		inst:ListenForEvent("ms_playerspawn", PlayerPostInit)
	end)

	AddSimPostInit(function()
		-- print("checking state and time")
		-- print(GLOBAL.TheWorld.state.time)
		-- print(GLOBAL.TheWorld.state.cycles)
		-- if GLOBAL.TheWorld.state.time < 0.01 and GLOBAL.TheWorld.state.cycles < 1 then
		-- 	GLOBAL.world_is_newly_created = true
		-- end

		print("in worldprefab postinit")
		if GLOBAL.TheWorld.ismastershard then
			if GLOBAL.TheWorld.state.time < 0.01 and GLOBAL.TheWorld.state.cycles < 1 then
				print("[global position (CompleteSync)]The world is newly created")
				-- print("[global position (CompleteSync)]The world time is "..tostring(GLOBAL.TheWorld.state.time))
				-- print("[global position (CompleteSync)]The world cycles is "..tostring(GLOBAL.TheWorld.state.cycles))
				GLOBAL.world_is_newly_created = true
			else
				print("[global position (CompleteSync)]The world is not newly created")
				GLOBAL.world_is_newly_created = false
			end

			if GLOBAL.TheWorld.components.maprecorder.mapdata == nil then
				print("[global position (CompleteSync)]The maprecorder is empty, are you starting a new game or adding this mod to old game?")
				GLOBAL.world_data_is_empty = true
			else
				print("[global position (CompleteSync)]The maprecorder is not empty.")
				GLOBAL.world_data_is_empty = false
			end

			if GLOBAL.world_data_is_empty and not GLOBAL.world_is_newly_created then
				GLOBAL.TheWorld.shard.components.shard_isgpsnewlyadded:SetIsAddMidway()
			else
			end
		end
	end)
	
	-- TheWorld can only have its own map on a dedicated server
	if SHAREMINIMAPPROGRESS and is_dedicated then
		-- On a dedicated server, maintain a separate copy of all shared map
		-- This ensures that map revealed by players who have sharing off never gets shared
		-- unfortunately this is not possible on client-servers
		MapRevealer = require("components/maprevealer")
		
		-- MapRevealer_ctor = MapRevealer._ctor
		-- MapRevealer._ctor = function(self, inst)
		-- 	self.counter = 1
		-- 	MapRevealer_ctor(self, inst)
		-- end
		
		-- MapRevealer_RevealMapToPlayer = MapRevealer.RevealMapToPlayer
		-- MapRevealer.RevealMapToPlayer = function(self, player)
		-- 	MapRevealer_RevealMapToPlayer(self, player)
		-- 	self.counter = self.counter + 1
		-- 	if self.counter > #GLOBAL.AllPlayers then
		-- 		self.counter = 1
		-- 	end
		-- end
	end
end

--Adding the stuff for signal fires
local function FirePostInit(inst, offset)
	if GLOBAL.TheWorld.ismastersim then
		inst:AddComponent("smokeemitter")
		inst.smoke_emitter_offset = offset
		local duration = 0
		if NEEDCHARCOAL then
			local OldTakeFuelItem = inst.components.fueled.TakeFuelItem
			inst.components.fueled.TakeFuelItem = function(self, item, ...)
				if type(item) == 'table' and item.prefab == "charcoal" and self:CanAcceptFuelItem(item) then
					duration = duration + item.components.fuel.fuelvalue * self.bonusmult
					-- we don't want it to ever go higher than the max burn of a firepit
					-- note that this can result in smoking after burning, but this actually
					-- makes some real-world sense, so I left it in
					duration = math.min(360, duration)
					inst.components.smokeemitter:Enable(duration)
				end
				return OldTakeFuelItem(self, item, ...)
			end
		else
			local OldIgnite = inst.components.burnable.Ignite
			inst.components.burnable.Ignite = function(...)
				OldIgnite(...)
				inst.components.smokeemitter:Enable()
			end
			local OldExtinguish = inst.components.burnable.Extinguish
			inst.components.burnable.Extinguish = function(...)
				OldExtinguish(...)
				inst.components.smokeemitter:Disable()
			end
			if inst.components.burnable.burning then
				inst.components.burnable:Ignite()
			end
		end
	end
end
--Don't even bother adding it unless we have signal fires enabled
if SHOWFIRES then
	AddPrefabPostInit("campfire", function(inst) FirePostInit(inst) end)
	AddPrefabPostInit("firepit", function(inst) FirePostInit(inst) end)
	local deluxe_campfires_installed = false
	for k,v in pairs(GLOBAL.KnownModIndex:GetModsToLoad()) do
		deluxe_campfires_installed = deluxe_campfires_installed or v == "workshop-444235588"
	end
	if deluxe_campfires_installed then
		AddPrefabPostInit("deluxe_firepit", function(inst) FirePostInit(inst, {x=350,y=-350}) end)
		AddPrefabPostInit("heat_star", function(inst) FirePostInit(inst, {x=230,y=-230}) end)
	end
end

if GLOBAL.TheNet:GetIsServer() then
	--have to fix the normal indicators sticking around forever on the server
	PlayerTargetIndicator = require("components/playertargetindicator")
	
	local function ShouldRemove(x, z, v)
		local vx, vy, vz = v.Transform:GetWorldPosition()
		return GLOBAL.distsq(x, z, vx, vz) > oldmaxrangesq
	end
	
	local OldOnUpdate = PlayerTargetIndicator.OnUpdate
	function PlayerTargetIndicator:OnUpdate(...)
		local ret = OldOnUpdate(self, ...)
		local x, y, z = self.inst.Transform:GetWorldPosition()
		for i,v in ipairs(self.offScreenPlayers) do
			while ShouldRemove(x, z, v) do
				self.inst.HUD:RemoveTargetIndicator(v)
				GLOBAL.table.remove(self.offScreenPlayers, i)
				v = self.offScreenPlayers[i]
				if v == nil then break end
			end
		end
		return ret
	end
end

local USERFLAGS = GLOBAL.USERFLAGS
local checkbit = GLOBAL.checkbit
local DST_CHARACTERLIST = GLOBAL.DST_CHARACTERLIST
local MODCHARACTERLIST = GLOBAL.MODCHARACTERLIST
local MOD_AVATAR_LOCATIONS = GLOBAL.MOD_AVATAR_LOCATIONS

-- Using the require approach so that we can modify the class table directly, instead
-- of AddClassPostConstruct, which patches the instances after each initialization;
-- this allows us to get at errors/warnings that would otherwise pop up in the constructor (_ctor),
-- and is also generally more efficient because it runs once
TargetIndicator = require("widgets/targetindicator")
local OldTargetIndicator_ctor = TargetIndicator._ctor
TargetIndicator._ctor = function(self, owner, target, ...)
	OldTargetIndicator_ctor(self, owner, target, ...)
	if type(target.userid) == "userdata" then
		self.is_character = true
		self.inst.startindicatortask:Cancel()
		local updating = false
		local OldShow = self.Show
		function self:Show(...)
			if not updating then
				updating = true
				self.colour = self.target.playercolour
				self:StartUpdating()
			end
			return OldShow(self, ...)
		end
	end
end

-- Wrapping these in a function so they can get rechecked when portraitdirty events are pushed
-- (normal target indicators actually don't check after being created)
function TargetIndicator:IsGhost()
	return self.userflags and checkbit(self.userflags, USERFLAGS.IS_GHOST)
end
-- AFK flag not used yet, but futureproofing and stuff
function TargetIndicator:IsAFK()
	return self.userflags and checkbit(self.userflags, USERFLAGS.IS_AFK)
end
function TargetIndicator:IsCharacterState1()
	return self.userflags and checkbit(self.userflags, USERFLAGS.CHARACTER_STATE_1)
end
function TargetIndicator:IsCharacterState2()
	return self.userflags and checkbit(self.userflags, USERFLAGS.CHARACTER_STATE_2)
end

-- This is for the target indicator images; map icons inherit directly from the prefab
local TARGET_INDICATOR_ICONS = {
	-- atlas is left nil if the image is in inventoryimages
	-- image is left nil if the image is just the key.tex
	-- for example, setting both fields for campfire to nil results in these values:
	-- campfire = {atlas = "images/inventoryimages.xml", image = "campfire.tex"}
	ping_generic = {atlas = "images/Ping.xml", image = "Ping.tex"},
	ping_danger = {atlas = "images/PingDanger.xml", image = "PingDanger.tex"},
	ping_omw = {atlas = "images/PingOmw.xml", image = "PingOmw.tex"},
	ping_explore = {atlas = "images/PingExplore.xml", image = "PingExplore.tex"},
	ping_gohere = {atlas = "images/PingGoHere.xml", image = "PingGoHere.tex"},
}
if SHOWFIRES then
    TARGET_INDICATOR_ICONS.campfire = {atlas = nil, image = nil}
    TARGET_INDICATOR_ICONS.firepit = {atlas = nil, image = nil}
    TARGET_INDICATOR_ICONS.deluxe_firepit = {atlas = "images/inventoryimages/deluxe_firepit.xml", image = nil}
    TARGET_INDICATOR_ICONS.heat_star = {atlas = "images/inventoryimages/heat_star.xml", image = nil}
end
-- Expose this so that other mods can add data for things they want to have icons/indicators for
GLOBAL._GLOBALPOSITIONS_TARGET_INDICATOR_ICONS = TARGET_INDICATOR_ICONS

local CH = lang == 'zh'
if ENABLEPINGS then
	GLOBAL.STRINGS.NAMES.PING_GENERIC = CH and "兴趣点" or "Point of Interest"
	GLOBAL.STRINGS.NAMES.PING_DANGER = CH and "这里危险" or "Danger"
	GLOBAL.STRINGS.NAMES.PING_OMW = CH and "正在路上" or "On My Way"
	GLOBAL.STRINGS.NAMES.PING_EXPLORE = CH and "探索这里" or "Explore Here"
	GLOBAL.STRINGS.NAMES.PING_GOHERE = CH and "去这里" or "Go Here"
end

local OldOnMouseButton = TargetIndicator.OnMouseButton
function TargetIndicator:OnMouseButton(button, down, ...)
	OldOnMouseButton(self, button, down, ...)
	-- Lets you dismiss the target indicator
	if button == GLOBAL.MOUSEBUTTON_RIGHT then
		-- this gets checked in the PlayerHud OnUpdate below
		self.onlyshowonscoreboard = true
	end
end

--#rezecib Most of this code is adapted from playerbadge
-- I used playerbadge because that is what's used on the scoreboard, which
-- also parses the TheNet:GetClientTable() to determine what it shows
local OldGetAvatarAtlas = TargetIndicator.GetAvatarAtlas
function TargetIndicator:GetAvatarAtlas(...)
	local CH = lang == 'zh'
	self.is_character = true
	if type(self.target.userid) == "userdata" then --this is a globalposition_classified
		local prefab = self.target.parentprefab:value()
		if self.target.userid:value() == "nil" then -- this isn't a player
			self.is_character = false
			self.prefabname = prefab
			if TARGET_INDICATOR_ICONS[prefab] then
				if self.name_label then
					self.name_label:SetString(self.target.name .. "\n" .. GLOBAL.STRINGS.RMB .. (CH and " 忽略" or " Dismiss"))
					-- self.name_label:SetString(self.target.name .. "\n" .. GLOBAL.STRINGS.RMB .. " Dismiss")
				end
			end
		else -- this is a player
			for k,v in pairs(GLOBAL.TheNet:GetClientTable() or {}) do -- find the right player
				if self.target.userid:value() == v.userid then -- this is the right player
					if self.prefabname ~= prefab then
						self.is_mod_character = false
						if not table.contains(DST_CHARACTERLIST, prefab)
						and not table.contains(MODCHARACTERLIST, prefab) then
							self.prefabname = "" -- this shouldn't happen
						else
							self.prefabname = prefab
							if table.contains(MODCHARACTERLIST, prefab) then
								self.is_mod_character = true
							end
						end
					end
					if self.userflags ~= v.userflags then
						self.userflags = v.userflags
					end
				end
			end
		end
		if self.is_character and self.is_mod_character and not self:IsAFK() then
			local location = MOD_AVATAR_LOCATIONS["Default"]
			if MOD_AVATAR_LOCATIONS[self.prefabname] ~= nil then
				location = MOD_AVATAR_LOCATIONS[self.prefabname]
			end
			
			local starting = "avatar_"
			if self:IsGhost() then
				starting = starting .. "ghost_"
			end
			
			local ending = ""
			if self:IsCharacterState1() then
				ending = "_1"
			end		
			if self:IsCharacterState2() then
				ending = "_2"
			end
			
			return location .. starting .. self.prefabname .. ending .. ".xml"
		elseif not self.is_character then
			return (TARGET_INDICATOR_ICONS[self.prefabname]
				and TARGET_INDICATOR_ICONS[self.prefabname].atlas)
				or "images/inventoryimages.xml"
		end
		return "images/avatars.xml"
	else
		return OldGetAvatarAtlas(self, ...)
	end
end
local OldGetAvatar = TargetIndicator.GetAvatar
function TargetIndicator:GetAvatar(...)
	if type(self.target.userid) == "userdata" then --this is a globalposition_classified
		local prefab = self.target.parentprefab:value()
		if self.is_mod_character and not self:IsAFK() then
			local starting = "avatar_"
			if self:IsGhost() then
				starting = starting .. "ghost_"
			end
			
			local ending = ""
			if self:IsCharacterState1() then
				ending = "_1"
			end		
			if self:IsCharacterState2() then
				ending = "_2"
			end
			
			return starting .. self.prefabname .. ending .. ".tex"
		elseif not self.is_character then
			return (TARGET_INDICATOR_ICONS[self.prefabname]
				and TARGET_INDICATOR_ICONS[self.prefabname].image)
				or self.prefabname .. ".tex"
		else
			if self.ishost and self.prefabname == "" then
				return "avatar_server.tex"
			elseif self:IsAFK() then
				return "avatar_afk.tex"
			elseif self:IsGhost() then
				return "avatar_ghost_"..(self.prefabname ~= "" and self.prefabname or "unknown")..".tex"
			else
				return "avatar_"..(self.prefabname ~= "" and self.prefabname or "unknown")..".tex"
			end				
		end
	else
		return OldGetAvatar(self, ...)
	end
end

-- The  in globalposition_classified (GPC) should really be handling this,
-- but for some reason sometimes an invalid GPC still gets its target indicator updated,
-- and this causes a crash
OldTargetIndicatorOnUpdate = TargetIndicator.OnUpdate
function TargetIndicator:OnUpdate()
	if self.target:IsValid() then
		OldTargetIndicatorOnUpdate(self)
	else
		-- If this gets spammed in logs then there's a real problem
		-- Otherwise this is just a hacky fix to a rare and temporary scenario
		-- print("GlobalPositions warning: Invalid GPC")
	end
end

AddClassPostConstruct("screens/playerhud", function(PlayerHud)
	PlayerHud.targetindicators = {}
	local mastersim = GLOBAL.TheNet:GetIsServer()
	local OldSetMainCharacter = PlayerHud.SetMainCharacter
	function PlayerHud:SetMainCharacter(...)
		local ret = OldSetMainCharacter(self, ...)
		local client_table = GLOBAL.TheNet:GetClientTable() or {}
		for k,v in pairs(GLOBAL.TheWorld.net.components.globalpositions.positions) do
			if v.userid:value() == "nil" and TARGET_INDICATOR_ICONS[v.parentprefab:value()] then
				self:AddTargetIndicator(v)
				self.targetindicators[#self.targetindicators]:Hide()
				v:UpdatePortrait()
			end
			--for each global position already added to the table...
			if SHOWPLAYERINDICATORS then
				for j,w in pairs(client_table) do
					if v.userid:value() == w.userid -- find the corresponding player...
					and w.userid ~= self.owner.userid then -- but not the local player...
						v.playercolor = w.colour
						v.name = w.name
						self:AddTargetIndicator(v)
						self.targetindicators[#self.targetindicators]:Hide()
						v:UpdatePortrait()
					end
				end
			end
		end
		return ret
	end
		
	--Basically the following two functions cause it to find the matching globalposition_classified's
	-- indicator, and tell it to be hidden while the normal indicator is up.
	local OldAddTargetIndicator = PlayerHud.AddTargetIndicator
	function PlayerHud:AddTargetIndicator(target, data)
		if type(target.userid) ~= "userdata" then --this is a normal player target indicator
			for k,v in pairs(self.targetindicators) do
				if type(v.target.userid) == "userdata" and v.target.userid:value() == target.userid then
					-- this is a target indicator for the same player's globalposition_classified
					v.hidewhileclose = true
				end
			end
		end
		OldAddTargetIndicator(self, target, data)
	end
	local OldRemoveTargetIndicator = PlayerHud.RemoveTargetIndicator
	function PlayerHud:RemoveTargetIndicator(target)
		if type(target.userid) ~= "userdata" then --this is a normal player target indicator
			for k,v in pairs(self.targetindicators) do
				if type(v.target.userid) == "userdata" and v.target.userid:value() == target.userid then
					-- this is a target indicator for the same player's globalposition_classified
					v.hidewhileclose = false
				end
			end
		end
		OldRemoveTargetIndicator(self, target)
	end
	
	local OldOnUpdate = PlayerHud.OnUpdate
	function PlayerHud:OnUpdate(...)
		local ret = OldOnUpdate(self, ...)
		local onscreen = {}
		if self.owner and self.owner.components and self.owner.components.playertargetindicator then
			onscreen = self.owner.components.playertargetindicator.onScreenPlayersLastTick
		end
		if self.targetindicators then
			for j,w in pairs(self.targetindicators) do --for each target indicator...
				local show = true
				if type(w.target.userid) == "userdata" then --if it's a globalposition_classified...
					-- globalpositions should only be shown on the scoreboard screen
					-- or if the show always option is set
					-- but we also don't want to have it showing when the normal indicator is,
					-- because that produces awful flickering
					show = SHOWPLAYERSALWAYS and (not w.hidewhileclose) or self:IsStatusScreenOpen()
					if not w.is_character then
						local parent_entity = w.target.parententity:value()
						show = not (parent_entity and parent_entity.entity:FrustumCheck())
						if w.onlyshowonscoreboard then
							show = show and self:IsStatusScreenOpen()
						end
					end
					for k,v in pairs(onscreen) do --check if its userid matches an onscreen player...
						if w.target.userid:value() == v.userid then
							show = false
						end
					end
					if w.is_character then 
						if self:IsStatusScreenOpen() then
							w.name_label:Show()
						elseif not w.focus then
							w.name_label:Hide()
						end
					end
					if GLOBAL.TheFrontEnd.mutedPlayers[w.target.parentuserid:value()] then
						show = false -- for pings from muted players
					end
				elseif mastersim then
					w:Hide()
				end
				if show then
					w:Show()
				else
					w:Hide()
				end
			end
		end
		return ret
	end
	
	local OldShowPlayerStatusScreen = PlayerHud.ShowPlayerStatusScreen
	function PlayerHud:ShowPlayerStatusScreen(...)
		local ret = OldShowPlayerStatusScreen(self, ...)
		self:OnUpdate(0.0001)
		return ret
	end
end)

--[[ Patch TheFrontEnd to track changes in muted players ]]--
require("frontend")
local OldFrontEnd_ctor = GLOBAL.FrontEnd._ctor
GLOBAL.FrontEnd._ctor = function(TheFrontEnd, ...)
	OldFrontEnd_ctor(TheFrontEnd, ...)
	TheFrontEnd.mutedPlayers = {DontDeleteMePlz = true} -- to prevent the table from getting deleted
end

--[[ Patch the map to allow names to show on hover-over and pings ]]--
local STARTSCALE = 0.25
local NORMSCALE = 1
local pingwheel = nil
local pingwheelup = false
local activepos = nil
local ReceivePing = nil
local ShowPingWheel = nil
local HidePingWheel = nil
local pings = {}
local checknumber = GLOBAL.checknumber
if ENABLEPINGS then
	ReceivePing = function(player, pingtype, x, y, z)
		-- Validate client input, because this could be arbitrary data of the wrong type or invalid prefabs
		if not (valid_ping_actions[pingtype] and checknumber(x) and checknumber(y) and checknumber(z)) then
			return
		end
		if pingtype == "delete" then
			--Find the nearest ping and delete it (if it was actually somewhat close)
			mindistsq, minping = math.huge, nil
			for _,ping in pairs(pings) do
				local px, py, pz = ping.Transform:GetWorldPosition()
				dq = GLOBAL.distsq(x, z, px, pz)
				if dq < mindistsq then
					mindistsq = dq
					minping = ping
				end
			end
			-- Check that their mouse is actually somewhat close to it first, ~20
			if mindistsq < 400 then
				pings[minping.GUID] = nil
				minping:Remove()
			end
		elseif pingtype == "clear" then
			for _,ping in pairs(pings) do
				ping:Remove()
			end
		else
            local prefab = "ping_"..pingtype
			-- This check is really crucial, because otherwise the server will crash if the prefab doesn't exist.
			-- SpawnPrefab also does some filtering on what prefabs can be spawned, specifically it seems to trim
			-- everything after the first slash, so if a malicious client sends a pingtype of /deerclops,
			-- it will literally spawn the Deerclops boss.
			if not GLOBAL.PrefabExists(prefab) then
				return
			end

			local ping = GLOBAL.SpawnPrefab(prefab)
			ping.OnRemoveEntity = function(inst) pings[inst.GUID] = nil end
			ping.parentuserid = player.userid
			ping.Transform:SetPosition(x,y,z)
			pings[ping.GUID] = ping
		end
	end
	AddModRPCHandler(modname, "Ping", ReceivePing)

	ShowPingWheel = function(position)
		if pingwheelup then return end
		pingwheelup = true
		SetModHUDFocus("PingWheel", true)
			
		activepos = position
		if GLOBAL.TheInput:ControllerAttached() then
			local scr_w, scr_h = GLOBAL.TheSim:GetScreenSize()
			pingwheel:SetPosition(scr_w/2, scr_h/2)
		else	
			pingwheel:SetPosition(GLOBAL.TheInput:GetScreenPosition():Get())
		end
		pingwheel:Show()
		pingwheel:ScaleTo(STARTSCALE, NORMSCALE, .25)
	end

	HidePingWheel = function(cancel)
		if not pingwheelup or activepos == nil then return end
		pingwheelup = false
		SetModHUDFocus("PingWheel", false)
		
		pingwheel:Hide()
		pingwheel.inst.UITransform:SetScale(STARTSCALE, STARTSCALE, 1)
					
		if pingwheel.activegesture and pingwheel.activegesture ~= "cancel" and not cancel then
			SendModRPCToServer(MOD_RPC[modname]["Ping"], pingwheel.activegesture, activepos:Get())
		end
		activepos = nil
	end
	GLOBAL.TheInput:AddMouseButtonHandler(function(button, down, x, y)
		if button == 1000 and not down then
			HidePingWheel()
		end
	end)
end

AddClassPostConstruct("widgets/mapwidget", function(MapWidget)
	-- Hoverers get their text from the owner's tooltip; we set the MapWidget to the owner
	MapWidget.nametext = require("widgets/maphoverer")()
	if ENABLEPINGS then
		MapWidget.pingwheel = require("widgets/pingwheel")()
		pingwheel = MapWidget.pingwheel
		pingwheel.radius = pingwheel.radius * 1.1
		pingwheel:Hide()
		pingwheel.inst.UITransform:SetScale(STARTSCALE, STARTSCALE, 1)
	end

	function MapWidget:OnUpdate(dt)
		if ENABLEPINGS then
			pingwheel:OnUpdate()
		end
		if not self.shown or pingwheelup then return end
		
		-- Begin copy-pasted code (small edits to match modmain environment)
		if GLOBAL.TheInput:IsControlPressed(GLOBAL.CONTROL_PRIMARY) then
			local pos = GLOBAL.TheInput:GetScreenPosition()
			if self.lastpos then
				local scale = 0.25
				local dx = scale * ( pos.x - self.lastpos.x )
				local dy = scale * ( pos.y - self.lastpos.y )
				self:Offset( dx, dy ) --#rezecib changed this so we can capture offsets
			end
			
			self.lastpos = pos
		else
			self.lastpos = nil
		end
		-- End copy-pasted code
		
		if SHOWPLAYERICONS then
			local p = self:GetWorldMousePosition()
			mindistsq, gpc = math.huge, nil
			for k,v in pairs(GLOBAL.TheWorld.net.components.globalpositions.positions) do
				if not GLOBAL.TheFrontEnd.mutedPlayers[v.parentuserid:value()] then--v.userid:value() ~= "nil" then -- this is a player's position
					local x, y, z = v.Transform:GetWorldPosition()
					dq = GLOBAL.distsq(p.x, p.z, x, z)
					if dq < mindistsq then
						mindistsq = dq
						gpc = v
					end
				end
			end
			-- Check that their mouse is actually somewhat close to them first
			if math.sqrt(mindistsq) < self.minimap:GetZoom()*10 then
				if self.nametext:GetString() ~= gpc.name then
					self.nametext:SetString(gpc.name)
					self.nametext:SetColour(gpc.playercolour)
				end
			else -- nobody is being moused over
				self.nametext:SetString("")
			end
		end
	end
	
	
	function MapWidget:GetWorldMousePosition()
		-- -- Get the screen size so we can figure out the position of the center
		-- local screenwidth, screenheight = GLOBAL.TheSim:GetScreenSize()
		-- -- But also adjust the center to the position of the player
		-- -- (this makes it so we only have to take into account camera angle once)
		-- local cx = screenwidth*.5 + self.offset.x*4.5
		-- local cy = screenheight*.5 + self.offset.y*4.5
		-- local mx, my = GLOBAL.TheInput:GetScreenPosition():Get()
		-- if GLOBAL.TheInput:ControllerAttached() then
		-- 	mx, my = screenwidth*.5, screenheight*.5
		-- end
		-- -- Calculate the offset of the mouse from the center
		-- local ox = mx - cx
		-- local oy = my - cy
		-- -- Calculate the world distance and world angle
		-- local angle = GLOBAL.TheCamera:GetHeadingTarget()*math.pi/180
		-- local wd = math.sqrt(ox*ox + oy*oy)*self.minimap:GetZoom()/4.5
		-- local wa = math.atan2(ox, oy) - angle
		-- -- Convert to world x and z coordinates, adding in the offset from the player
		-- local px, _, pz = GLOBAL.ThePlayer:GetPosition():Get()
		-- local wx = px - wd*math.cos(wa)
		-- local wz = pz + wd*math.sin(wa)
		-- return GLOBAL.Vector3(wx, 0, wz)

		-- copy from debugkeys.lua
		local mousepos = GLOBAL.TheInput:GetScreenPosition()
		if GLOBAL.TheInput:ControllerAttached() then
			local screenwidth, screenheight = GLOBAL.TheSim:GetScreenSize()
			local mx, my = screenwidth*.5, screenheight*.5
			mousepos = GLOBAL.Vector3(mx, my, 0)
		end
		local the_screen = self.parent
		if the_screen~=nil then
			local mousewidgetpos = the_screen:ScreenPosToWidgetPos( mousepos )
			local mousemappos = the_screen:WidgetPosToMapPos( mousewidgetpos )
	
			local x,y,z = self.minimap:MapPosToWorldPos( mousemappos:Get() )
			return GLOBAL.Vector3(x, 0, y)
		else
			return GLOBAL.Vector3(0, 0, 0)
		end
	end
end)

--[[ Patch the Map Screen to disable the hovertext when getting closed, and add ping interface]]--
AddClassPostConstruct("screens/mapscreen", function(MapScreen)
	if ENABLEPINGS and GLOBAL.TheInput:ControllerAttached() then
		MapScreen.ping_reticule = MapScreen:AddChild(GLOBAL.require("widgets/uianim")())
		MapScreen.ping_reticule:GetAnimState():SetBank("reticule")
		MapScreen.ping_reticule:GetAnimState():SetBuild("reticule")
		MapScreen.ping_reticule:GetAnimState():PlayAnimation("idle")
		MapScreen.ping_reticule:SetScale(.35)
		local screenwidth, screenheight = GLOBAL.TheSim:GetScreenSize()
		MapScreen.ping_reticule:SetPosition(screenwidth*.5, screenheight*.5)
	end

	local OldOnBecomeInactive = MapScreen.OnBecomeInactive
	function MapScreen:OnBecomeInactive(...)
		self.minimap.nametext:SetString("")
		if ENABLEPINGS then HidePingWheel(true) end -- consider it to be a cancellation
		OldOnBecomeInactive(self, ...)
	end
	
	if ENABLEPINGS then
		function MapScreen:OnMouseButton(button, down, ...)
			-- Alt-click
			if button == 1000 and down and GLOBAL.TheInput:IsControlPressed(GLOBAL.CONTROL_FORCE_INSPECT) then
				ShowPingWheel(self.minimap:GetWorldMousePosition())
			end
		end
		
		local OldOnControl = MapScreen.OnControl
		function MapScreen:OnControl(control, down, ...)
			if control == GLOBAL.CONTROL_MENU_MISC_4 then --right-stick click
				if down then
					ShowPingWheel(self.minimap:GetWorldMousePosition())
				else
					HidePingWheel()
				end
				return true
			end
			return OldOnControl(self, control, down, ...)
		end
		local OldGetHelpText = MapScreen.GetHelpText
		function MapScreen:GetHelpText(...)
			return OldGetHelpText(self, ...) .. "  " .. GLOBAL.TheInput:GetLocalizedControl(
				GLOBAL.TheInput:GetControllerID(), GLOBAL.CONTROL_MENU_MISC_4) .. " Ping"
		end
	end
end)

--[[ Capture nonstandard minimap icons for mod characters ]]--
--#rezecib code from Global Player Icons, by Sarcen (also see prefabs/globalplayericon.lua)
GLOBAL._GLOBALPOSITIONS_MAP_ICONS = {}

-- Hack to determine MiniMap icon names
for i,atlases in ipairs(GLOBAL.ModManager:GetPostInitData("MinimapAtlases")) do
	for i,path in ipairs(atlases) do
		local file = GLOBAL.io.open(GLOBAL.resolvefilepath(path), "r")
		if file then
			local xml = file:read("*a")
			if xml then
				for element in string.gmatch(xml, "<Element[^>]*name=\"([^\"]*)\"") do
					if element then
						local elementName = string.match(element, "^(.*)[.]")
						if elementName then
							GLOBAL._GLOBALPOSITIONS_MAP_ICONS[elementName] = element
						end
					end
				end
			end
			file:close()
		end
	end
end

for prefab,data in pairs(TARGET_INDICATOR_ICONS) do
	GLOBAL._GLOBALPOSITIONS_MAP_ICONS[prefab] = prefab .. ".tex"
end

for _,prefab in pairs(GLOBAL.DST_CHARACTERLIST) do
	GLOBAL._GLOBALPOSITIONS_MAP_ICONS[prefab] = prefab .. ".png"
end