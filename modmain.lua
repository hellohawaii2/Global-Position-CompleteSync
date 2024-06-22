local TUNING = GLOBAL.TUNING
TUNING.REMAPPED_MODE = TUNING.REMAPPED_MODE or GetModConfigData("mode") -- Ignore config if already set via other mods


-- ************************ Functions about mapdata update************************ 
local function save_to_buffer(world, player)
    local maprecorder = world.components.maprecorder
    local result, description = maprecorder:RecordMap(player)
end

local function learn_from_buffer(world, player)
    local maprecorder = world.components.maprecorder
    local result, description = maprecorder:KeepTryingTeach(player)
    -- maprecorder.inst.DoTaskInTime(maprecorder, 0, maprecorder.TeachMap, player)
end

local function player2player_via_buffer(world, player_from, player_to)
    save_to_buffer(world, player_from)
    learn_from_buffer(world, player_to)
end
-- ************************ end of functions about mapdata update ************************ 


-- ************************ Try to accelerate ************************ 

require("networking")
GLOBAL.SerializeUserSession = function (player, isnewspawn)
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
        if player.player_classified ~= nil and player.player_classified.entity then
            local player_mapexplorer = player.player_classified.MapExplorer or nil
            if player_mapexplorer ~= nil then
                local mapdata = player_mapexplorer:RecordMap()
                GLOBAL.TheSim:SetPersistentString("player_mapdata", mapdata, false)
            end
        end
        -- TODO: can I call "save to buffer" here to avoid bug produced by ctrl+C?
        -- save_to_buffer(GLOBAL.TheWorld, player)  -- This seems to bother the basic function. Do not use the shared buffer!
        GLOBAL.TheNet:SerializeUserSession(player.userid, data, isnewspawn == true, nil, metadataStr)
    end
end
-- ************************ End of Try to accelerate ************************ 

-- ************************ add maprecorder to world as a buffer ************************
AddPrefabPostInit("world", function(inst)
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
        if count > 30 then
            print("[global position (CompleteSync)]Wrong! Tried 30 times, but still failed to teach map to player")
            return
        end
        local result, description = maprecorder:TeachMap(player)
        if result == false then
            -- check is the description is "BLANK", if not, try again
            if description ~= "BLANK" then
                maprecorder.inst.DoTaskInTime(maprecorder, 1, KeepTryingTeach, player, count)
            end
        else
        end
    end

    inst.components.maprecorder.KeepTryingTeach = KeepTryingTeach

    local OnLoadPlayerMapdata = function(load_success, str)
        if load_success == true then
            inst.components.maprecorder.mapdata = str
        end
    end
    GLOBAL.TheSim:GetPersistentString("player_mapdata", OnLoadPlayerMapdata)

end)
-- ************************ end of add maprecorder to world as a buffer ************************

-- ************************ Build event handler ************************
-- The world listen for the player spawn
AddPrefabPostInit("world", function(inst)
    -- TODO: the gap between str and map data should be resolved.
    -- TODO2: how about the migrate event?
    local OnMyPlayerSpawn = function(world, player)
        -- If empty world, learn from recorded data.
        local maprecorder = world.components.maprecorder
        if #GLOBAL.AllPlayers == 1 then
            learn_from_buffer(world, player)
        else
            for i, v in ipairs(GLOBAL.AllPlayers) do
                if v.userid == player.userid then
                    -- continue
                else
                    player2player_via_buffer(world, v, player)
                    return
                end
            end
        end
    end
    inst:ListenForEvent("ms_playerspawn", OnMyPlayerSpawn, GLOBAL.TheWorld)

    local OnMyPlayerDespawn = function(world, player)
        save_to_buffer(world, player)
    end
    local OnMyPlayerDespawnAndDelete = function(world, player)
        save_to_buffer(world, player)
    end
    local OnMyPlayerDespawnAndMigrate = function(world, data)
        save_to_buffer(world, data.player)
    end
    inst:ListenForEvent("ms_playerdespawn", OnMyPlayerDespawn, GLOBAL.TheWorld)
    inst:ListenForEvent("ms_playerdespawnanddelete", OnMyPlayerDespawnAndDelete, GLOBAL.TheWorld)
    inst:ListenForEvent("ms_playerdespawnandmigrate", OnMyPlayerDespawnAndMigrate, GLOBAL.TheWorld)
end)
-- ************************ end of build event handler ************************

-- ************************ The orginal codes  of GLOBAL POSITION(REMAPPED) ************************
local function NewShouldTrackfn(inst, viewer)
    return  inst:IsValid() and
        not inst:HasTag("noplayerindicator") and
        not inst:HasTag("hiding") and
        inst:IsNear(viewer, TUNING.MAX_INDICATOR_RANGE * 1.5) and -- Originally checks inst:IsNear(inst, max_range), What's the point of that?
        not inst.entity:FrustumCheck() and
        GLOBAL.CanEntitySeeTarget(viewer, inst)
end

AddPlayerPostInit(function(inst)

    if GLOBAL.TheWorld.ismastersim then
        inst.icon = GLOBAL.SpawnPrefab("globalmapicon")
        if not inst:HasTag("playerghost") then
            inst.icon.MiniMapEntity:SetIsFogRevealer(true)
            inst.icon:AddTag("fogrevealer")
        end
        inst.icon:TrackEntity(inst)

        inst.entity:SetCanSleep(false)

        inst:AddComponent("maprevealer")
    end

    if not GLOBAL.TheNet:IsDedicated() then
        inst.components.hudindicatable:SetShouldTrackFunction(NewShouldTrackfn)
    end

    local OnDeath = function() inst.icon.MiniMapEntity:SetIsFogRevealer(false) inst.icon:RemoveTag("fogrevealer") inst.components.maprevealer:Stop() end
    local OnRespawn = function() inst.icon.MiniMapEntity:SetIsFogRevealer(true) inst.icon:AddTag("fogrevealer") inst.components.maprevealer:Start() end

    inst:ListenForEvent("ms_becameghost", OnDeath)
    inst:ListenForEvent("ms_respawnedfromghost", OnRespawn)
end)
-- ************************ end of the orginal codes  of GLOBAL POSITION(REMAPPED) ************************

-- ************************ code for sharing the map from mapspotrevealer ************************
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
                doer:DoTaskInTime(1, function()
                    player2player_via_buffer(GLOBAL.TheWorld, doer, v)
                end)
            end

        else
            return false, "NO_MAP"
        end
    
        self.inst:PushEvent("on_reveal_map_spot_pst", targetpos)
    
        return true
    end
end)

-- ************************ end of code for sharing the map from mapspotrevealer ************************


