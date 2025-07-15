local MapRevealOptimizer = Class(function(self, inst)
    self.inst = inst
    self.grid_size = 8
    
    -- Defer initialization until the map is ready.
    self.inst:DoTaskInTime(0, function() self:Initialize() end)
end)

function MapRevealOptimizer:Initialize()
    -- Prevent re-initialization
    -- if self.grid_width then return end

    if TheWorld.Map then
        local map_width, map_height = TheWorld.Map:GetWorldSize()
        -- Tile size is 4x4 units.
        self.world_width_units = map_width * TILE_SCALE
        self.world_height_units = map_height * TILE_SCALE

        -- Grid dimensions
        self.grid_width = math.ceil(self.world_width_units / self.grid_size)
        self.grid_height = math.ceil(self.world_height_units / self.grid_size)

        -- World coordinates are centered around (0,0), so we need an offset for array indices.
        self.offset_x = self.world_width_units / 2
        self.offset_z = self.world_height_units / 2
    end
    
    -- Initialize grid only if it wasn't loaded from a save
    if self.revealed_grid == nil then
        self.revealed_grid = {}
    end
end



function MapRevealOptimizer:OnLoad(data)
    if data and data.revealed_grid then
        self.revealed_grid = data.revealed_grid
    end
end
function MapRevealOptimizer:OnSave()
    return {
        revealed_grid = self.revealed_grid
    }
end

function MapRevealOptimizer:WorldToGrid(wx, wz)
    if not self.offset_x then return nil, nil end
    local gx = math.floor((wx + self.offset_x) / self.grid_size) + 1
    local gz = math.floor((wz + self.offset_z) / self.grid_size) + 1
    return gx, gz
end

-- This should be called after a map area has been successfully revealed.
function MapRevealOptimizer:MarkRevealed(wx, wz)
    -- self:Initialize() -- Ensure component is initialized
    if not self.grid_width then return end

    local gx, gz = self:WorldToGrid(wx, wz)
    if gx then
        if not self.revealed_grid[gx] then
            self.revealed_grid[gx] = {}
        end
        self.revealed_grid[gx][gz] = true
    end
end

-- Check if revealing a circular area is necessary.
function MapRevealOptimizer:IsNecessary(wx, wz)
    -- self:Initialize() -- Ensure component is initialized
    if not self.grid_width then return true end

    local gx, gz = self:WorldToGrid(wx, wz)
    if gx and self.revealed_grid[gx] and self.revealed_grid[gx][gz] then
        return false -- The grid cell for this center point has been revealed before.
    end

    return true -- It's a new grid cell, so the reveal is necessary.
end

return MapRevealOptimizer 