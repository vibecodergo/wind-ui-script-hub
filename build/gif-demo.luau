-- Run from repo root after building dist/main.lua: lune run build/gif-demo.luau
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
local Instance = roblox.Instance
local folder = Instance.new("Folder")
folder.Name = "WindUIGIFDemo"
local library = Instance.new("ModuleScript")
library.Name = "WindUI"
-- The original library chooses CoreGui. This demo-only adapter uses its existing
-- gethui hook so a regular Studio LocalScript can mount the ORIGINAL UI in PlayerGui.
library.Source = 'local gethui = function() return game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui") end\n'
	.. fs.readFile("dist/main.lua")
library.Parent = folder
local demo = Instance.new("LocalScript")
demo.Name = "Demo"
demo.Source = fs.readFile("examples/GIFBackground.lua")
demo.Parent = folder
luau.compile(library.Source)
luau.compile(demo.Source)
fs.writeFile("examples/WindUI-GIF-Demo.rbxm", roblox.serializeModel({ folder }))
local roundtrip = roblox.deserializeModel(fs.readFile("examples/WindUI-GIF-Demo.rbxm"))
assert(#roundtrip == 1 and #roundtrip[1]:GetChildren() == 2)
assert(roundtrip[1].WindUI.Source == library.Source)
assert(roundtrip[1].Demo.Source == demo.Source)
print("Built examples/WindUI-GIF-Demo.rbxm; both scripts compile and model round-trip verified. Play in Studio to check rendering.")
