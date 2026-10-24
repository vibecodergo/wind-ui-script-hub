local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")
local files, directories, failWrite = {}, {}, false
local env = setmetatable({
	game = { GetService = function() return {
		JSONDecode = function(_, value) return serde.decode("json", value) end,
		JSONEncode = function(_, value) return serde.encode("json", value) end,
	} end },
	writefile = function(path, content) assert(not failWrite, "read-only fixture"); files[path] = content end,
	readfile = function(path) return assert(files[path]) end,
	isfile = function(path) return files[path] ~= nil end,
	makefolder = function(path) directories[path] = true end,
	isfolder = function(path) return directories[path] == true end,
}, { __index = getfenv() })
local Store = luau.load(fs.readFile("examples/HubStore.lua"), { environment = env })()
local checks = 0
local function check(value, label) assert(value, label); checks += 1 end
local function item(id) return { _id = id or "one", title = "Fixture", game = { name = "Game" }, key = false,
	isUniversal = true, verified = true, script = "must not persist executable code" } end
local s = Store.new()
check(s.Persistent and #s.Favorites == 0, "fresh state")
check(s:ToggleFavorite(item()) and s:IsFavorite("one"), "add favorite")
check(directories["WindUI/script-hub"], "create only owned storage folder")
local raw = files["WindUI/script-hub/state-v1.json"]
check(not raw:find("must not persist", 1, true), "favorite JSON must not contain downloaded source")
local restored = Store.new()
check(restored:IsFavorite("one") and restored.Favorites[1].key == false, "favorite and false boolean must round-trip")
check(not s:ToggleFavorite(item()) and not s:IsFavorite("one"), "remove favorite")
s:Record(item(), "Visto"); s:Record(item(), "Ejecutado")
check(#s.History == 1 and s.History[1].Action == "Ejecutado", "history de-duplicates and updates action")
check(Store.new().History[1].Action == "Ejecutado", "history persists")
s.Persistent = false
for n = 1, 120 do s:Record(item(tostring(n)), "Visto") end
check(#s.History == 100 and s.History[1]._id == "120", "history is bounded and newest first")
s:ClearHistory(); check(#s.History == 0, "clear history")
for n = 1, 501 do s:ToggleFavorite(item(tostring(n))) end
check(#s.Favorites == 500, "favorite cap")
s.Persistent = true
failWrite = true
check(not s:Save() and s.LastError ~= nil and #s.Favorites == 500, "write failure preserves in-memory state")
failWrite = false
files["WindUI/script-hub/state-v1.json"] = "not json"
local malformed = Store.new()
check(#malformed.Favorites == 0 and malformed.LastError ~= nil, "malformed file must not crash")
check(files["WindUI/script-hub/state-v1.json"] == "not json", "load must not overwrite malformed file")
files["WindUI/script-hub/state-v1.json"] = serde.encode("json", { Version = 1,
	Favorites = { item(), item(), { title = "invalid" } }, History = {},
	Settings = { Transparency = 4, FPS = 999, Background = false } })
local validated = Store.new()
check(#validated.Favorites == 1, "load must de-duplicate and reject invalid entries")
check(validated.Settings.Transparency == 1 and validated.Settings.FPS == 30 and not validated.Settings.Background, "settings bounds")
local unicode = item("unicode"); unicode.title = string.rep("🌸", 200)
validated:ToggleFavorite(unicode)
check(utf8.len(validated.Favorites[1].title) ~= nil and #validated.Favorites[1].title <= 500, "truncate metadata on UTF-8 boundaries")
check(Store.new():IsFavorite("unicode"), "Unicode favorite persists")
print("PASS: " .. checks .. " local-library assertions.")
