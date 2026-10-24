-- Source entry point: bundle with Darklua; run dist/script-hub.lua in the executor.
local WindUI = require("../src/Init")
local Background = require("./GiphyBackground")
local Store = require("./HubStore").new()
local backgroundConfig = table.clone(Background)
backgroundConfig.Enabled = Store.Settings.Background
backgroundConfig.FPS = Store.Settings.FPS
backgroundConfig.Transparency = Store.Settings.Transparency
local Window = WindUI:CreateWindow({
	Title = "My Script Hub · Remastered",
	Size = UDim2.fromOffset(820, 540),
	SideBarWidth = 150,
	GIFBackground = backgroundConfig,
})
if Window.UIElements.GIFBackground then Window.UIElements.GIFBackground.ScaleType = Enum.ScaleType.Crop end
local Hub = require("./HubWorkspace")(WindUI, Window, Store, Background)
return { Library = WindUI, Window = Window, Search = Hub.Search, Hub = Hub, Store = Store }
