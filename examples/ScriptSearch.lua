-- Integrated ScriptBlox browser. No remote script runs until Execute is pressed.
return function(WindUI, Window, Options)
	Options = Options or {}
	local Http = game:GetService("HttpService")
	local BASE = "https://scriptblox.com"
	local PAGE_SIZE, CACHE_LIMIT, PREVIEW_LIMIT = 20, 6, 16000
	local Browser = {
		Page = 1, TotalPages = 0, Query = "", Results = {}, Selected = nil,
		Code = nil, Busy = false, Ready = false, Version = 0, SelectionVersion = 0,
		Cache = {}, CacheOrder = {}, CatalogPages = nil, LastError = nil,
		CatalogCount = nil, Filters = { Universal = false, NoKey = false, Verified = false, CurrentGame = false, Sort = "updatedAt" },
	}
	local Tab = Window:Tab({ Title = Options.TabTitle or "Scripts", Icon = "search" })
	Browser.Tab = Tab
	local status = Tab:Paragraph({ Title = "Buscador de scripts", Desc = "Conectando… · Powered by ScriptBlox.com" })
	local details, preview, actions, navigation, queryInput, backButton
	local rows, actionButtons = {}, {}
	local filterWidgets, filterByKey = {}, {}
	local filterButton, favoriteButton
	local filtersShown, syncingFilters, filtersInitialized = false, false, false
	local showingCode = false
	local function visible(element, value)
		if element and element.ElementFrame then element.ElementFrame.Visible = value end
	end
	local function updateVisibility()
		visible(details, Browser.Selected ~= nil)
		visible(actions, Browser.Selected ~= nil)
		visible(preview, showingCode)
		visible(backButton, showingCode)
		visible(queryInput, not showingCode)
		visible(navigation, not showingCode)
		visible(filterButton, not showingCode)
		for _, widget in ipairs(filterWidgets) do visible(widget, filtersShown and not showingCode) end
		for index, row in ipairs(rows) do
			visible(row, not showingCode and Browser.Ready and Browser.Results[index] ~= nil)
		end
	end
	local function actionReady(ready)
		for _, button in ipairs(actionButtons) do
			if ready then button:Unlock() else button:Lock() end
		end
	end
	local function text(value)
		return tostring(value or ""):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
	end
	local function message(title, description)
		if Window.Destroyed then return end
		status:SetTitle(title)
		status:SetDesc((description or "") .. "\nPowered by ScriptBlox.com")
	end
	local function notify(title, description)
		if not Window.Destroyed then
			WindUI:Notify({ Title = title, Content = description, Duration = 4 })
		end
	end
	local function changed()
		if Options.OnChange then Options.OnChange(Browser) end
	end
	function Browser:Tags(item)
		local names = {}
		if item.isUniversal == true then table.insert(names, "Universal") end
		if item.key == false then table.insert(names, "Sin clave") elseif item.key == true then table.insert(names, "Con clave") end
		if item.verified == true then table.insert(names, "Verificado") end
		local date = type(item.updatedAt) == "string" and item.updatedAt:match("^%d%d%d%d%-%d%d%-%d%d")
		if date then table.insert(names, "Actualizado " .. date) end
		return names
	end
	local function renderTags(row, item)
		if Options.RenderTags then Options.RenderTags(row, Browser:Tags(item)) end
	end
	local function favoriteLabel()
		if favoriteButton and Browser.Selected then
			favoriteButton:SetTitle(Options.Store:IsFavorite(Browser.Selected) and "Quitar" or "Guardar")
		end
	end
	local function requestJSON(path)
		local transport = request or http_request or (syn and syn.request)
		local body
		if transport then
			local response = transport({ Url = BASE .. path, Method = "GET", Headers = { Accept = "application/json" } })
			assert(type(response) == "table", "El executor no devolvió una respuesta HTTP")
			local code = tonumber(response.StatusCode) or 200
			assert(code >= 200 and code < 300, "HTTP " .. code .. ". Reintenta en unos segundos.")
			body = response.Body
		else
			body = game:HttpGet(BASE .. path)
		end
		assert(type(body) == "string" and #body <= 8 * 1024 * 1024, "Respuesta vacía o demasiado grande")
		local ok, decoded = pcall(Http.JSONDecode, Http, body)
		assert(ok and type(decoded) == "table", "El catálogo no devolvió JSON válido")
		if decoded.message and not decoded.result and not decoded.script then error(tostring(decoded.message), 0) end
		return decoded
	end
	local function remember(key, value)
		if not Browser.Cache[key] then table.insert(Browser.CacheOrder, key) end
		Browser.Cache[key] = { Value = value, Time = os.clock() }
		while #Browser.CacheOrder > CACHE_LIMIT do
			Browser.Cache[table.remove(Browser.CacheOrder, 1)] = nil
		end
	end
	local function catalogDescription()
		if Browser.CatalogCount then return Browser.CatalogCount .. " scripts informados por ScriptBlox" end
		if Browser.CatalogPages and Browser.CatalogPages > 2500 then
			return "Catálogo > 50.000 scripts · " .. Browser.CatalogPages .. " páginas informadas por ScriptBlox"
		end
		return "Catálogo en línea · " .. tostring(Browser.CatalogPages or "?") .. " páginas informadas"
	end
	local function resetSelection()
		Browser.SelectionVersion += 1
		Browser.Selected, Browser.Code = nil, nil
		details:SetTitle("Selecciona un resultado")
		details:SetDesc("Ver, copiar o ejecutar su código desde esta ventana.")
		preview:SetCode("-- Selecciona un script en Resultados.")
		showingCode = false
		actionReady(false)
		updateVisibility()
	end
	function Browser:ShowCode()
		if not self.Code then return false end
		showingCode = true
		updateVisibility()
		Tab.UIElements.ContainerFrame.CanvasPosition = Vector2.zero
		return true
	end
	function Browser:ShowResults()
		showingCode = false
		updateVisibility()
		Tab.UIElements.ContainerFrame.CanvasPosition = Vector2.zero
	end
	function Browser:Select(index)
		if not self.Ready or self.Busy then return false end
		local item = self.Results[index]
		if not item then return false end
		return self:SelectItem(item, index)
	end
	function Browser:SelectItem(item, index)
		if type(item) ~= "table" then return false end
		self.SelectionVersion += 1
		local selectionVersion = self.SelectionVersion
		self.Selected, self.Code = item, nil
		details:SetTitle(text(item.title))
		details:SetDesc(text(item.game and item.game.name or "Universal")
			.. " · " .. (item.key and "Con clave" or "Sin clave")
			.. " · " .. (item.verified and "Verificado por ScriptBlox" or "Sin verificar"))
		renderTags(details, item)
		favoriteLabel()
		preview:SetCode("-- Cargando código…")
		actionReady(false)
		for n, row in ipairs(rows) do
			local result = self.Results[n]
			if result then row:SetTitle((n == index and "✓ " or "") .. text(result.title)) end
		end
		updateVisibility()
		Tab.UIElements.ContainerFrame.CanvasPosition = Vector2.zero
		if Options.Store then Options.Store:Record(item, "Visto") end
		changed()
		task.spawn(function()
			local ok, code = pcall(function()
				if type(item.script) == "string" and item.script ~= "" then return item.script end
				local identifier = item.slug or item._id
				assert(type(identifier) == "string", "El resultado no tiene identificador")
				local response = requestJSON("/api/script/" .. Http:UrlEncode(identifier))
				assert(type(response.script) == "table", "No se encontraron detalles del script")
				return response.script.script
			end)
			if Window.Destroyed or selectionVersion ~= self.SelectionVersion then return end
			if not ok or type(code) ~= "string" or code == "" then
				preview:SetCode("-- Código no disponible para este resultado.")
				self.LastError = tostring(code)
				notify("Código no disponible", text(ok and "El proveedor no incluye el código." or code))
				return
			end
			self.Code = code
			local displayed = code
			if #displayed > PREVIEW_LIMIT then
				displayed = displayed:sub(1, PREVIEW_LIMIT)
				-- Avoid splitting a UTF-8 codepoint at the preview boundary.
				while not utf8.len(displayed) do displayed = displayed:sub(1, -2) end
				displayed ..= "\n-- Vista parcial. Copiar y Ejecutar usan el código completo."
			end
			preview:SetCode(displayed)
			actionReady(true)
		end)
		return true
	end
	function Browser:OpenItem(item)
		self.Version += 1
		self.Busy = false
		showingCode = false
		Tab:Select()
		return self:SelectItem(item)
	end
	function Browser:ToggleFavorite()
		if not Options.Store or not self.Selected then return false end
		local added, err = Options.Store:ToggleFavorite(self.Selected)
		favoriteLabel(); changed()
		notify(err and "No se pudo guardar" or added and "Favorito guardado" or "Favorito retirado", err or text(self.Selected.title))
		return added
	end
	function Browser:SetFilters(filters, reload)
		for _, key in ipairs({ "Universal", "NoKey", "Verified", "CurrentGame" }) do
			if filters[key] ~= nil then self.Filters[key] = filters[key] == true end
		end
		if filters.Sort and table.find({ "updatedAt", "views", "likeCount" }, filters.Sort) then self.Filters.Sort = filters.Sort end
		syncingFilters = true
		local count = 0
		for _, key in ipairs({ "Universal", "NoKey", "Verified", "CurrentGame" }) do
			if self.Filters[key] then count += 1 end
			if filterByKey[key] then filterByKey[key]:Set(self.Filters[key]) end
		end
		syncingFilters = false
		if filterButton then filterButton:SetTitle(count > 0 and "Filtros (" .. count .. ")" or "Filtros y orden") end
		if reload ~= false then self:Load(1) end
	end
	function Browser:RefreshCatalog()
		task.spawn(function()
			local ok, response = pcall(requestJSON, "/api/script/fetch?page=1&max=1")
			if Window.Destroyed then return end
			if ok and response.result and tonumber(response.result.max) == 1 then
				self.CatalogCount = tonumber(response.result.totalPages)
				changed()
			end
		end)
	end
	function Browser:Load(page, query)
		if Window.Destroyed then return end
		query = tostring(query == nil and self.Query or query):match("^%s*(.-)%s*$")
		page = math.max(1, math.floor(tonumber(page) or 1))
		self.Version += 1
		local version = self.Version
		self.Busy, self.Ready, self.LastError = true, false, nil
		local filters = table.clone(self.Filters)
		resetSelection()
		message("Buscando…", query == "" and "Consultando el catálogo" or text(query))
		task.delay(20, function()
			if version == self.Version and self.Busy and not Window.Destroyed then
				self.Version += 1
				self.Busy = false
				self.LastError = "Tiempo de espera agotado"
				message("Sin respuesta del catálogo", "Reintenta la búsqueda.")
			end
		end)
		task.spawn(function()
			local ok, data = pcall(function()
				local params = "page=" .. page .. "&max=" .. PAGE_SIZE .. "&sortBy=" .. filters.Sort
				if filters.Universal then params ..= "&universal=1" end
				if filters.NoKey then params ..= "&key=0" end
				if filters.Verified then params ..= "&verified=1" end
				if filters.CurrentGame then params ..= "&placeId=" .. tostring(game.PlaceId) end
				local key = query .. "\0" .. params
				local cached = self.Cache[key]
				if cached and os.clock() - cached.Time < 60 then return cached.Value end
				local path = query == "" and "/api/script/fetch?" or "/api/script/search?q=" .. Http:UrlEncode(query) .. "&"
				local response = requestJSON(path .. params)
				assert(type(response.result) == "table" and type(response.result.scripts) == "table", "Respuesta de resultados inválida")
				remember(key, response.result)
				return response.result
			end)
			if Window.Destroyed or version ~= self.Version then return end
			self.Busy = false
			if not ok then
				self.LastError = tostring(data)
				message("No se pudo buscar", text(data) .. "\nPrueba un término más específico o reintenta.")
				return
			end
			self.Page, self.Query = page, query
			self.TotalPages = math.max(0, math.floor(tonumber(data.totalPages) or 0))
			if query == "" and not (filters.Universal or filters.NoKey or filters.Verified or filters.CurrentGame) then self.CatalogPages = self.TotalPages end
			self.Results, self.Ready = {}, true
			for _, item in ipairs(data.scripts) do
				if #self.Results >= PAGE_SIZE then break end
				if type(item) == "table" and type(item.title) == "string" then
					table.insert(self.Results, item)
				end
			end
			for index, row in ipairs(rows) do
				local item = self.Results[index]
				if item then
					row:SetTitle(text(item.title))
					row:SetDesc(text(item.game and item.game.name or "Universal") .. (item.key and " · Con clave" or " · Sin clave"))
					renderTags(row, item)
				end
			end
			updateVisibility()
			message(#self.Results .. " resultados · Página " .. page .. "/" .. self.TotalPages, catalogDescription())
			changed()
		end)
	end
	function Browser:Copy()
		if not self.Code then notify("Selecciona un script", "Espera a que su código termine de cargar."); return false end
		local copy = setclipboard or toclipboard
		if not copy then notify("Portapapeles no disponible", "Tu executor no ofrece esta función."); return false end
		local ok, err = pcall(copy, self.Code)
		notify(ok and "Código copiado" or "No se pudo copiar", ok and "Se copió el código completo." or text(err))
		return ok
	end
	function Browser:ExecuteCode(code, title, item)
		if not code or code == "" then notify("Código vacío", "Carga o escribe un script primero."); return false end
		if not loadstring then notify("Ejecución no disponible", "Tu entorno no ofrece loadstring."); return false end
		local compiled, callback, err = pcall(loadstring, code, tostring(title or "Script Hub"))
		if not compiled or not callback then
			notify("Error de compilación", text(err or callback)); return false
		end
		task.spawn(function()
			local trace = debug and debug.traceback or function(messageText) return tostring(messageText) end
			local ok, messageText = xpcall(callback, trace)
			if not ok then notify("Error del script", text(messageText):sub(1, 400)) end
			if item and Options.Store then Options.Store:Record(item, ok and "Ejecutado" or "Error"); changed() end
		end)
		return true
	end
	function Browser:Run()
		if not self.Code then notify("Selecciona un script", "Espera a que su código termine de cargar."); return false end
		return self:ExecuteCode(self.Code, "ScriptBlox: " .. tostring(self.Selected and self.Selected.title), self.Selected)
	end

	local queryValue = ""
	queryInput = Tab:Input({ Title = "Buscar scripts", Placeholder = "Nombre o juego", Callback = function(value) queryValue = value end })
	navigation = Tab:HStack({})
	navigation:Button({ Title = "Buscar", Icon = "search", Callback = function()
		Browser.Cache = {}; Browser.CacheOrder = {}; Browser:Load(1, queryValue)
	end })
	navigation:Button({ Title = "Anterior", Icon = "chevron-left", Callback = function()
		if not Browser.Busy and Browser.Page > 1 then Browser:Load(Browser.Page - 1) end
	end })
	navigation:Button({ Title = "Siguiente", Icon = "chevron-right", Callback = function()
		if not Browser.Busy and Browser.Page < Browser.TotalPages then Browser:Load(Browser.Page + 1) end
	end })
	filterButton = Tab:Button({ Title = "Filtros y orden", Icon = "sliders-horizontal", Callback = function()
		filtersShown = not filtersShown; updateVisibility()
	end })
	for _, definition in ipairs({ { "Universal", "Universales" }, { "NoKey", "Sin clave" }, { "Verified", "Verificados por ScriptBlox" }, { "CurrentGame", "Solo este juego" } }) do
		local key = definition[1]
		local widget = Tab:Toggle({ Title = definition[2], Value = false, Callback = function(value)
			if filtersInitialized and not syncingFilters then Browser:SetFilters({ [key] = value }) end
		end })
		filterByKey[key] = widget; table.insert(filterWidgets, widget)
	end
	local sortValues = { ["Actualización reciente"] = "updatedAt", ["Más vistos"] = "views", ["Más valorados"] = "likeCount" }
	table.insert(filterWidgets, Tab:Dropdown({ Title = "Ordenar", Values = { "Actualización reciente", "Más vistos", "Más valorados" },
		Value = "Actualización reciente", Callback = function(value)
			if filtersInitialized and sortValues[value] then Browser:SetFilters({ Sort = sortValues[value] }) end
		end }))
	filtersInitialized = true
	details = Tab:Paragraph({ Title = "Selecciona un script", Desc = "" })
	actions = Tab:HStack({})
	actionButtons[1] = actions:Button({ Title = "Ver", Icon = "code", Callback = function() Browser:ShowCode() end })
	actionButtons[2] = actions:Button({ Title = "Copiar", Icon = "copy", Callback = function() Browser:Copy() end })
	actionButtons[3] = actions:Button({ Title = "Ejecutar", Icon = "play", Callback = function() Browser:Run() end })
	if Options.Store then
		favoriteButton = actions:Button({ Title = "Guardar", Icon = "star", Callback = function() Browser:ToggleFavorite() end })
	end
	backButton = Tab:Button({ Title = "Volver a resultados", Icon = "arrow-left", Callback = function() Browser:ShowResults() end })
	preview = Tab:Code({ Title = "Código del script seleccionado", Code = "-- Selecciona un script.",
		CodeSize = 13, Height = UDim.new(0, 230), CanCopied = false })
	for index = 1, PAGE_SIZE do
		rows[index] = Tab:Button({ Title = "", Desc = "", Size = "Small", Icon = "chevron-right", Callback = function()
			Browser:Select(index)
		end })
	end
	Browser.UI = { Status = status, Rows = rows, Details = details, Preview = preview, Query = queryInput,
		Actions = actions, ActionButtons = actionButtons, Navigation = navigation, Back = backButton,
		Filters = filterByKey, FilterWidgets = filterWidgets, FilterButton = filterButton, Favorite = favoriteButton }
	updateVisibility()
	Tab:Select()
	Browser:Load(1, "")
	return Browser
end
