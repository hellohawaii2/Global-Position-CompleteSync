local MapRevealOptimizer = Class(function(self, inst)
    self.inst = inst
    self.grid_size = 8
    self.revealed_grid = {} -- 直接初始化
end)

-- Initialize函数不再需要，因为我们不再依赖于地图加载
-- OnLoad 和 OnSave 保持不变，它们能正确地保存和加载新的表结构

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

-- 不再需要WorldToGrid函数，可以直接在需要的地方计算

function MapRevealOptimizer:MarkRevealed(wx, wz)
    local gx = math.floor(wx / self.grid_size)
    local gz = math.floor(wz / self.grid_size)
    local key = gx..","..gz -- 创建唯一的字符串键
    print("[global position (CompleteSync)] MapRevealOptimizer:MarkRevealed: gx, gz = ", gx, gz)
    self.revealed_grid[key] = true
end

function MapRevealOptimizer:IsNecessary(wx, wz)
    local gx = math.floor(wx / self.grid_size)
    local gz = math.floor(wz / self.grid_size)
    local key = gx..","..gz -- 创建相同的键来检查
    
    -- 检查这个键是否存在即可
    if self.revealed_grid[key] then
        print("[global position (CompleteSync)] MapRevealOptimizer:IsNecessary: gx, gz = ", gx, gz, "is already revealed")
        return false 
    end

    print("[global position (CompleteSync)] MapRevealOptimizer:IsNecessary: gx, gz = ", gx, gz, "is not revealed")
    return true
end

return MapRevealOptimizer 