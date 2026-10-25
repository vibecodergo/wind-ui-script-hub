-- Public loader for vibecodergo/wind-ui-script-hub.
local url = "https://raw.githubusercontent.com/vibecodergo/wind-ui-script-hub/main/dist/script-hub.lua"
local downloaded, source = pcall(function() return game:HttpGet(url) end)
assert(downloaded and type(source) == "string" and #source > 0,
	"No se pudo descargar Script Hub: " .. tostring(source))
local start, compileError = loadstring(source, "WindUI Script Hub")
assert(start, compileError)

local environment = getgenv and getgenv() or _G
local previous = environment.__WindUIScriptHub
if previous and previous.Window and not previous.Window.Destroyed then
	previous.Window:Destroy()
	task.wait(0.6)
end
local success, hub = pcall(start)
assert(success, "No se pudo iniciar Script Hub: " .. tostring(hub))
environment.__WindUIScriptHub = hub
return hub
