-- Studio: included in WindUI-GIF-Demo.rbxm; insert the folder into StarterPlayerScripts.
-- Executor: place this modified repository in your executor's workspace as WindUI.
local WindUI
if game:GetService("RunService"):IsStudio() then
	WindUI = require(script.Parent:WaitForChild("WindUI"))
else
	assert(readfile and loadstring, "Load the modified WindUI/dist/main.lua in your supported environment")
	WindUI = assert(loadstring(readfile("WindUI/dist/main.lua")))()
end

-- Roblox's documented 1024 x 1024 punch animation: 12 occupied cells in a 4 x 4 grid.
-- https://create.roblox.com/docs/reference/engine/classes/ImageLabel
local animation = {
	Enabled = true,
	Type = "SpriteSheet",
	Asset = "rbxassetid://848623155",
	FrameSize = Vector2.new(256, 256),
	Columns = 4,
	Rows = 4,
	FrameCount = 12,
	FPS = 24,
	Transparency = 0.3,
	Loop = true,
}

local Window = WindUI:CreateWindow({
	Title = "WindUI GIF Background",
	Size = UDim2.fromOffset(620, 460),
	GIFBackground = animation,
})

local Tab = Window:Tab({ Title = "Animation", Icon = "play" })
Tab:Paragraph({
	Title = "Internal animated background",
	Desc = "The animated character is a sprite-sheet example from Roblox documentation. Resize or drag the window, scroll this tab and use the controls while it plays.",
})
Tab:Slider({
	Title = "Background transparency",
	Step = 0.01,
	Value = { Min = 0, Max = 1, Default = 0.3 },
	Callback = function(value)
		animation.Transparency = value
		Window:SetGIFBackgroundTransparency(value)
	end,
})
Tab:Toggle({
	Title = "Loop animation",
	Value = true,
	Callback = function(value)
		animation.Loop = value
		Window:SetGIFBackground(animation)
	end,
})
Tab:Button({
	Title = "Restart / restore animation",
	Callback = function() Window:SetGIFBackground(animation) end,
})
Tab:Button({
	Title = "Replace with slower playback",
	Callback = function()
		local replacement = table.clone(animation)
		replacement.FPS = 6
		Window:SetGIFBackground(replacement)
	end,
})
Tab:Button({
	Title = "Remove animation",
	Callback = function() Window:RemoveGIFBackground() end,
})
Tab:Button({
	Title = "Close and reopen in 2 seconds",
	Callback = function()
		Window:Close()
		task.delay(2, function() if not Window.Destroyed then Window:Open() end end)
	end,
})
Tab:Button({
	Title = "Check texture and layer",
	Callback = function()
		local image = Window.UIElements.GIFBackground
		print("[GIF demo]", image and (image.IsLoaded and "texture loaded" or "texture pending / unavailable") or "removed")
		if image then
			assert(image.Parent == Window.UIElements.Main.Background)
			assert(not image.Active and not image.Selectable)
			assert(Window.UIElements.Main.Main.ZIndex > image.Parent.ZIndex)
			local offset = image.ImageRectOffset
			task.delay(0.09, function()
				if image.Parent then
					print("[GIF demo] frame offset", offset, "->", image.ImageRectOffset)
				end
			end)
		end
	end,
})

local Controls = Window:Tab({ Title = "Controls", Icon = "settings" })
Controls:Toggle({ Title = "Interactive control", Value = false, Callback = function(value) print("Toggle:", value) end })
for i = 1, 12 do
	Controls:Button({ Title = "Scroll test " .. i, Callback = function() print("Clicked", i) end })
end

Tab:Select()
return Window
