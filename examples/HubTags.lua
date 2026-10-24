-- Small theme-aware badges in the original WindUI tag container, reused on paging.
return function(WindUI)
	local Creator = WindUI.Creator
	return function(row, names)
		local frame = row.ButtonFrame or row.ParagraphFrame
		if not frame then return end
		local title = frame.UIElements.Container.TitleFrame.TitleFrame
		local parent = title.ScrollingFrame
		row.HubBadges = row.HubBadges or {}
		for index = 1, 4 do
			local badge = row.HubBadges[index]
			if not badge then
				local label = Creator.New("TextLabel", {
					Text = "", TextSize = 11, BackgroundTransparency = 1,
					FontFace = Font.new(Creator.Font, Enum.FontWeight.Medium),
					Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X,
					ThemeTag = { TextColor3 = "Text" },
				}, { Creator.New("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }) })
				local holder = Creator.NewRoundFrame(6, "Squircle", {
					Parent = parent, Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X,
					ImageTransparency = 0.88, ThemeTag = { ImageColor3 = "Text" },
				}, { label })
				badge = { Holder = holder, Label = label }; row.HubBadges[index] = badge
			end
			badge.Holder.Visible = names[index] ~= nil
			if names[index] then badge.Label.Text = names[index] end
		end
		parent.Visible, title.Space.Visible = #names > 0, #names > 0
	end
end
