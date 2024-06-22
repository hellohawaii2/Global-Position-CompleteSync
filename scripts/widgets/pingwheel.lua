local Widget = require "widgets/widget"
local PingBadge = require("widgets/pingbadge")

-- local ATLAS = "images/avatars.xml"
local lang = LanguageTranslator.defaultlang or 'en'
local CH = lang == 'zh' or lang == 'zht'

local PingWheel = Class(Widget, function(self)
    Widget._ctor(self, "PingWheel")
    self.isFE = false
    self:SetClickable(false)
	self.useleftstick = false

    self.root = self:AddChild(Widget("root"))

    self.icon = self.root:AddChild(Widget("target"))
    self.icon:SetScale(1)
	self.gestures = {}
	
	local pings = {
		{name = "omw", image = "Omw", text = CH and "正在路上" or "On My Way"},
		{name = "gohere", image = "GoHere", text = CH and "去这里" or "Go Here"},
		{name = "explore", image = "Explore", text = CH and "探索这里" or "Explore"},
		{name = "danger", image = "Danger", text = CH and "这里危险" or "Danger"},
	}
	local function build_wheel(pings)
		local count = #pings
		local dist = (100*count)/(math.pi)
		self.radius = math.max(self.radius or 0, dist)
		local delta = 2*math.pi/count
		local theta = 0
		for i,v in ipairs(pings) do
			self.gestures[v.name] = self.icon:AddChild(PingBadge(v.image, v.text))
			self.gestures[v.name]:SetPosition(dist*math.cos(theta),dist*math.sin(theta), 0)
			theta = theta + delta
		end
	end
	build_wheel(pings)
	local specialdist = 150
	local specials = {
		{name = "generic", image = "", text = CH and "集合" or "Ping", x = 0, y = 0},
		{name = "cancel", image = "Cancel", text = CH and "取消" or "Cancel", x = -specialdist, y = -specialdist},
		{name = "delete", image = "Delete", text = CH and "删除此信号" or "Delete", x = specialdist, y = specialdist},
		{name = "clear", image = "Clear", text = CH and "清除所有信号" or "Clear All", x = specialdist, y = -specialdist},
	}
	for _,v in ipairs(specials) do
		self.gestures[v.name] = self.icon:AddChild(PingBadge(v.image, v.text))
		self.gestures[v.name]:SetPosition(v.x, v.y, 0)
	end
end)

local function GetMouseDistance(self, gesture, mouse)
	local pos = self:GetPosition()
	if gesture ~= nil then
		local offset = gesture:GetPosition()
		pos.x = pos.x + offset.x
		pos.y = pos.y + offset.y
	end
	local dx = pos.x - mouse.x
	local dy = pos.y - mouse.y
	return dx*dx + dy*dy
end

local function GetControllerDistance(self, gesture, direction)
	direction = direction * self.radius
	local pos = self:GetPosition()
	if gesture ~= nil then
		pos = gesture:GetPosition()
	else
		pos.x = 0
		pos.y = 0
	end
	local dx = pos.x - direction.x
	local dy = pos.y - direction.y
	return dx*dx + dy*dy
end

local function GetControllerTilt(left)
	local xdir = 0
	local ydir = 0
	if left then
		xdir = TheInput:GetAnalogControlValue(CONTROL_MOVE_RIGHT) - TheInput:GetAnalogControlValue(CONTROL_MOVE_LEFT)
		ydir = TheInput:GetAnalogControlValue(CONTROL_MOVE_UP) - TheInput:GetAnalogControlValue(CONTROL_MOVE_DOWN)
	else
		xdir = TheInput:GetAnalogControlValue(CONTROL_INVENTORY_RIGHT) - TheInput:GetAnalogControlValue(CONTROL_INVENTORY_LEFT)
		ydir = TheInput:GetAnalogControlValue(CONTROL_INVENTORY_UP) - TheInput:GetAnalogControlValue(CONTROL_INVENTORY_DOWN)
	end
	return xdir, ydir
end

function PingWheel:OnUpdate()
	local mindist = math.huge
	local mingesture = nil
	
	if TheInput:ControllerAttached() then
		local xdir, ydir = GetControllerTilt(self.useleftstick)
		local deadzone = .3
		local dir = Vector3(xdir, ydir, 0):GetNormalized()
		if math.abs(xdir) < deadzone and math.abs(ydir) < deadzone then
			dir = dir * 0
		end
		
		for k,v in pairs(self.gestures) do
			local dist = GetControllerDistance(self, v, dir)
			if dist < mindist then
				mindist = dist
				mingesture = k
			end
		end
		
		if GetControllerDistance(self, nil, dir) < mindist then
			mingesture = nil
			self.activegesture = nil
		end
	else
		--find the gesture closest to the mouse
		local mouse = TheInput:GetScreenPosition()
		for k,v in pairs(self.gestures) do
			local dist = GetMouseDistance(self, v, mouse)
			if dist < mindist then
				mindist = dist
				mingesture = k
			end
		end
		-- make sure the mouse isn't still close to the center of the gesture wheel
		if GetMouseDistance(self, nil, mouse) < mindist then
			mingesture = nil
			self.activegesture = nil
		end
		
	end
	
	for k,v in pairs(self.gestures) do
		if k == mingesture then
			v:Expand()
			self.activegesture = k
		else
			v:Contract()
		end
	end
end

return PingWheel