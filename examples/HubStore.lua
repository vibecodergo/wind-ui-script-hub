-- Local metadata only: favorites/history never persist downloaded executable code.
local Http = game:GetService("HttpService")
local Store = {}
Store.__index = Store
local PATH = "WindUI/script-hub/state-v1.json"
local function flag(value) if type(value) == "boolean" then return value end end
local function short(value, limit)
	local value = value:sub(1, limit)
	while not utf8.len(value) do value = value:sub(1, -2) end
	return value
end
local function metadata(item)
	if type(item) ~= "table" then return nil end
	local id = item._id or item.slug
	if type(id) ~= "string" or #id == 0 or #id > 300 or type(item.title) ~= "string" then return nil end
	return { _id = id, slug = type(item.slug) == "string" and short(item.slug, 300) or nil,
		title = short(item.title, 500), game = { name = type(item.game) == "table" and short(tostring(item.game.name or ""), 300) or "Universal" },
		key = flag(item.key), verified = flag(item.verified), isUniversal = flag(item.isUniversal),
		updatedAt = type(item.updatedAt) == "string" and item.updatedAt:sub(1, 40) or nil,
		Action = type(item.Action) == "string" and short(item.Action, 40) or nil,
		Time = type(item.Time) == "number" and item.Time or nil }
end
function Store.new()
	local self = setmetatable({ Favorites = {}, History = {}, Settings = { Transparency = 0.6, FPS = 10, Background = true },
		Persistent = type(writefile) == "function" and type(readfile) == "function", LastError = nil }, Store)
	if self.Persistent and isfile and isfile(PATH) then
		local ok, data = pcall(function()
			local raw = readfile(PATH)
			assert(type(raw) == "string" and #raw <= 2 * 1024 * 1024, "Archivo local demasiado grande")
			return Http:JSONDecode(raw)
		end)
		if ok and type(data) == "table" and data.Version == 1 then
			for _, name in ipairs({ "Favorites", "History" }) do
				local seen = {}
				for _, item in ipairs(type(data[name]) == "table" and data[name] or {}) do
					local entry = metadata(item)
					if entry and not seen[entry._id] and #self[name] < (name == "Favorites" and 500 or 100) then
						seen[entry._id] = true; table.insert(self[name], entry)
					end
				end
			end
			if type(data.Settings) == "table" then
				for _, key in ipairs({ "Transparency", "FPS" }) do
					local value = data.Settings[key]
					if type(value) == "number" and value == value and math.abs(value) < math.huge then
						self.Settings[key] = math.clamp(value, key == "FPS" and 1 or 0, key == "FPS" and 30 or 1)
					end
				end
				if type(data.Settings.Background) == "boolean" then self.Settings.Background = data.Settings.Background end
			end
		else self.LastError = "El archivo local no es válido; se conserva sin sobrescribir hasta guardar un cambio." end
	end
	return self
end
function Store:Save()
	if not self.Persistent then return false end
	local ok, err = pcall(function()
		if makefolder and isfolder then
			for _, path in ipairs({ "WindUI", "WindUI/script-hub" }) do if not isfolder(path) then makefolder(path) end end
		end
		writefile(PATH, Http:JSONEncode({ Version = 1, Favorites = self.Favorites, History = self.History, Settings = self.Settings }))
	end)
	self.LastError = not ok and tostring(err) or nil
	return ok
end
function Store:IsFavorite(item)
	local id = type(item) == "table" and (item._id or item.slug) or item
	for _, entry in ipairs(self.Favorites) do if entry._id == id then return true end end
	return false
end
function Store:ToggleFavorite(item)
	local entry = metadata(item)
	if not entry then return false, "Script inválido" end
	for index, favorite in ipairs(self.Favorites) do
		if favorite._id == entry._id then table.remove(self.Favorites, index); self:Save(); return false end
	end
	if #self.Favorites >= 500 then return false, "Límite de 500 favoritos" end
	table.insert(self.Favorites, 1, entry); self:Save(); return true
end
function Store:Record(item, action)
	local entry = metadata(item)
	if not entry then return end
	for index = #self.History, 1, -1 do if self.History[index]._id == entry._id then table.remove(self.History, index) end end
	entry.Action, entry.Time = action, os.time()
	table.insert(self.History, 1, entry)
	while #self.History > 100 do table.remove(self.History) end
	self:Save()
end
function Store:ClearHistory() self.History = {}; self:Save() end
return Store
