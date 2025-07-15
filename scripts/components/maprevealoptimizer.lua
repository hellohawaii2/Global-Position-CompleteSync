local MapRevealOptimizer = Class(function(self, inst)
    self.inst = inst
    -- The radius of map reveal, as per user request.
    self.radius = 50
    self.radius_sq = self.radius * self.radius
    self.grid_size = 10

    -- Do task in time
    self.inst.DoTaskInTime(self, 0, self.Initialize)
    -- TODO: will this initialzation influence the save and load?
end,
nil,
nil)

function MapRevealOptimizer:Initialize()
    print("[global position (CompleteSync)] MapRevealOptimizer:Initialize")
    if TheWorld.Map then
        print("[global position (CompleteSync)] MapRevealOptimizer:Initialize: TheWorld.Map")
        local map_width, map_height = TheWorld.Map:GetWorldSize()
        -- Tile size is 4x4 units.
        self.world_width_units = map_width * 4
        self.world_height_units = map_height * 4

        -- Grid dimensions
        self.grid_width = math.ceil(self.world_width_units / self.grid_size)
        self.grid_height = math.ceil(self.world_height_units / self.grid_size)

        -- World coordinates are centered around (0,0), so we need an offset for array indices.
        self.offset_x = self.world_width_units / 2
        self.offset_z = self.world_height_units / 2
        if self.revealed_grid then
            print("[global position (CompleteSync)] MapRevealOptimizer:Initialize: self.revealed_grid is not nil")
            return 
        else
            print("[global position (CompleteSync)] MapRevealOptimizer:Initialize: self.revealed_grid is nil, set to {}")
            self.revealed_grid = {}
        end
    end
end

function MapRevealOptimizer:OnLoad(data)
    print("[global position (CompleteSync)] MapRevealOptimizer:OnLoad")
    if data then
        print("[global position (CompleteSync)] MapRevealOptimizer:OnLoad: data is not nil")
        self.revealed_grid = data.revealed_grid or {}
    else
        print("[global position (CompleteSync)] MapRevealOptimizer:OnLoad: data is nil")
    end
end

function MapRevealOptimizer:OnSave()
    print("[global position (CompleteSync)] MapRevealOptimizer:OnSave")
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
    if not self.grid_width then return end

    local radius_in_grid = math.ceil(self.radius / self.grid_size)
    local center_gx, center_gz = self:WorldToGrid(wx, wz)
    if not center_gx then return end

    for i = -radius_in_grid, radius_in_grid do
        for j = -radius_in_grid, radius_in_grid do
            local gx = center_gx + i
            local gz = center_gz + j

            if gx >= 1 and gx <= self.grid_width and gz >= 1 and gz <= self.grid_height then
                -- Only mark the grid cell if it is COMPLETELY inside the circle.
                if not self.revealed_grid[gx] or not self.revealed_grid[gx][gz] then
                    local grid_min_wx = (gx - 1) * self.grid_size - self.offset_x
                    local grid_min_wz = (gz - 1) * self.grid_size - self.offset_z
                    local grid_max_wx = gx * self.grid_size - self.offset_x
                    local grid_max_wz = gz * self.grid_size - self.offset_z
                    
                    -- Check if all 4 corners of the grid cell are within the circle's radius.
                    if ((grid_min_wx - wx)^2 + (grid_min_wz - wz)^2 < self.radius_sq and
                        (grid_max_wx - wx)^2 + (grid_min_wz - wz)^2 < self.radius_sq and
                        (grid_min_wx - wx)^2 + (grid_max_wz - wz)^2 < self.radius_sq and
                        (grid_max_wx - wx)^2 + (grid_max_wz - wz)^2 < self.radius_sq) then

                        -- All 4 corners are inside the circle, so the cell is fully revealed.
                        if not self.revealed_grid[gx] then
                            self.revealed_grid[gx] = {}
                        end
                        self.revealed_grid[gx][gz] = true
                    end
                end
            end
        end
    end
end

-- Check if revealing a circular area is necessary.
function MapRevealOptimizer:IsNecessary(wx, wz)
    if not self.grid_width then return true end

    local radius_in_grid = math.ceil(self.radius / self.grid_size)
    local center_gx, center_gz = self:WorldToGrid(wx, wz)
    if not center_gx then return true end

    for i = -radius_in_grid, radius_in_grid do
        for j = -radius_in_grid, radius_in_grid do
            local gx = center_gx + i
            local gz = center_gz + j

            if gx >= 1 and gx <= self.grid_width and gz >= 1 and gz <= self.grid_height then
                -- First, check if the circle intersects this grid cell at all.
                local grid_min_wx = (gx - 1) * self.grid_size - self.offset_x
                local grid_min_wz = (gz - 1) * self.grid_size - self.offset_z
                local grid_max_wx = gx * self.grid_size - self.offset_x
                local grid_max_wz = gz * self.grid_size - self.offset_z

                local closest_x = math.max(grid_min_wx, math.min(wx, grid_max_wx))
                local closest_z = math.max(grid_min_wz, math.min(wz, grid_max_wz))

                local dist_sq = (wx - closest_x)^2 + (wz - closest_z)^2

                if dist_sq < self.radius_sq then
                    -- The circle intersects this grid cell.
                    -- Now, we check if this cell has been marked as *fully* revealed.
                    -- If it's NOT fully revealed, the call is necessary.
                    if not self.revealed_grid[gx] or not self.revealed_grid[gx][gz] then
                        return true
                    end
                end
            end
        end
    end

    -- If we looped through all intersecting cells and ALL of them are already fully revealed,
    -- then this call is likely unnecessary.
    return false
end

return MapRevealOptimizer 