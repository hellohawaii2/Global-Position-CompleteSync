local MapRevealOptimizer = Class(function(self, inst)
    self.inst = inst
    self.grid_size = 8
    self.revealed_grid = {}
end)


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


function MapRevealOptimizer:MarkRevealed(wx, wz)
    local gx = math.floor(wx / self.grid_size)
    local gz = math.floor(wz / self.grid_size)
    local key = gx..","..gz
    -- print("[global position (CompleteSync)] MapRevealOptimizer:MarkRevealed: gx, gz = ", gx, gz)
    self.revealed_grid[key] = true
end

function MapRevealOptimizer:IsNecessary(wx, wz)
    local gx = math.floor(wx / self.grid_size)
    local gz = math.floor(wz / self.grid_size)
    local key = gx..","..gz

    if self.revealed_grid[key] then
        -- print("[global position (CompleteSync)] MapRevealOptimizer:IsNecessary: gx, gz = ", gx, gz, "is already revealed")
        return false 
    end

    -- print("[global position (CompleteSync)] MapRevealOptimizer:IsNecessary: gx, gz = ", gx, gz, "is not revealed")
    return true
end

return MapRevealOptimizer 