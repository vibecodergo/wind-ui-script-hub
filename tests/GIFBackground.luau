-- Run from the repository root: lune run tests/GIFBackground.luau
-- Executes the real controller and real window API against deterministic engine doubles.
-- These checks cannot verify Roblox rendering, asset permissions or frame time.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Vector2, UDim, UDim2 = roblox.Vector2, roblox.UDim, roblox.UDim2
local function signal()
	local callbacks = {}
	local s = {}
	function s:Connect(callback)
		local connection = { Connected = true }
		callbacks[connection] = callback
		function connection:Disconnect() self.Connected = false; callbacks[self] = nil end
		return connection
	end
	function s:Fire(...)
		local copy = table.clone(callbacks)
		for connection, callback in pairs(copy) do
			if connection.Connected then callback(...) end
		end
	end
	function s:Count() local n = 0; for _ in pairs(callbacks) do n += 1 end; return n end
	return s
end

local objects = {}
local function new(class, properties, children)
	local object = { ClassName = class, Visible = true, Enabled = true, Playing = false,
		IsLoaded = false, Destroying = signal(), Signals = {}, Children = {}, ImageTransparency = 0 }
	function object:IsA(name)
		return name == self.ClassName
			or (name == "GuiObject" and table.find({ "ImageLabel", "Frame", "VideoFrame" }, self.ClassName) ~= nil)
			or (name == "LayerCollector" and self.ClassName == "ScreenGui")
	end
	function object:GetPropertyChangedSignal(name)
		self.Signals[name] = self.Signals[name] or signal()
		return self.Signals[name]
	end
	function object:Set(name, value) self[name] = value; self:GetPropertyChangedSignal(name):Fire() end
	function object:Destroy()
		if self.WasDestroyed then return end
		self.Destroying:Fire()
		self.WasDestroyed = true
		self.Parent = nil
	end
	function object:Pause() self.Playing = false end
	for k, v in pairs(properties or {}) do object[k] = v end
	object.Children = children or {}
	for _, child in ipairs(object.Children) do child.Parent = object end
	table.insert(objects, object)
	return object
end

local heartbeat = signal()
local preloads = {}
local creator = { New = new }
local env = {
	game = { GetService = function(_, name)
		if name == "ContentProvider" then return { PreloadAsync = function() end } end
		assert(name == "RunService"); return { Heartbeat = heartbeat }
	end },
	task = { spawn = function(callback) table.insert(preloads, callback) end },
	require = function(path) assert(path == "../../modules/Creator"); return creator end,
	Vector2 = Vector2, UDim = UDim, UDim2 = UDim2, Enum = roblox.Enum,
}
setmetatable(env, { __index = getfenv() })
local function load(source) return luau.load(source, { environment = env }) end
local Controller = load(fs.readFile("src/components/window/GIFBackground.lua"))()
local tests = 0
local function check(value, message) assert(value, message); tests += 1 end
local function config(overrides)
	local c = { Asset = "rbxassetid://848623155", Columns = 4, Rows = 4,
		FrameCount = 12, FrameSize = Vector2.new(256, 256), FPS = 24, Transparency = 0.3 }
	for k, v in pairs(overrides or {}) do c[k] = v end
	return c
end
local gui = new("ScreenGui")
local main = new("Frame", { Parent = gui })
local background = new("ImageLabel", { Parent = main })
local player = Controller.new(background, 16, config())
check(player.Image.Parent == background, "must live in the existing window background")
check(not player.Image.Active and not player.Image.Selectable, "must not capture input")
check(player.Image.Size == UDim2.fromScale(1, 1), "must resize with the window")
check(player.Image.Children[1].CornerRadius == UDim.new(0, 16), "must retain the window radius")
check(player.Image.ImageTransparency == 0.3, "transparency must be exact")
check(heartbeat:Count() == 0, "must not run before the texture loads")
player.Image:Set("IsLoaded", true)
check(heartbeat:Count() == 1, "must auto-play on texture load")
heartbeat:Fire(1 / 24)
check(player.Image.ImageRectOffset == Vector2.new(256, 0), "second frame must be column 2")
heartbeat:Fire(3 / 24)
check(player.Image.ImageRectOffset == Vector2.new(0, 256), "fifth frame must wrap into row 2")
heartbeat:Fire(1)
check(player.Frame == 4, "large deltas must skip missed frames and loop")
player:SetPlaying(false)
local before = player.Elapsed
heartbeat:Fire(1)
check(player.Elapsed == before and heartbeat:Count() == 0, "closing must pause without advancing time")
player:SetPlaying(true)
main:Set("Visible", false)
check(heartbeat:Count() == 0, "externally hiding the window must pause")
main:Set("Visible", true)
gui:Set("Enabled", false)
check(heartbeat:Count() == 0, "disabling ScreenGui must pause")
gui:Set("Enabled", true)
check(heartbeat:Count() == 1, "showing ancestors must resume with one connection")
player:SetTransparency(1)
check(heartbeat:Count() == 0, "fully transparent animation must not tick")
player:SetTransparency(-1)
check(player.Image.ImageTransparency == 0 and heartbeat:Count() == 1, "transparency clamps and resumes")
player:Destroy(); player:Destroy()
check(heartbeat:Count() == 0 and #player.Connections == 0, "destroy must be idempotent and release connections")
local silent = Controller.new(background, 16, config())
silent.Image.IsLoaded = true -- Engine may update this without emitting a property signal.
preloads[#preloads]()
check(heartbeat:Count() == 1, "preload completion must start playback without an IsLoaded signal")
silent:Destroy()
local once = Controller.new(background, 16, config({ Loop = false }))
once.Image:Set("IsLoaded", true)
heartbeat:Fire(3)
check(once.Frame == 11 and once.Finished and heartbeat:Count() == 0, "nonlooping animation must stop on final frame")
once:SetPlaying(false); once:SetPlaying(true)
check(heartbeat:Count() == 0, "reopen must preserve a completed nonlooping animation")
once:Destroy()
local doomed = Controller.new(background, 16, config())
doomed.Image:Set("IsLoaded", true)
background:Destroy()
check(doomed.Destroyed and heartbeat:Count() == 0, "parent destruction must clean up")

for _, bad in ipairs({
	{ FrameCount = 17 }, { Columns = 0 }, { Rows = 1.5 },
	{ FrameSize = Vector2.new(0, 256) }, { Asset = "https://example.com/test.gif" },
	{ FPS = 0/0 }, { Transparency = math.huge }, { Type = "GIF" }, { Loop = "true" },
}) do
	check(not pcall(Controller.Validate, config(bad)), "invalid metadata must be rejected")
end
check(Controller.Validate(config({ FPS = 1000 })).FPS == 60, "FPS must be capped")
check(Controller.Validate(config({ FPS = 0 })).FPS == 1, "FPS must have a lower bound")
check(Controller.Validate(config({ Asset = "rbxasset://giphy-sheet.png" })).Asset == "rbxasset://giphy-sheet.png", "executor image URIs must be accepted")

-- Execute the actual Window API section; no duplicate setter implementation in the test.
local source = fs.readFile("src/components/window/Init.lua")
local start = assert(source:find("\t-- Shares the existing internal Background", 1, true))
local finish = assert(source:find("\n\tfunction Window:SetBackgroundTransparency", start, true))
local factory = load("return function(Window, Config, BGImage, GIFBackground)\n"
	.. "local AnimatedBG, PreviousBackground\n" .. source:sub(start, finish - 1)
	.. "\nreturn function() return AnimatedBG end end")()
local static = new("VideoFrame", { Playing = true })
local gradient = new("ImageLabel", { Visible = false })
local bg = new("ImageLabel", { Parent = main })
local window = { UIElements = { Main = { Background = bg }, BackgroundGradient = gradient }, UICorner = 16 }
local get = factory(window, {}, static, Controller)
window:SetGIFBackground(config())
check(not static.Visible and not static.Playing and not gradient.Visible, "GIF must hide previous media and pause video")
local first = get()
first.Image:Set("IsLoaded", true)
local ok = pcall(function() window:SetGIFBackground(config({ FrameCount = 999 })) end)
check(not ok and get() == first and not first.Destroyed, "invalid replacement must preserve current animation")
window:SetGIFBackground(config({ Asset = "rbxassetid://123" }))
check(first.Destroyed and get() ~= first and heartbeat:Count() == 0, "replacement must release old playback")
window:SetGIFBackgroundTransparency(0.456)
check(window.GIFBackground.Transparency == 0.456, "dynamic transparency must retain precision")
window:RemoveGIFBackground()
check(get() == nil and window.UIElements.GIFBackground == nil, "remove must clear public references")
check(static.Visible and static.Playing and not gradient.Visible, "remove must restore previous visibility and playback")
window:SetGIFBackground({ Enabled = false })
check(get() == nil, "disabled configuration needs no sprite metadata")
window.Closed = true
window:SetGIFBackground(config())
get().Image:Set("IsLoaded", true)
check(heartbeat:Count() == 0 and get().Image.ImageTransparency == 1, "replacement while closed must stay paused and hidden")
window:SetGIFBackgroundTransparency(0.2)
check(get().Image.ImageTransparency == 1 and window.GIFBackground.Transparency == 0.2, "closed transparency update must not reveal animation")
window:SetGIFBackground(false)
window.Destroyed = true
check(not pcall(function() window:SetGIFBackground(config()) end), "destroyed window must reject new animation")
check(heartbeat:Count() == 0, "test must leave no playback connections")

-- Syntax/bytecode validation of the real integration and generated distribution.
luau.compile(source)
luau.compile(fs.readFile("dist/main.lua"))
print(string.format("PASS: %d assertions; controller, window API and bundle compile checked. Engine rendering/FPS not tested.", tests))
