-- Deterministic checks of the actual browser. No network or catalog scripts executed.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")
local pending, deadlines, urls, notifications = {}, {}, {}, {}
local copied, runs, failure = nil, 0, nil
local fixture = string.rep("-- known test fixture\n", 1000)
local function widget(config)
	local w = table.clone(config or {})
	w.ElementFrame = { Visible = true }
	function w:SetTitle(t) self.Title = t end
	function w:SetDesc(t) self.Desc = t end
	function w:SetCode(t) self.Code = t end
	function w:Refresh(v) self.Values = v end
	function w:Close() end
	function w:Lock() self.Locked = true end
	function w:Unlock() self.Locked = false end
	function w:Set(value) self.Value = value; if self.Callback then self.Callback(value) end end
	return w
end
local tabs = {}
local window = { Destroyed = false }
function window:Tab(config)
	local tab = { Title = config.Title, Elements = {}, Buttons = {}, UIElements = { ContainerFrame = {} } }
	for _, kind in ipairs({ "Paragraph", "Input", "Dropdown", "Code", "Button", "Toggle" }) do
		tab[kind] = function(self, settings)
			local w = widget(settings)
			table.insert(self.Elements, w)
			if kind == "Button" then self.Buttons[settings.Title] = w end
			return w
		end
	end
	function tab:HStack()
		return { ElementFrame = { Visible = true }, Button = function(_, settings) return widget(settings) end }
	end
	function tab:Select() self.Selected = true end
	table.insert(tabs, tab)
	return tab
end
local http = {
	JSONDecode = function(_, body) return serde.decode("json", body) end,
	UrlEncode = function(_, value) return value:gsub("([^%w%-_%.~])", function(c) return string.format("%%%02X", string.byte(c)) end) end,
}
local env = setmetatable({
	game = { PlaceId = 1234, GetService = function() return http end },
	UDim = { new = function(_, offset) return { Offset = offset } end },
	Vector2 = { zero = {} },
	task = { spawn = function(callback) table.insert(pending, callback) end,
		delay = function(_, callback) table.insert(deadlines, callback) end },
	setclipboard = function(value) copied = value end,
	loadstring = function(code)
		if code == "invalid!" then return nil, "syntax error" end
		return function() runs += 1 end
	end,
	request = function(options)
		table.insert(urls, options.Url)
		if failure then return { StatusCode = failure, Body = "" } end
		if options.Url:find("max=1$", 1) then
			return { StatusCode = 200, Body = serde.encode("json", { result = { max = 1, totalPages = 74252, scripts = {} } }) }
		end
		if options.Url:find("/api/script/detail", 1, true) then
			return { StatusCode = 200, Body = serde.encode("json", { script = { script = "return 42" } }) }
		end
		local result = { totalPages = options.Url:find("/search", 1, true) and 5 or 3713, scripts = {
			{ _id = "one", title = "<fixture>", script = fixture, game = { name = "Test game" } },
			{ _id = "two", slug = "detail", title = "Details fixture" },
		} }
		return { StatusCode = 200, Body = serde.encode("json", { result = result }) }
	end,
}, { __index = getfenv() })
local attach = luau.load(fs.readFile("examples/ScriptSearch.lua"), { environment = env })()
local browser = attach({ Notify = function(_, config) table.insert(notifications, config) end }, window)
local checks = 0
local function check(value, message) assert(value, message); checks += 1 end
local function nextTask() local callback = table.remove(pending, 1); assert(callback); callback() end
check(browser.Busy and not browser.Ready, "initial request must be asynchronous")
nextTask()
check(browser.Ready and #browser.Results == 2 and browser.CatalogPages == 3713, "catalog must load actual response")
check(browser.UI.Rows[1].ElementFrame.Visible and not browser.UI.Rows[3].ElementFrame.Visible, "only real results should appear in the visible list")
check(not browser.UI.Actions.ElementFrame.Visible, "actions must stay hidden until selecting a result")
check(browser.UI.Status.Desc:find("50.000", 1, true), "large catalog metadata must be shown")
check(runs == 0, "loading results must not run code")
browser:Select(1); nextTask()
check(browser.Code == fixture, "selection must retain complete code")
check(browser.UI.Actions.ElementFrame.Visible and not browser.UI.ActionButtons[1].Locked, "selection must reveal enabled actions")
browser:ShowCode()
check(browser.UI.Preview.ElementFrame.Visible and not browser.UI.Rows[1].ElementFrame.Visible, "code view must replace the list inside the same tab")
browser:ShowResults()
check(not browser.UI.Preview.ElementFrame.Visible and browser.UI.Rows[1].ElementFrame.Visible, "back must restore the visible list")
check(#browser.UI.Preview.Code < #fixture, "large source must have a bounded preview")
check(browser.UI.Details.Title == "&lt;fixture&gt;", "remote metadata must escape RichText")
check(browser:Copy() and copied == fixture, "copy must use full source")
check(browser:Run() and runs == 0, "execute must be asynchronous")
nextTask()
check(runs == 1, "explicit execute must invoke compiled callback")
browser:Load(2); nextTask()
check(browser.Code == nil and browser.Selected == nil, "page changes must invalidate selection")
check(browser.Page == 2, "page must update")
local count = #urls
browser:Load(1); nextTask()
check(#urls == count, "recent pages must use the bounded cache")
browser:Load(1, "a & b"); nextTask()
check(urls[#urls]:find("q=a%%20%%26%%20b") ~= nil, "search text must be URL encoded")
check(browser.TotalPages == 5 and browser.CatalogPages == 3713, "query results must not replace catalog size")
browser:Select(2); nextTask()
check(browser.Code == "return 42", "missing list source must load details")
browser:Load(1, "stale")
browser:Load(1, "new")
nextTask(); nextTask()
check(browser.Query == "new", "an older response must not replace the current query")
browser:Select(1); browser:Select(2)
nextTask(); nextTask()
check(browser.Selected._id == "two" and browser.Code == "return 42", "old selection must not replace a newer source")
failure = 429
browser:Load(1, "rate limit"); nextTask()
check(not browser.Ready and not browser.Busy and browser.LastError:find("429"), "HTTP errors must clear loading state")
failure = nil
browser:Load(1, "timeout")
deadlines[#deadlines]()
nextTask()
check(not browser.Busy and browser.LastError == "Tiempo de espera agotado", "timed-out response must stay invalidated")
for n = 1, 10 do browser:Load(1, "cache" .. n); nextTask() end
check(#browser.CacheOrder <= 6, "page cache must stay bounded")
browser.Code = "invalid!"
check(not browser:Run(), "syntax errors must not invoke a callback")
check(runs == 1, "test must execute only the explicit known fixture")
browser:SetFilters({ Universal = true, NoKey = true, Verified = true, CurrentGame = true, Sort = "views" })
nextTask()
check(urls[#urls]:find("universal=1", 1, true) and urls[#urls]:find("key=0", 1, true)
	and urls[#urls]:find("verified=1", 1, true) and urls[#urls]:find("placeId=1234", 1, true), "filters must reach the server")
check(urls[#urls]:find("sortBy=views", 1, true), "sort order must reach the server")
browser:RefreshCatalog(); nextTask()
check(browser.CatalogCount == 74252, "one-result pagination must report catalog size independently of filters")
local tags = browser:Tags({ isUniversal = true, key = false, verified = true, updatedAt = "2026-10-24T12:00:00Z" })
check(#tags == 4 and tags[4] == "Actualizado 2026-10-24", "tags must reflect actual fields and date")
check(#browser:Tags({}) == 0, "missing metadata must not invent tags")
env.debug = {}
check(browser:ExecuteCode("known fixture", "Editor local"), "executors without debug.traceback must still run code")
nextTask()
check(runs == 2, "fallback error handler must execute the known callback")
window.Destroyed = true
count = #pending
browser:Load(1, "closed")
check(#pending == count, "destroyed window must not launch requests")
luau.compile(fs.readFile("dist/script-hub.lua"))
print("PASS: " .. checks .. " browser assertions; integrated bundle compiles.")
