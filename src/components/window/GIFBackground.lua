-- GIFs must first be converted to a row-major sprite sheet uploaded as an image.
-- One texture, one ImageLabel and at most one Heartbeat connection per window.
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")
local Creator = require("../../modules/Creator")

local GIFBackground = {}
GIFBackground.__index = GIFBackground

local function number(value, name, default)
	if value == nil then
		value = default
	end
	assert(type(value) == "number" and value == value and math.abs(value) < math.huge,
		"GIFBackground." .. name .. " must be a finite number")
	return value
end

local function positiveInteger(value, name)
	value = number(value, name)
	assert(value > 0 and value % 1 == 0, "GIFBackground." .. name .. " must be a positive integer")
	return value
end

function GIFBackground.Validate(config)
	assert(type(config) == "table", "GIFBackground must be a table")
	assert(config.Type == nil or config.Type == "SpriteSheet", "GIFBackground.Type must be SpriteSheet")
	assert(type(config.Asset) == "string" and (config.Asset:match("^rbxassetid://%d+$") or config.Asset:match("^rbxasset://.+")),
		"GIFBackground.Asset must be a sprite sheet image ID or a local rbxasset:// image URI, not a GIF")
	assert(typeof(config.FrameSize) == "Vector2", "GIFBackground.FrameSize must be a Vector2 in uploaded image pixels")
	positiveInteger(config.FrameSize.X, "FrameSize.X")
	positiveInteger(config.FrameSize.Y, "FrameSize.Y")
	local columns = positiveInteger(config.Columns, "Columns")
	local rows = positiveInteger(config.Rows, "Rows")
	local count = positiveInteger(config.FrameCount, "FrameCount")
	assert(count <= columns * rows, "GIFBackground.FrameCount exceeds the sprite sheet grid")
	assert(config.Loop == nil or type(config.Loop) == "boolean", "GIFBackground.Loop must be boolean")
	assert(config.Enabled == nil or type(config.Enabled) == "boolean", "GIFBackground.Enabled must be boolean")
	return {
		Type = "SpriteSheet",
		Enabled = config.Enabled ~= false,
		Asset = config.Asset,
		FrameSize = config.FrameSize,
		Columns = columns,
		Rows = rows,
		FrameCount = count,
		FPS = math.clamp(number(config.FPS, "FPS", 24), 1, 60),
		Transparency = math.clamp(number(config.Transparency, "Transparency", 0), 0, 1),
		Loop = config.Loop ~= false,
	}
end

function GIFBackground.new(parent, radius, config)
	local self = setmetatable({
		Config = GIFBackground.Validate(config),
		Elapsed = 0,
		Frame = 0,
		Playing = true,
		Finished = false,
		Destroyed = false,
		Connections = {},
	}, GIFBackground)
	self.Image = Creator.New("ImageLabel", {
		Name = "GIFBackground",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
		Active = false,
		Selectable = false,
		Image = self.Config.Asset,
		ImageRectSize = self.Config.FrameSize,
		ImageRectOffset = Vector2.zero,
		ImageTransparency = self.Config.Transparency,
		ScaleType = Enum.ScaleType.Stretch,
		Parent = parent,
	}, {
		Creator.New("UICorner", { CornerRadius = UDim.new(0, radius) }),
	})
	local function connect(signal, callback)
		table.insert(self.Connections, signal:Connect(callback))
	end
	connect(self.Image:GetPropertyChangedSignal("IsLoaded"), function() self:Refresh() end)
	-- Watch the actual ancestor visibility, including externally hidden ScreenGuis.
	local ancestor = self.Image
	while ancestor do
		if ancestor:IsA("GuiObject") then
			connect(ancestor:GetPropertyChangedSignal("Visible"), function() self:Refresh() end)
		elseif ancestor:IsA("LayerCollector") then
			connect(ancestor:GetPropertyChangedSignal("Enabled"), function() self:Refresh() end)
		end
		ancestor = ancestor.Parent
	end
	connect(parent.Destroying, function() self:Destroy() end)
	connect(self.Image.Destroying, function() self:Destroy() end)
	self:Refresh()
	-- IsLoaded changes do not consistently emit property signals on every client.
	-- Explicit preload completion also starts cached/replacement sheets reliably.
	task.spawn(function()
		if self.Destroyed then return end
		local success, message = pcall(function()
			ContentProvider:PreloadAsync({ self.Image })
		end)
		if self.Destroyed then return end
		self:Refresh()
		if not success then warn("[WindUI.GIFBackground] Texture preload failed: " .. tostring(message)) end
	end)
	return self
end

function GIFBackground:IsVisible()
	local ancestor = self.Image
	while ancestor do
		if ancestor:IsA("GuiObject") and not ancestor.Visible then return false end
		if ancestor:IsA("LayerCollector") and not ancestor.Enabled then return false end
		ancestor = ancestor.Parent
	end
	return self.Image.Parent ~= nil
end

function GIFBackground:Refresh()
	if self.Destroyed then return end
	local active = self.Playing and not self.Finished and self.Config.Enabled
		and self.Config.Transparency < 1 and self.Image.IsLoaded and self:IsVisible()
	if active and not self.Heartbeat then
		self.Heartbeat = RunService.Heartbeat:Connect(function(dt) self:Step(dt) end)
	elseif not active and self.Heartbeat then
		self.Heartbeat:Disconnect()
		self.Heartbeat = nil
	end
end

function GIFBackground:Step(dt)
	if self.Destroyed then return end
	local config = self.Config
	self.Elapsed = self.Elapsed + dt
	local frame = math.floor(self.Elapsed * config.FPS)
	if config.Loop then
		-- Bound elapsed time even in long-running sessions; skip missed frames.
		self.Elapsed = self.Elapsed % (config.FrameCount / config.FPS)
		frame = frame % config.FrameCount
	elseif frame >= config.FrameCount then
		frame = config.FrameCount - 1
		self.Finished = true
		self:Refresh()
	end
	if frame ~= self.Frame then
		self.Frame = frame
		self.Image.ImageRectOffset = Vector2.new(
			(frame % config.Columns) * config.FrameSize.X,
			math.floor(frame / config.Columns) * config.FrameSize.Y
		)
	end
end

function GIFBackground:SetPlaying(value)
	self.Playing = value
	self:Refresh()
end

function GIFBackground:SetTransparency(value)
	self.Config.Transparency = math.clamp(number(value, "Transparency"), 0, 1)
	self.Image.ImageTransparency = self.Config.Transparency
	self:Refresh()
end

function GIFBackground:Destroy()
	if self.Destroyed then return end
	self.Destroyed = true
	if self.Heartbeat then
		self.Heartbeat:Disconnect()
		self.Heartbeat = nil
	end
	for _, connection in ipairs(self.Connections) do connection:Disconnect() end
	table.clear(self.Connections)
	self.Image:Destroy()
end

return GIFBackground
