local attachSearch = require("./ScriptSearch")
local makeTagRenderer = require("./HubTags")

return function(WindUI, Window, Store, Background)
	local Hub = { Tabs = {}, Store = Store }
	local renderTags = makeTagRenderer(WindUI)
	local function text(value)
		return tostring(value or ""):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
	end
	local function notify(title, message)
		if not Window.Destroyed then WindUI:Notify({ Title = title, Content = message, Duration = 4 }) end
	end
	local Home = Window:Tab({ Title = "Inicio", Icon = "house" })
	Hub.Tabs.Home = Home
	Home:Section({ Title = "Tu biblioteca de scripts", TextSize = 22 })
	Home:Paragraph({ Title = "Busca. Guarda. Ejecuta.", Desc = "Explora el catálogo, organiza tus favoritos y vuelve a lo que usaste recientemente." })
	local stats = Home:Paragraph({ Title = "Conectando al catálogo…", Desc = "Powered by ScriptBlox.com" })
	Hub.HomeStats = stats
	local panels = {}
	local function refresh()
		local count = Hub.Search and Hub.Search.CatalogCount
		stats:SetTitle(count and (count .. " scripts en el catálogo") or "Catálogo en línea")
		stats:SetDesc(#Store.Favorites .. " favoritos · " .. #Store.History .. " recientes\n"
			.. (Store.Persistent and "Biblioteca guardada en este dispositivo" or "Biblioteca disponible durante esta sesión")
			.. (Store.LastError and " · No se pudo leer o guardar algún dato local" or "") .. "\nPowered by ScriptBlox.com")
		for _, panel in ipairs(panels) do panel:Refresh() end
	end
	Hub.Search = attachSearch(WindUI, Window, {
		TabTitle = "Explorar", Store = Store, RenderTags = renderTags,
		OnChange = refresh,
	})
	local Search = Hub.Search
	Hub.Tabs.Explore = Search.Tab
	local homeActions = Home:HStack({})
	homeActions:Button({ Title = "Explorar", Icon = "search", Callback = function() Search.Tab:Select() end })
	homeActions:Button({ Title = "Este juego", Icon = "gamepad-2", Callback = function()
		Search.UI.Query:Set("")
		Search:SetFilters({ Universal = false, NoKey = false, Verified = false, CurrentGame = true }, false)
		Search:Load(1, ""); Search.Tab:Select()
	end })
	Home:Button({ Title = "Ver favoritos", Icon = "star", Callback = function() Hub.Tabs.Favorites:Select() end })
	Home:Button({ Title = "Abrir editor", Icon = "code", Callback = function() Hub.Tabs.Editor:Select() end })
	Home:Paragraph({ Title = "Etiquetas que sí informan", Desc = "Universal, con o sin clave y verificado aparecen según los datos del catálogo. Las fechas se muestran cuando el autor o proveedor las publica." })

	local function savedPanel(title, icon, collection)
		local Tab = Window:Tab({ Title = title, Icon = icon })
		local panel = { Tab = Tab, Page = 1, Rows = {}, Items = {} }
		local info = Tab:Paragraph({ Title = title, Desc = "" })
		local nav = Tab:HStack({})
		nav:Button({ Title = "Anterior", Callback = function() panel.Page = math.max(1, panel.Page - 1); panel:Refresh() end })
		nav:Button({ Title = "Siguiente", Callback = function()
			panel.Page = math.min(math.max(1, math.ceil(#Store[collection] / 20)), panel.Page + 1); panel:Refresh()
		end })
		if collection == "History" then
			Tab:Button({ Title = "Vaciar historial", Icon = "trash-2", Callback = function() Store:ClearHistory(); refresh() end })
		end
		for index = 1, 20 do
			panel.Rows[index] = Tab:Button({ Title = "", Desc = "", Size = "Small", Icon = "chevron-right", Callback = function()
				local entry = panel.Items[(panel.Page - 1) * 20 + index]
				if entry then Search:OpenItem(entry) end
			end })
		end
		function panel:Refresh()
			if Window.Destroyed then return end
			self.Items = Store[collection]
			local pages = math.max(1, math.ceil(#self.Items / 20))
			self.Page = math.min(self.Page, pages)
			info:SetTitle(title .. " · " .. #self.Items)
			info:SetDesc(#self.Items == 0 and (collection == "Favorites" and "Guarda un script desde Explorar para encontrarlo aquí." or "Los scripts vistos y ejecutados aparecerán aquí.")
				or "Página " .. self.Page .. "/" .. pages .. " · Pulsa un script para abrirlo")
			for index, row in ipairs(self.Rows) do
				local item = self.Items[(self.Page - 1) * 20 + index]
				row.ElementFrame.Visible = item ~= nil
				if item then
					row:SetTitle(text(item.title))
					row:SetDesc(text(item.game and item.game.name or "Universal")
						.. (collection == "History" and (" · " .. text(item.Action or "Visto")) or ""))
					renderTags(row, Search:Tags(item))
				end
			end
		end
		table.insert(panels, panel)
		panel:Refresh()
		return panel
	end
	Hub.Favorites = savedPanel("Favoritos", "star", "Favorites")
	Hub.History = savedPanel("Historial", "history", "History")
	Hub.Tabs.Favorites, Hub.Tabs.History = Hub.Favorites.Tab, Hub.History.Tab

	local Editor = Window:Tab({ Title = "Editor", Icon = "code" })
	Hub.Tabs.Editor = Editor
	Editor:Paragraph({ Title = "Editor local", Desc = "Carga el script seleccionado o pega tu propio código. El borrador solo se ejecuta al pulsar Ejecutar." })
	local input = Editor:Input({ Title = "Código Lua", Type = "Textarea", Value = "-- Escribe o pega tu código aquí.\n", Callback = function() end })
	Hub.EditorInput = input
	local sourceActions = Editor:HStack({})
	sourceActions:Button({ Title = "Cargar seleccionado", Icon = "download", Callback = function()
		if not Search.Code then notify("Sin selección", "Selecciona primero un script en Explorar."); return end
		if #Search.Code > 200000 then notify("Código demasiado grande", "Usa Ver, Copiar o Ejecutar desde Explorar."); return end
		input:Set(Search.Code)
	end })
	sourceActions:Button({ Title = "Copiar", Icon = "copy", Callback = function()
		local copy = setclipboard or toclipboard
		if copy then
			local ok = pcall(copy, input.Value or "")
			notify(ok and "Borrador copiado" or "No se pudo copiar", "")
		else notify("Portapapeles no disponible", "") end
	end })
	Hub.RunEditor = function() return Search:ExecuteCode(input.Value, "Editor local") end
	Editor:Button({ Title = "Ejecutar borrador", Icon = "play", Callback = Hub.RunEditor })
	local draftPath = "WindUI/script-hub/editor-draft.lua"
	Hub.SaveDraft = function()
		if not writefile then notify("Guardado no disponible", ""); return false end
		if #(input.Value or "") > 200000 then notify("Borrador demasiado grande", "Máximo 200.000 bytes para guardar y abrir."); return false end
		local ok = pcall(function()
			if makefolder and isfolder and not isfolder("WindUI/script-hub") then makefolder("WindUI/script-hub") end
			writefile(draftPath, input.Value or "")
		end)
		notify(ok and "Borrador guardado" or "No se pudo guardar", "Se guarda en este dispositivo.")
		return ok
	end
	Hub.LoadDraft = function()
		if not readfile then notify("Lectura no disponible", ""); return false end
		local ok, code = pcall(readfile, draftPath)
		if not ok or type(code) ~= "string" then notify("No hay borrador guardado", ""); return false end
		if #code > 200000 then notify("Borrador demasiado grande", "Máximo 200.000 bytes en el editor."); return false end
		input:Set(code); return true
	end
	local draftActions = Editor:HStack({})
	draftActions:Button({ Title = "Guardar borrador", Icon = "save", Callback = Hub.SaveDraft })
	draftActions:Button({ Title = "Abrir guardado", Icon = "folder-open", Callback = Hub.LoadDraft })

	local Settings = Window:Tab({ Title = "Ajustes", Icon = "settings" })
	Hub.Tabs.Settings = Settings
	Settings:Paragraph({ Title = "Tu espacio", Desc = "El fondo de flores y los controles originales de WindUI se mantienen. Los cambios se recuerdan en este dispositivo." })
	local initializing, applyVersion, saveVersion = true, 0, 0
	local function saveLater()
		saveVersion += 1
		local token = saveVersion
		task.delay(0.4, function() if token == saveVersion then Store:Save(); refresh() end end)
	end
	local function applyBackground()
		applyVersion += 1
		local token = applyVersion
		task.delay(0.12, function()
			if token ~= applyVersion or Window.Destroyed then return end
			if not Store.Settings.Background then Window:RemoveGIFBackground(); return end
			local config = table.clone(Background)
			config.Enabled, config.FPS, config.Transparency = true, Store.Settings.FPS, Store.Settings.Transparency
			Window:SetGIFBackground(config)
			Window.UIElements.GIFBackground.ScaleType = Enum.ScaleType.Crop
		end)
	end
	local enabled = Settings:Toggle({ Title = "Fondo animado", Value = Store.Settings.Background, Callback = function(value)
		if initializing then return end
		Store.Settings.Background = value; applyBackground(); saveLater()
	end })
	local transparency = Settings:Slider({ Title = "Transparencia del fondo", Step = 0.05,
		Value = { Min = 0, Max = 1, Default = Store.Settings.Transparency }, Callback = function(value)
			if initializing then return end
			Store.Settings.Transparency = value
			Window:SetGIFBackgroundTransparency(value); saveLater()
		end })
	local fps = Settings:Slider({ Title = "Velocidad del fondo (FPS)", Step = 1,
		Value = { Min = 1, Max = 30, Default = math.min(30, Store.Settings.FPS) }, Callback = function(value)
			if initializing then return end
			Store.Settings.FPS = value; applyBackground(); saveLater()
		end })
	Hub.SettingsUI = { Enabled = enabled, Transparency = transparency, FPS = fps }
	Settings:Button({ Title = "Restaurar fondo original", Icon = "rotate-ccw", Callback = function()
		enabled:Set(true); transparency:Set(0.6); fps:Set(10)
	end })
	Settings:Button({ Title = "Vaciar caché de búsqueda", Icon = "refresh-cw", Callback = function()
		Search.Cache, Search.CacheOrder = {}, {}; notify("Caché vaciada", "La próxima búsqueda consultará el catálogo.")
	end })
	local storage = Settings:Paragraph({ Title = "Biblioteca local", Desc = Store.Persistent and "Favoritos, historial y ajustes se guardan en este dispositivo." or "El executor permite guardar solo durante esta sesión." })
	Settings:Button({ Title = "Guardar biblioteca ahora", Icon = "save", Callback = function()
		local ok = Store:Save()
		storage:SetDesc(ok and "Biblioteca guardada correctamente." or "No se pudo guardar; los datos siguen disponibles en esta sesión.")
	end })
	initializing = false
	refresh()
	Search:RefreshCatalog()
	Home:Select()
	return Hub
end
