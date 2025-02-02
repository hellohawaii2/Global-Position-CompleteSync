-- Modified from https://steamcommunity.com/sharedfiles/filedetails/?id=756229217 

------------------------------------------------------------------------
--[[ shard_isgpsnewlyadded ]]
--------------------------------------------------------------------------

return Class(function(self, inst)

    assert(TheWorld.ismastersim, "shard_isgpsnewlyadded should not exist on client")

    --------------------------------------------------------------------------
    --[[ Constants ]]
    --------------------------------------------------------------------------

    local MAX_TARGETS = 10

    --------------------------------------------------------------------------
    --[[ Member variables ]]
    --------------------------------------------------------------------------

    --Public
    self.inst = inst

    --Private
    local _world = TheWorld
    local _ismastershard = _world.ismastershard
    local _isaddmidway = net_bool(inst.GUID, "shard_isgpsnewlyadded._isaddmidway", "shard_isgpsnewlyadded._isaddmidwaydirty") -- value does not matter, everytime it is changed the slave sends data to master
    local _restoredworldnum = net_tinybyte(inst.GUID, "shard_isgpsnewlyadded._restoredworldnum", "shard_isgpsnewlyadded._restoredworldnumdirty") -- value does not matter, everytime it is changed the slave sends data to master
    -- Perhaps can not called too early
    local _totalsharded = 1
    print("Connected shards:")
    for k,v in pairs(Shard_GetConnectedShards()) do
        print("\t",k,v)
        _totalsharded = _totalsharded + 1
    end
    local _allworldrestored = net_bool(inst.GUID, "shard_isgpsnewlyadded._allworldrestored", "shard_isgpsnewlyadded._allworldrestoreddirty") -- value does not matter, everytime it is changed the slave sends data to master
    -- local _isaddmidway = net_event(inst.GUID, "shard_isgpsnewlyadded._isaddmidway")
    

    -- the following is used for debug
    self._isaddmidway = _isaddmidway
    self._restoredworldnum = _restoredworldnum
    self._totalsharded = _totalsharded
    self._allworldrestored = _allworldrestored
    --------------------------------------------------------------------------
    --[[ Private member functions ]]
    --------------------------------------------------------------------------
    
    -- local function SaveAndSendDataToMaster()
    --     print("SaveAndSendDataToMaster")
    --     if not _ismastershard then
    --         print("SaveAndSendDataToMaster slave")
    --         _world.components.worldjump:SavePlayerData() -- will save playerdata within worldjump.player_data_save
    --         local player_data_save = _world.components.worldjump.player_data_save
    --         SendShardRPCToServer(SHARD_RPC.TeleSerp.PlayerSave, player_data_save) -- send it to master (currently only identified by forest Tag...)
    --     end
    -- end
    

    
    --------------------------------------------------------------------------
    --[[ Initialization ]]
    --------------------------------------------------------------------------

    
    -- inst:ListenForEvent("shard_isgpsnewlyadded._isaddmidwaydirty", function(inst) -- fornet_bool if the master sends a request via netvar to the slaves, save our data and send them via rpc
    --     print("_isaddmidwaydirty")
    --     if not _ismastershard then -- only do it when you are not master
    --         if _isaddmidway:value()==true then
    --             print("_isaddmidwaydirty slave and set true")
    --             SaveAndSendDataToMaster()
    --         end
    --     end
    -- end)
    inst:ListenForEvent("shard_isgpsnewlyadded._restoredworldnumdirty", function(inst) -- fornet_tinybyte if the master sends a request via netvar to the slaves, save our data and send them via rpc
        print("[global position (CompleteSync)] _restoredworldnumdirty current value",_restoredworldnum:value())
    end)

    _isaddmidway:set(false)
    _restoredworldnum:set(0)
    _allworldrestored:set(false)
    
    --------------------------------------------------------------------------
    --[[ Public member functions ]]
    --------------------------------------------------------------------------
    
    function self:SetIsAddMidway()
        print("[global position (CompleteSync)] SetIsAddMidway")
        assert(_ismastershard, "SetIsAddMidway should only be called on master")
        _isaddmidway:set(true) -- simply change the value, the value itself does not matter,we only want to trigger the dirty functions
        -- _isaddmidway:push()
    end

    function self:IncreaseCounter()
        print("[global position (CompleteSync)] IncreaseCounter")
        if _ismastershard then
            local current = _restoredworldnum:value()
            -- print("[global position (CompleteSync)] current _restoredworldnum",current)
            _restoredworldnum:set(current+1)
            print("[global position (CompleteSync)] new _restoredworldnum",_restoredworldnum:value())
            local _totalsharded = 1
            -- print("Connected shards:")
            for k,v in pairs(Shard_GetConnectedShards()) do
                -- print("\t",k,v)
                _totalsharded = _totalsharded + 1
            end
            print("[global position (CompleteSync)] totalsharded",_totalsharded)
            if _restoredworldnum:value() == _totalsharded then
                print("[global position (CompleteSync)] All shards have been restored")
                -- SaveAndSendDataToMaster()
                _allworldrestored:set(true)
            end
        else
            local modname = "globalpositioncompletesync"
            SendModRPCToShard(GetShardModRPC(modname, "ShardIncreaseCounter"), nil)
        end

        -- _restoredworldnum:push()

        
    end

    function self:CanDeleteUserMap()
        return (not _isaddmidway:value()) or _allworldrestored:value()
    end
    
    
    --------------------------------------------------------------------------
    --[[ End ]]
    --------------------------------------------------------------------------
    
end)