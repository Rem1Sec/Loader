local previousLoader = (getgenv and getgenv() or _G).__YallHolyLoader
if previousLoader and previousLoader.lib and previousLoader.lib.alive then previousLoader.lib:unload() end
local preserved = {}
local host = (type(gethui) == "function" and gethui()) or game:GetService("CoreGui")
for _, gui in ipairs(host:GetChildren()) do
	if gui:IsA("ScreenGui") and gui.Name == "yall_holy_ui" then
		preserved[#preserved + 1] = gui
		gui.Name = "yall_holy_preserved_ui"
	end
end
local LIB_URL = "https://raw.githubusercontent.com/Rem1Sec/yall-holy/main/yall_holy.lua"
local fetched, libSource = pcall(function() return game:HttpGet(LIB_URL) end)
local lib
if fetched and type(libSource) == "string" and #libSource > 0 then
	local boundary = libSource:find("local ok2, err = xpcall(function()", 1, true)
	if boundary then libSource = libSource:sub(1, boundary - 1) end
	local libChunk, libErr = loadstring(libSource .. "\nreturn lib", "=yall holy lib")
	if libChunk then
		local okLib, result = pcall(libChunk)
		if okLib then lib = result else warn("[yall holy loader] library error: " .. tostring(result)) end
	else
		warn("[yall holy loader] library compile error: " .. tostring(libErr))
	end
else
	warn("[yall holy loader] could not download the library from GitHub: " .. tostring(libSource))
end
for _, gui in ipairs(preserved) do if gui.Parent then gui.Name = "yall_holy_ui" end end
if not lib then return end
lib.scr.Name = "yall_holy_loader"
lib.autosave = false
lib._autocfg = function() end
lib._gamedir = lib:rootdir() .. "/Loader"
lib:setwatermark(false)
lib:sethotkeys(false)

local env = getgenv and getgenv() or _G
local loader = {
	lib = lib,
	games = {},
	loading = false,
}
env.__YallHolyLoader = loader
lib:onunload(function()
	if env.__YallHolyLoader == loader then env.__YallHolyLoader = nil end
end)

local statusColors = {
	Supported = Color3.fromRGB(82, 224, 159),
	Updating = Color3.fromRGB(255, 190, 83),
	Soon = Color3.fromRGB(255, 190, 83),
	Discontinued = Color3.fromRGB(245, 78, 103),
}
loader.games = {
	{ id = 3203685552, name = "BEAR (Alpha)", status = "Supported", icon = "rbxassetid://129894077297837", url = "https://flowauth.net/v1/loaders/bear-alpha.lua" },
	{ id = 2214661900, name = "Survive In Area 51", status = "Discontinued", icon = "rbxassetid://103668606592732", url = "https://flowauth.net/v1/loaders/SIN51.lua" },
	{ id = 7239319209, name = "Ohio.", status = "Soon", icon = "rbxassetid://135219069939611", url = "" },
}
local byId = {}
for _, entry in ipairs(loader.games) do entry.color = statusColors[entry.status]; byId[entry.id] = entry end
local current = byId[game.PlaceId]

local function buildLoaderUI()
	local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1024, 768)
local width = math.min(780, viewport.X - 24)
local height = math.min(500, viewport.Y - 24)
local win = lib:window({ title = "yall holy", bind = "LeftControl", size = Vector2.new(width, height), side = math.min(170, math.max(124, math.floor(width * 0.22))) })
loader.window = win
local tab = win:tab({ name = "Loader", icon = "gamepad-2", tip = "all games" })
local pg = tab._pg
pg.left.Size = UDim2.new(1, 0, 1, -44)
pg.right.Visible = false
for _, header in ipairs(tab.page:GetChildren()) do
	if header:IsA("Frame") and header:FindFirstChildOfClass("TextBox") then
		local searchButton = header:FindFirstChildOfClass("ImageButton")
		if searchButton then searchButton.Visible = false end
	end
end

local function fail(entry, message)
	loader.loading = false
	loader.lastError = tostring(message)
	if not lib.alive then return end
	win:toggle(true)
	lib:popup({ title = "Launch failed", text = entry.name .. "\n" .. tostring(message), icon = "bug" })
	warn("[yall holy loader] " .. entry.name .. ": " .. tostring(message))
end

local function launch(id)
	local entry = byId[id]
	if not entry or not lib.alive or loader.loading then return end
	if entry.url == "" then
		lib:notify({ title = entry.name, text = "Soon — the script is not available yet.", icon = "clock", tone = entry.color, life = 5 })
		return
	end
	loader.loading = true
	loader.lastError = nil
	lib:notify({ title = entry.name, text = entry.status == "Discontinued" and "Launching through Flowauth. Discontinued — no more updates." or "Launching through Flowauth...", icon = "rocket", tone = entry.color, life = 4 })
	task.spawn(function()
		if not lib.alive then loader.loading = false; return end
		if type(loadstring) ~= "function" then fail(entry, "This executor does not support loadstring."); return end
		local fetched, source = pcall(function() return game:HttpGet(entry.url) end)
		if not lib.alive then loader.loading = false; return end
		if not fetched then fail(entry, source); return end
		if source:match("^%s*$") then fail(entry, "Flowauth returned an empty response."); return end
		local compiled, chunk, compileError = pcall(loadstring, source, "=Flowauth / " .. entry.name)
		if not compiled or not chunk then fail(entry, compiled and compileError or chunk); return end
		local success, result = pcall(chunk)
		loader.loading = false
		if not success then fail(entry, result); return end
		loader.lastLaunch = entry.id
		if lib.alive then win:toggle(false) end
	end)
end
loader.launch = launch

local items = {}
for _, entry in ipairs(loader.games) do items[#items + 1] = { Name = entry.name, Value = entry.id, Image = entry.icon } end
local gallery = tab:gallery({
	name = "Games", icon = "gamepad-2", side = "left", height = 290, cell = 166, gap = 8,
	search = true, tools = false, list = items, empty = "No games found.",
	callback = function(id) launch(id) end,
})
loader.gallery = gallery
local grid = gallery.cells[1].frame.Parent
local layout = grid:FindFirstChildOfClass("UIGridLayout")
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Top
grid.ClipsDescendants = true
local padding = Instance.new("UIPadding")
padding.PaddingLeft = UDim.new(0, 6)
padding.PaddingRight = UDim.new(0, 6)
padding.PaddingTop = UDim.new(0, 6)
padding.PaddingBottom = UDim.new(0, 6)
padding.Parent = grid
local tools = grid.Parent:FindFirstChildOfClass("Frame")
local searchBox = tools:FindFirstChildOfClass("TextBox")
searchBox.Name = "GameSearch"
searchBox.PlaceholderText = "Search games..."
searchBox.Size = UDim2.fromScale(1, 1)
loader.searchBox = searchBox
local empty = grid:FindFirstChildOfClass("TextLabel")
empty.Parent = grid.Parent
empty.LayoutOrder = 4
empty.Size = UDim2.new(1, 0, 0, 32)
empty.TextSize = 12
for _, cell in ipairs(gallery.cells) do
	local entry = byId[cell.item.value]
	local frame = cell.frame
	frame.Name = "Game_" .. tostring(entry.id)
	frame.ClipsDescendants = true
	frame:SetAttribute("PlaceId", entry.id)
	frame:SetAttribute("Status", entry.status)
	cell.st.Enabled = false
	local border = Instance.new("UIStroke")
	border.Name = "CardBorder"
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Transparency = 0.55
	border.Color = lib.theme.line
	border.Parent = frame
	lib.conns[#lib.conns + 1] = cell.st:GetPropertyChangedSignal("Color"):Connect(function()
		border.Color = lib.theme.line
	end)
	for _, child in ipairs(frame:GetChildren()) do
		if child:IsA("ImageLabel") then
			child.Name = "GameIcon"
			child.Size = UDim2.new(1, -8, 1, -54)
			child.ScaleType = Enum.ScaleType.Fit
		elseif child:IsA("TextLabel") then
			child.Position = UDim2.new(0, 4, 1, -22)
			child.Size = UDim2.new(1, -8, 0, 28)
			child.TextSize = 11
			child.TextWrapped = true
			child.TextColor3 = lib.theme.text
		end
	end
	local badge = Instance.new("TextLabel")
	badge.Name = "GameStatus"
	badge.AnchorPoint = Vector2.new(0, 1)
	badge.Position = UDim2.new(0, 4, 1, -5)
	badge.Size = UDim2.new(1, -8, 0, 14)
	badge.BackgroundTransparency = 1
	badge.Font = Enum.Font.GothamBold
	badge.TextSize = 10
	badge.TextColor3 = entry.color
	badge.Text = entry.status
	badge.ZIndex = 8
	badge.Parent = frame
end
local scale = win.shell:FindFirstChildOfClass("UIScale")
local function resizeGrid()
	local available = grid.AbsoluteSize.X / scale.Scale
	if available < 1 then return end
	local columns = available >= 420 and 3 or (available >= 230 and 2 or 1)
	local size = math.floor((available - 12 - 8 * (columns - 1)) / columns)
	layout.CellSize = UDim2.fromOffset(size, size)
	layout.FillDirectionMaxCells = columns
	local count = 0
	for _, cell in ipairs(gallery.cells) do if cell.frame.Visible then count = count + 1 end end
	grid.Visible = count > 0
	grid.Size = UDim2.new(1, 0, 0, count > 0 and (math.ceil(count / columns) * (size + 8) - 8 + 12) or 0)
	empty.Visible = count == 0
end
function gallery:search(query)
	query = tostring(query or "")
	self.query = query
	for _, cell in ipairs(self.cells) do
		local text = string.lower(cell.item.name .. " " .. tostring(cell.item.value))
		local matches = true
		for word in string.lower(query):gmatch("%S+") do
			if not text:find(word, 1, true) then matches = false; break end
		end
		cell.frame.Visible = matches
	end
	grid.CanvasPosition = Vector2.new()
	pg.left.CanvasPosition = Vector2.new()
	resizeGrid()
end
lib.conns[#lib.conns + 1] = grid:GetPropertyChangedSignal("AbsoluteSize"):Connect(resizeGrid)
lib.conns[#lib.conns + 1] = scale:GetPropertyChangedSignal("Scale"):Connect(resizeGrid)
task.defer(resizeGrid)

local footerSection = tab:section({ name = "Loader", side = "left" })
local unloadButton = footerSection:button({ name = "Unload loader", icon = "power", callback = function() lib:unload() end })
local footer = Instance.new("Frame")
footer.Name = "LoaderFooter"
footer.BackgroundTransparency = 1
footer.AnchorPoint = Vector2.new(0, 1)
footer.Position = UDim2.fromScale(0, 1)
footer.Size = UDim2.new(1, 0, 0, 32)
footer.ZIndex = 6
footer.Parent = pg.cg
unloadButton.__frame.Parent = footer
unloadButton.__frame.Size = UDim2.fromScale(1, 1)
for i = #pg.elems, 1, -1 do if pg.elems[i].frame == unloadButton.__frame then table.remove(pg.elems, i) end end
for i = #pg.cards, 1, -1 do if pg.cards[i] == footerSection.card then table.remove(pg.cards, i) end end
pg.titles[footerSection.card] = nil
footerSection.card:Destroy()
loader.unloadButton = unloadButton
if lib.mobile then lib:openericon("rbxassetid://99293705721130") end

	task.defer(function()
		if not lib.alive then return end
		lib:notify({ title = "Unsupported game", text = current and (current.name .. " is not supported yet (Soon). Choose another game card to launch manually.") or "No script for this game. Choose a game card to launch manually.", icon = "info", tone = statusColors.Soon, life = 8 })
	end)
end

if current and current.url ~= "" then
	loader.loading = true
	loader.lastError = nil
	lib:notify({ title = current.name, text = current.status == "Discontinued" and "Launching through Flowauth. Discontinued — no more updates." or "Launching through Flowauth...", icon = "rocket", tone = current.color, life = 4 })
	task.spawn(function()
		local entry = current
		local function directFail(message)
			loader.loading = false
			loader.lastError = tostring(message)
			warn("[yall holy loader] " .. entry.name .. ": " .. tostring(message))
			if lib.alive then lib:popup({ title = "Launch failed", text = entry.name .. "\n" .. tostring(message), icon = "bug" }) end
		end
		if type(loadstring) ~= "function" then directFail("This executor does not support loadstring."); return end
		local fetched, source = pcall(function() return game:HttpGet(entry.url) end)
		if not fetched then directFail(source); return end
		if source:match("^%s*$") then directFail("Flowauth returned an empty response."); return end
		local compiled, chunk, compileError = pcall(loadstring, source, "=Flowauth / " .. entry.name)
		if not compiled or not chunk then directFail(compiled and compileError or chunk); return end
		local success, result = pcall(chunk)
		loader.loading = false
		if not success then directFail(result); return end
		loader.lastLaunch = entry.id
		if lib.alive then lib:unload() end
	end)
else
	buildLoaderUI()
end
