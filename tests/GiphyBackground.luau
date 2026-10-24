local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local written, writes, folders = nil, 0, {}
local env = setmetatable({
	Vector2 = roblox.Vector2,
	getcustomasset = function(path) return "rbxasset://giphy-sheet.png" end,
	writefile = function(path, bytes) assert(path == "WindUI/assets/giphy-TrVla4Z2PYEkU-sheet.png"); written = bytes; writes += 1 end,
	isfile = function() return written ~= nil end,
	isfolder = function(path) return folders[path] == true end,
	makefolder = function(path) folders[path] = true end,
}, { __index = getfenv() })
local function load()
	return luau.load(fs.readFile("examples/GiphyBackground.lua"), { environment = env })()
end
local config = load()
assert(written == fs.readFile("assets/giphy-TrVla4Z2PYEkU.png"), "embedded decoder must reproduce PNG byte for byte")
assert(config.FrameCount == 16 and config.FPS == 10 and config.Columns == 4 and config.Rows == 4)
assert(config.FrameSize == roblox.Vector2.new(250, 140))
assert(config.Asset == "rbxasset://giphy-sheet.png" and config.Loop)
assert(folders["WindUI/assets"])
load()
assert(writes == 1, "cached sheet must not be rewritten")
print("PASS: embedded PNG byte equality, animation metadata, local asset and cache checks.")
