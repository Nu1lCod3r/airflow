--[[
	Airflow — Luau UI library for Roblox executors (Instance-based rendering).
	Style recreated from the Airflow CS:GO cheat menu: dark window, frosted
	header, sidebar with accent bar, subtabs, two-column grouped controls.

	Usage:
		local Airflow = loadstring(game:HttpGet("...airflow.lua"))()
		or:  local Airflow = require(path) / dofile

	API overview:
		local ui = Airflow:CreateWindow({ Title = "Airflow", Size = UDim2... })
		local tab = ui:Tab("Visuals", "rbxassetid://...")   -- icon optional
		local page = tab:Page("Enemy")                      -- subtab
		local grp = page:Group("General", "Left"|"Right")
		grp:Toggle / :Slider / :Dropdown / :Keybind / :Color
		ui:Toggle() / ui:SetVisible(bool) / ui:Notify(text)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")
local CoreGui = game:GetService("CoreGui")

local LP = Players.LocalPlayer
local Mouse = LP and LP:GetMouse()
local Heartbeat = RunService.Heartbeat

---------------------------------------------------------------- theme
local theme = {
	accent        = Color3.fromRGB(140, 132, 240),
	bg            = Color3.fromRGB(16, 16, 16),
	sidebar       = Color3.fromRGB(19, 19, 19),
	header        = Color3.fromRGB(148, 140, 133),
	row           = Color3.fromRGB(30, 30, 30),
	rowHover      = Color3.fromRGB(37, 37, 37),
	track         = Color3.fromRGB(22, 22, 22),
	text          = Color3.fromRGB(232, 232, 232),
	textDim       = Color3.fromRGB(150, 150, 150),
	textFaint     = Color3.fromRGB(105, 105, 105),
	white         = Color3.fromRGB(255, 255, 255),
}

---------------------------------------------------------------- helpers
local function new(cls, props, parent)
	local o = Instance.new(cls)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then o[k] = v end
	end
	if parent then o.Parent = parent end
	return o
end

local function corner(parent, r)
	return new("UICorner", { CornerRadius = UDim.new(0, r or 5) }, parent)
end

local function stroke(parent, color, alpha, thick)
	return new("UIStroke", {
		Color = color or theme.white,
		Transparency = alpha or 0.93,
		Thickness = thick or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

-- Roblox renamed UIPadding Pad* -> Padding*; support both
local padProbe = Instance.new("UIPadding")
local PAD = pcall(function() local _ = padProbe.PaddingLeft end) and "Padding" or "Pad"
padProbe:Destroy()

local function padding(parent, l, t, r, b)
	local p = new("UIPadding", {}, parent)
	p[PAD .. "Left"] = UDim.new(0, l or 0)
	p[PAD .. "Top"] = UDim.new(0, t or 0)
	p[PAD .. "Right"] = UDim.new(0, r or 0)
	p[PAD .. "Bottom"] = UDim.new(0, b or 0)
	return p
end

local function label(parent, text, size, color, align)
	return new("TextLabel", {
		BackgroundTransparency = 1,
		Text = text, TextSize = size or 12,
		TextColor3 = color or theme.text,
		Font = Enum.Font.Gotham,
		TextXAlignment = align or Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(1, 0, 1, 0),
	}, parent)
end

local function button(parent)
	local b = new("TextButton", {
		AutoButtonColor = false, BackgroundTransparency = 1,
		Text = "", Size = UDim2.new(1, 0, 1, 0),
	}, parent)
	return b
end

local function tween(obj, props, dur, style)
	TweenService:Create(obj, TweenInfo.new(dur or 0.16, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

local function hoverize(btn, base, hover)
	btn.BackgroundColor3 = base
	btn.MouseEnter:Connect(function() tween(btn, { BackgroundColor3 = hover, BackgroundTransparency = 0 }, 0.12) end)
	btn.MouseLeave:Connect(function() tween(btn, { BackgroundColor3 = base, BackgroundTransparency = 1 }, 0.12) end)
end

---------------------------------------------------------------- color utils
local colorUtils = {}

function colorUtils.hsv2rgb(h, s, v)
	local i = math.floor(h * 6)
	local f = h * 6 - i
	local p = v * (1 - s)
	local q = v * (1 - (f * s))
	local t = v * (1 - ((1 - f) * s))
	local m = i % 6
	if m == 0 then return v, t, p
	elseif m == 1 then return q, v, p
	elseif m == 2 then return p, v, t
	elseif m == 3 then return p, q, v
	elseif m == 4 then return t, p, v
	else return v, p, q end
end

function colorUtils.rgb2hsv(r, g, b)
	local max = math.max(r, g, b)
	local min = math.min(r, g, b)
	local d = max - min
	local h = 0
	if d ~= 0 then
		if max == r then h = ((g - b) / d) % 6
		elseif max == g then h = (b - r) / d + 2
		else h = (r - g) / d + 4 end
		h = h / 6
		if h < 0 then h = h + 1 end
	end
	local s = max == 0 and 0 or d / max
	return h, s, max
end

function colorUtils.hue2rgb(h)
	local r, g, b = colorUtils.hsv2rgb(h, 1, 1)
	return Color3.fromRGB(r * 255, g * 255, b * 255)
end

---------------------------------------------------------------- input overlay (popups live above scrolling content)
local overlay = new("Frame", {
	Name = "AirflowOverlay",
	BackgroundTransparency = 1,
	Position = UDim2.new(0.5, -300, 0.5, -200),
	Size = UDim2.new(0, 600, 0, 400),
	Visible = false,
	ZIndex = 40,
})
overlay.Parent = CoreGui

local openPopups = {}
local function registerPopup(frame, onOutside)
	for i = #openPopups, 1, -1 do
		if openPopups[i].frame == frame then table.remove(openPopups, i) end
	end
	table.insert(openPopups, { frame = frame, onOutside = onOutside })
end
local function closeAllPopups()
	for _, p in ipairs(openPopups) do
		if p.frame.Visible then
			p.frame.Visible = false
			if p.onOutside then p.onOutside() end
		end
	end
	table.clear(openPopups)
end

---------------------------------------------------------------- library root
local Airflow = {}
Airflow.__index = Airflow

function Airflow:CreateWindow(opts)
	opts = opts or {}
	local size = opts.Size or UDim2.new(0, 600, 0, 400)

	local gui = new("ScreenGui", {
		Name = opts.Name or "AirflowUI",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = opts.IgnoreGuiInset ~= false,
	})
	local ok, err = pcall(function() gui.Parent = CoreGui end)
	if not ok then gui.Parent = LP:WaitForChild("PlayerGui") end

	overlay.Position = UDim2.new(0.5, -(size.X.Offset / 2), 0.5, -(size.Y.Offset / 2))
	overlay.Size = size
	overlay.Visible = true

	local window = new("Frame", {
		Name = "Window",
		BackgroundColor3 = theme.bg,
		BackgroundTransparency = 0.02,
		Position = UDim2.new(0.5, -size.X.Offset / 2, 0.5, -size.Y.Offset / 2),
		Size = size,
		ClipsDescendants = true,
		Active = true,
		Parent = gui,
	})
	corner(window, 7)
	stroke(window, theme.white, 0.9, 1)

	-- frosted header
	local header = new("Frame", {
		Name = "Header",
		BackgroundColor3 = theme.header,
		BackgroundTransparency = 0.35,
		Size = UDim2.new(1, 0, 0, 34),
		Parent = window,
	})
	new("UIGradient", {
		Color = ColorSequence.new{
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 150, 150)),
		},
		Transparency = NumberSequence.new{
			NumberSequenceKeypoint.new(0, 0.55),
			NumberSequenceKeypoint.new(1, 0.25),
		},
	}, header)

	local logo = new("ImageLabel", {
		BackgroundTransparency = 1,
		Image = "rbxassetid://7734029372",
		ImageColor3 = theme.accent,
		Size = UDim2.new(0, 13, 0, 13),
		Position = UDim2.new(0.5, -34, 0.5, -7),
		Parent = header,
	})
	label(header, opts.Title or "Airflow", 13, theme.text, Enum.TextXAlignment.Left).Position = UDim2.new(0.5, -16, 0, 0)

	-- body: sidebar + content
	local body = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0, 34),
		Size = UDim2.new(1, 0, 1, -34),
		Parent = window,
	})

	local sidebar = new("Frame", {
		Name = "Sidebar",
		BackgroundColor3 = theme.sidebar,
		Size = UDim2.new(0, 130, 1, 0),
		Parent = body,
	})
	local sbList = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Parent = sidebar })
	new("UIListLayout", {
		Padding = UDim.new(0, 2),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	}, sbList)
	padding(sbList, 8, 12, 8, 0)

	local content = new("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 130, 0, 0),
		Size = UDim2.new(1, -130, 1, 0),
		Parent = body,
	})

	-- keybinds chip (left of window, like in Airflow)
	local keybinds = new("Frame", {
		Name = "Keybinds",
		BackgroundColor3 = theme.header,
		BackgroundTransparency = 0.35,
		Size = UDim2.new(0, 112, 0, 0),
		Visible = false,
		Parent = gui,
	})
	corner(keybinds, 3)
	label(keybinds, "  keybinds", 11, theme.text).Size = UDim2.new(1, 0, 0, 16)

	local self = setmetatable({
		gui = gui, window = window, overlay = overlay,
		sbList = sbList, content = content,
		tabs = {}, activeTab = nil, visible = true,
		keybinds = keybinds, keybindRows = {},
	}, Airflow)

	local function syncKeybindsPos()
		keybinds.Position = UDim2.new(
			window.Position.X.Scale, window.Position.X.Offset - 118,
			window.Position.Y.Scale, window.Position.Y.Offset + 170)
	end
	self.syncKeybindsPos = syncKeybindsPos
	syncKeybindsPos()

	-- drag
	local dragging, dragStart, startPos = false, nil, nil
	header.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			dragStart = input.Position
			startPos = window.Position
		end
	end)
	header.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local d = input.Position - dragStart
			window.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
			overlay.Position = window.Position
			syncKeybindsPos()
		end
	end)

	-- global click: close popups on outside click
	UserInputService.InputBegan:Connect(function(input, gp)
		if gp then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local pos = input.Position
			for i = #openPopups, 1, -1 do
				local p = openPopups[i]
				if p.frame.Visible then
					local ap = p.frame.AbsolutePosition
					local as = p.frame.AbsoluteSize
					local inside = pos.X >= ap.X and pos.X <= ap.X + as.X and pos.Y >= ap.Y and pos.Y <= ap.Y + as.Y
					if not inside then
						p.frame.Visible = false
						if p.onOutside then p.onOutside() end
						table.remove(openPopups, i)
					end
				end
			end
		end
	end)

	-- insert / remove key
	UserInputService.InputBegan:Connect(function(input, gp)
		if gp then return end
		if input.KeyCode == (opts.ToggleKey or Enum.KeyCode.Insert) then
			self:Toggle()
		end
	end)

	return self
end

function Airflow:Toggle()
	self:SetVisible(not self.visible)
end

function Airflow:SetVisible(v)
	self.visible = v
	self.window.Visible = v
	self.keybinds.Visible = v and self.keybinds.Visible or false
	if v and self.syncKeybindsPos then self.syncKeybindsPos() end
	closeAllPopups()
end

function Airflow:Notify(text, dur)
	local note = new("Frame", {
		BackgroundColor3 = theme.row,
		Size = UDim2.new(0, 180, 0, 26),
		Position = UDim2.new(0, 8, 1, 8),
		Parent = self.window,
	})
	corner(note, 4)
	stroke(note, theme.white, 0.92)
	label(note, "  " .. text, 11, theme.text)
	task.delay(dur or 2.5, function()
		tween(note, { BackgroundTransparency = 1 }, 0.3)
		task.wait(0.3)
		note:Destroy()
	end)
end

---------------------------------------------------------------- tabs
local Tab = {}
Tab.__index = Tab

function Airflow:Tab(name, icon)
	local self = self
	local item = new("Frame", {
		BackgroundColor3 = Color3.fromRGB(26, 26, 26),
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -16, 0, 28),
		Parent = self.sbList,
	})
	corner(item, 4)

	local bar = new("Frame", {
		BackgroundColor3 = theme.accent,
		Size = UDim2.new(0, 2, 0, 16),
		Position = UDim2.new(1, -2, 0.5, -8),
		BackgroundTransparency = 1,
		Parent = item,
	})
	corner(bar, 1)

	local ic
	if icon then
		ic = new("ImageLabel", {
			BackgroundTransparency = 1,
			Image = icon, ImageColor3 = theme.textDim,
			Size = UDim2.new(0, 13, 0, 13),
			Position = UDim2.new(0, 10, 0.5, -7),
			Parent = item,
		})
	end
	local txt = label(item, name, 12, theme.textDim)
	txt.Position = UDim2.new(0, ic and 28 or 12, 0, 0)
	txt.Size = UDim2.new(1, -(ic and 34 or 18), 1, 0)

	local btn = button(item)
	hoverize(btn, Color3.fromRGB(26, 26, 26), Color3.fromRGB(32, 32, 32))

	local tab = setmetatable({
		ui = self, name = name, item = item, bar = bar, txt = txt, ic = ic,
		pages = {}, activePage = nil,
		tabBar = nil, pagesHolder = nil,
	}, Tab)

	-- subtab bar + pages holder
	tab.tabBar = new("Frame", {
		BackgroundColor3 = Color3.fromRGB(24, 24, 24),
		Size = UDim2.new(1, -20, 0, 36),
		Position = UDim2.new(0, 10, 0, 10),
		Visible = false,
		Parent = self.content,
	})
	corner(tab.tabBar, 5)
	local tbList = new("Frame", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Parent = tab.tabBar,
	})
	new("UIListLayout", {
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = Enum.FillDirection.Horizontal,
	}, tbList)
	padding(tbList, 8, 0, 8, 0)

	tab.pagesHolder = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 10, 0, 54),
		Size = UDim2.new(1, -20, 1, -64),
		Visible = false,
		Parent = self.content,
	})

	btn.MouseButton1Click:Connect(function()
		closeAllPopups()
		self:SelectTab(tab)
	end)

	table.insert(self.tabs, tab)
	if #self.tabs == 1 then self:SelectTab(tab) end
	return tab
end

function Airflow:SelectTab(tab)
	for _, t in ipairs(self.tabs) do
		local on = t == tab
		t.item.BackgroundTransparency = on and 0 or 1
		t.bar.BackgroundTransparency = on and 0 or 1
		t.txt.TextColor3 = on and theme.text or theme.textDim
		if t.ic then t.ic.ImageColor3 = on and theme.text or theme.textDim end
		t.tabBar.Visible = on
		t.pagesHolder.Visible = on
	end
	self.activeTab = tab
	if tab.activePage then tab:SelectPage(tab.activePage) end
end

---------------------------------------------------------------- pages (subtabs)
local Page = {}
Page.__index = Page

function Tab:Page(name)
	local tab = self
	local btn = button(tab.tabBar)
	local tw = TextService:GetTextSize(name, 12, Enum.Font.Gotham, Vector2.new(1000, 1000)).X
	btn.Size = UDim2.new(0, tw + 22, 1, 0)

	local holder = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		Visible = false,
		Parent = tab.pagesHolder,
	})

	local txt = label(btn, name, 12, theme.textFaint, Enum.TextXAlignment.Center)
	txt.Size = UDim2.new(1, -16, 1, 0)
	txt.Position = UDim2.new(0, 8, 0, 0)

	local underline = new("Frame", {
		BackgroundColor3 = theme.accent,
		Size = UDim2.new(1, -12, 0, 2),
		Position = UDim2.new(0, 6, 1, -4),
		BackgroundTransparency = 1,
		Parent = btn,
	})

	local page = setmetatable({
		tab = tab, name = name, btn = btn, underline = underline,
		txt = txt, holder = holder, columns = {},
	}, Page)

	btn.MouseButton1Click:Connect(function()
		closeAllPopups()
		tab:SelectPage(page)
	end)

	table.insert(tab.pages, page)
	if #tab.pages == 1 then tab:SelectPage(page) end
	return page
end

function Tab:SelectPage(page)
	for _, p in ipairs(self.pages) do
		local on = p == page
		p.holder.Visible = on
		p.underline.BackgroundTransparency = on and 0 or 1
		p.txt.TextColor3 = on and theme.text or theme.textFaint
	end
	self.activePage = page
end

---------------------------------------------------------------- groups (two-column layout)
local Group = {}
Group.__index = Group

function Page:Group(name, side)
	local page = self
	local col = page.columns[side]
	if not col then
		local isLeft = side ~= "Right"
		col = new("ScrollingFrame", {
			BackgroundTransparency = 1,
			Position = UDim2.new(isLeft and 0 or 0.5, isLeft and 0 or 6, 0, 0),
			Size = UDim2.new(0.5, isLeft and -6 or -6, 1, 0),
			ScrollBarThickness = 2,
			ScrollBarImageColor3 = Color3.fromRGB(70, 70, 70),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(0, 0, 0, 0),
			Parent = page.holder,
		})
		local list = new("UIListLayout", {
			Padding = UDim.new(0, 14),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, col)
		padding(col, 2, 2, 6, 8)
		page.columns[side] = col
	end

	local g = new("Frame", { BackgroundTransparency = 1, Parent = col })
	g.AutomaticSize = Enum.AutomaticSize.Y
	g.Size = UDim2.new(1, 0, 0, 0)

	label(g, name, 12, theme.text).Size = UDim2.new(1, 0, 0, 16)

	local rows = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0, 22),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = g,
	})
	new("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, rows)

	return setmetatable({
		page = page, rows = rows, ui = page.tab.ui,
		order = 0,
	}, Group)
end

local function rowFrame(group, height)
	group.order = group.order + 1
	local row = new("Frame", {
		BackgroundColor3 = theme.row,
		Size = UDim2.new(1, 0, 0, height or 30),
		LayoutOrder = group.order,
		Parent = group.rows,
	})
	corner(row, 5)
	return row
end

---------------------------------------------------------------- shared control helpers
local function hoverRow(btn, row)
	btn.MouseEnter:Connect(function() tween(row, { BackgroundColor3 = theme.rowHover }, 0.12) end)
	btn.MouseLeave:Connect(function() tween(row, { BackgroundColor3 = theme.row }, 0.12) end)
end

local function rightBox(row, width)
	local box = new("Frame", {
		BackgroundColor3 = Color3.fromRGB(40, 40, 40),
		Size = UDim2.new(0, width or 78, 0, 18),
		Position = UDim2.new(1, -(width or 78) - 8, 0.5, -9),
		Parent = row,
	})
	corner(box, 4)
	return box
end

local function makePopup()
	local f = new("Frame", {
		BackgroundColor3 = Color3.fromRGB(26, 26, 26),
		Visible = false,
		ZIndex = 50,
		Parent = overlay,
	})
	corner(f, 5)
	stroke(f, theme.white, 0.9)
	return f
end

local function placePopup(f, row, height)
	local rp, op = row.AbsolutePosition, overlay.AbsolutePosition
	f.Position = UDim2.new(0, rp.X - op.X, 0, rp.Y - op.Y + row.AbsoluteSize.Y + 3)
	f.Size = UDim2.new(0, row.AbsoluteSize.X, 0, height)
end

local function dragRatio(inputObj, getTrack, onRatio)
	local dragging = false
	local function update(pos)
		local t = getTrack()
		if t.AbsoluteSize.X == 0 then return end
		onRatio(math.clamp((pos.X - t.AbsolutePosition.X) / t.AbsoluteSize.X, 0, 1))
	end
	inputObj.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			update(i.Position)
		end
	end)
	UserInputService.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			update(i.Position)
		end
	end)
	UserInputService.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
end

---------------------------------------------------------------- toggle
function Group:Toggle(opts)
	opts = opts or {}
	local row = rowFrame(self, 30)
	label(row, "  " .. (opts.Name or "Toggle"), 12, theme.text)

	local pill = new("Frame", {
		BackgroundColor3 = theme.track,
		Size = UDim2.new(0, 26, 0, 14),
		Position = UDim2.new(1, -34, 0.5, -7),
		Parent = row,
	})
	corner(pill, 7)
	local knob = new("Frame", {
		BackgroundColor3 = theme.textDim,
		Size = UDim2.new(0, 10, 0, 10),
		Position = UDim2.new(0, 2, 0.5, -5),
		Parent = pill,
	})
	corner(knob, 5)

	local state = { Value = false, callbacks = {} }
	function state:Set(v, silent)
		self.Value = v and true or false
		tween(pill, { BackgroundColor3 = self.Value and theme.accent or theme.track })
		tween(knob, {
			Position = UDim2.new(0, self.Value and 14 or 2, 0.5, -5),
			BackgroundColor3 = self.Value and theme.white or theme.textDim,
		})
		if not silent then
			for _, f in ipairs(self.callbacks) do f(self.Value) end
		end
	end
	function state:OnChanged(f) table.insert(self.callbacks, f) end

	local btn = button(row)
	hoverRow(btn, row)
	btn.MouseButton1Click:Connect(function() state:Set(not state.Value) end)

	if opts.Default then state:Set(opts.Default, true) end
	return state
end

---------------------------------------------------------------- slider
function Group:Slider(opts)
	opts = opts or {}
	local min, max = opts.Min or 0, opts.Max or 100
	local step = opts.Step or 1
	local suffix = opts.Suffix or ""
	local decimals = opts.Decimals or 0

	local row = rowFrame(self, 44)
	label(row, "  " .. (opts.Name or "Slider"), 12, theme.text).Size = UDim2.new(0.55, -10, 0, 16)
	local valTxt = label(row, "", 12, theme.text, Enum.TextXAlignment.Right)
	valTxt.Position = UDim2.new(0.55, 0, 0, 0)
	valTxt.Size = UDim2.new(0.45, -10, 0, 16)

	local track = new("Frame", {
		BackgroundColor3 = theme.track,
		Size = UDim2.new(1, -20, 0, 4),
		Position = UDim2.new(0, 10, 0, 26),
		Parent = row,
	})
	corner(track, 2)
	local fill = new("Frame", {
		BackgroundColor3 = theme.accent,
		Size = UDim2.new(0, 0, 1, 0),
		Parent = track,
	})
	corner(fill, 2)
	local knob = new("Frame", {
		BackgroundColor3 = theme.white,
		Size = UDim2.new(0, 10, 0, 10),
		Position = UDim2.new(0, -5, 0.5, -5),
		Parent = fill,
	})
	corner(knob, 5)

	local state = { Value = opts.Default or min, callbacks = {} }

	local function fmt(v)
		if opts.Format then return opts.Format(v) end
		return string.format("%." .. decimals .. "f%s", v, suffix)
	end
	local function render()
		local ratio = (state.Value - min) / (max - min)
		fill.Size = UDim2.new(ratio, 0, 1, 0)
		valTxt.Text = fmt(state.Value)
	end
	function state:Set(v, silent)
		v = math.clamp(v, min, max)
		v = math.floor(v / step + 0.5) * step
		v = math.clamp(v, min, max)
		self.Value = v
		render()
		if not silent then
			for _, f in ipairs(self.callbacks) do f(v) end
		end
	end
	function state:OnChanged(f) table.insert(self.callbacks, f) end

	local btn = button(row)
	hoverRow(btn, row)
	dragRatio(btn, function() return track end, function(r)
		state:Set(min + r * (max - min))
	end)

	state:Set(state.Value, true)
	return state
end

---------------------------------------------------------------- dropdown
function Group:Dropdown(opts)
	opts = opts or {}
	local multi = opts.Multi or false
	local options = opts.Options or {}

	local row = rowFrame(self, 30)
	label(row, "  " .. (opts.Name or "Dropdown"), 12, theme.text).Size = UDim2.new(0.45, -8, 1, 0)

	local box = rightBox(row, 88)
	local valTxt = label(box, "", 11, theme.text, Enum.TextXAlignment.Right)
	valTxt.Position = UDim2.new(0, 4, 0, 0)
	valTxt.Size = UDim2.new(1, -18, 1, 0)
	local chev = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 8, 0, 6),
		Position = UDim2.new(1, -12, 0.5, -3),
		Parent = box,
	})
	new("Frame", { BackgroundColor3 = theme.textDim, Size = UDim2.new(0, 5, 0, 1), Rotation = 45, Position = UDim2.new(0, 0, 0, 2), Parent = chev })
	new("Frame", { BackgroundColor3 = theme.textDim, Size = UDim2.new(0, 5, 0, 1), Rotation = -45, Position = UDim2.new(0, 4, 0, 2), Parent = chev })

	local popup = makePopup()
	local list = new("ScrollingFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -8, 1, -8),
		Position = UDim2.new(0, 4, 0, 4),
		ScrollBarThickness = 2,
		ScrollBarImageColor3 = Color3.fromRGB(70, 70, 70),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = popup,
	})
	new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, list)

	local state = {
		Value = multi and (opts.Default or {}) or (opts.Default or options[1]),
		Options = options, Multi = multi, callbacks = {},
	}

	local function valueText()
		if multi then
			if #state.Value == 0 then return "None" end
			return table.concat(state.Value, ", ")
		end
		return tostring(state.Value or "None")
	end
	local function render() valTxt.Text = valueText() end

	local function fire()
		for _, f in ipairs(state.callbacks) do f(state.Value) end
	end

	local function rebuild()
		for _, c in ipairs(list:GetChildren()) do
			if c:IsA("Frame") or c:IsA("TextButton") then c:Destroy() end
		end
		for _, opt in ipairs(state.Options) do
			local item = new("TextButton", {
				AutoButtonColor = false,
				BackgroundColor3 = Color3.fromRGB(32, 32, 32),
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 22),
				Parent = list,
			})
			corner(item, 4)
			local sel = multi and table.find(state.Value, opt) ~= nil or state.Value == opt
			local t = label(item, (multi and (sel and "✓ " or "   ") or "") .. opt, 11, sel and theme.accent or theme.textDim)
			t.Position = UDim2.new(0, 8, 0, 0)
			t.Size = UDim2.new(1, -12, 1, 0)
			item.MouseEnter:Connect(function() item.BackgroundTransparency = 0 end)
			item.MouseLeave:Connect(function() item.BackgroundTransparency = 1 end)
			item.MouseButton1Click:Connect(function()
				if multi then
					local i = table.find(state.Value, opt)
					if i then table.remove(state.Value, i) else table.insert(state.Value, opt) end
					rebuild()
					render()
					fire()
				else
					state.Value = opt
					render()
					fire()
					popup.Visible = false
				end
			end)
		end
	end

	function state:Set(v, silent)
		state.Value = v
		render()
		if not silent then fire() end
	end
	function state:OnChanged(f) table.insert(self.callbacks, f) end
	function state:Add(opt)
		table.insert(state.Options, opt)
		rebuild()
	end

	local btn = button(row)
	hoverRow(btn, row)
	btn.MouseButton1Click:Connect(function()
		if popup.Visible then
			popup.Visible = false
			return
		end
		closeAllPopups()
		rebuild()
		placePopup(popup, row, math.min(#state.Options, 6) * 24 + 8)
		popup.Visible = true
		registerPopup(popup)
	end)

	render()
	return state
end

---------------------------------------------------------------- keybind
function Group:Keybind(opts)
	opts = opts or {}
	local row = rowFrame(self, 30)
	label(row, "  " .. (opts.Name or "Keybind"), 12, theme.text)

	local box = rightBox(row, 64)
	local valTxt = label(box, "None", 11, theme.text, Enum.TextXAlignment.Center)

	local state = { Value = opts.Default, callbacks = {}, pressCallbacks = {}, listening = false }

	local function name()
		if not state.Value then return "None" end
		local n = state.Value.Name
		if n == "LeftControl" then n = "Ctrl" end
		return n
	end
	local function render() valTxt.Text = state.listening and "..." or name() end

	local ui = self.ui
	local function syncChip()
		local chipRow = state.chipRow
		if chipRow then
			if state.Value then
				chipRow.Visible = true
				chipRow.Text = "  " .. (opts.Name or "Keybind") .. "  —  " .. name()
			else
				chipRow.Visible = false
			end
			local any = false
			for _, c in ipairs(ui.keybinds:GetChildren()) do
				if c:IsA("TextLabel") and c.Visible then any = true end
			end
			ui.keybinds.Visible = any and ui.visible
		end
	end

	function state:Set(k, silent)
		state.Value = k
		render()
		syncChip()
		if not silent then
			for _, f in ipairs(state.callbacks) do f(k) end
		end
	end
	function state:OnChanged(f) table.insert(self.callbacks, f) end
	function state:OnPressed(f) table.insert(self.pressCallbacks, f) end

	-- chip row
	local chipList = ui.keybinds:FindFirstChildOfClass("UIListLayout")
	if not chipList then
		chipList = new("UIListLayout", { Padding = UDim.new(0, 1), SortOrder = Enum.SortOrder.LayoutOrder }, ui.keybinds)
		padding(ui.keybinds, 0, 3, 0, 3)
		ui.keybinds.AutomaticSize = Enum.AutomaticSize.Y
		ui.keybinds.Size = UDim2.new(0, 112, 0, 0)
	end
	state.chipRow = label(ui.keybinds, "", 10, theme.text)
	state.chipRow.Size = UDim2.new(1, 0, 0, 14)
	state.chipRow.Visible = false

	local btn = button(row)
	hoverRow(btn, row)
	btn.MouseButton1Click:Connect(function()
		state.listening = not state.listening
		render()
	end)

	UserInputService.InputBegan:Connect(function(input, gp)
		if state.listening and not gp then
			if input.UserInputType == Enum.UserInputType.MouseButton1 then return end
			if input.KeyCode == Enum.KeyCode.Escape then
				state:Set(nil)
			else
				state:Set(input.KeyCode)
			end
			state.listening = false
			render()
		elseif state.Value and input.KeyCode == state.Value and not gp then
			for _, f in ipairs(state.pressCallbacks) do f() end
		end
	end)

	render()
	syncChip()
	return state
end

---------------------------------------------------------------- color
function Group:Color(opts)
	opts = opts or {}
	local row = rowFrame(self, 30)
	label(row, "  " .. (opts.Name or "Color"), 12, theme.text)

	local sw = new("Frame", {
		Size = UDim2.new(0, 24, 0, 14),
		Position = UDim2.new(1, -32, 0.5, -7),
		Parent = row,
	})
	corner(sw, 3)
	stroke(sw, theme.white, 0.85)

	local state = {
		Value = opts.Default or theme.accent,
		Alpha = opts.DefaultAlpha or 1,
		callbacks = {},
	}
	state.H, state.S, state.V = colorUtils.rgb2hsv(state.Value.R, state.Value.G, state.Value.B)

	local function apply(silent)
		local r, g, b = colorUtils.hsv2rgb(state.H, state.S, state.V)
		state.Value = Color3.fromRGB(r * 255, g * 255, b * 255)
		sw.BackgroundColor3 = state.Value
		if not silent then
			for _, f in ipairs(state.callbacks) do f(state.Value, state.Alpha) end
		end
	end
	function state:Set(c, a, silent)
		state.H, state.S, state.V = colorUtils.rgb2hsv(c.R, c.G, c.B)
		if a then state.Alpha = a end
		apply(silent)
	end
	function state:OnChanged(f) table.insert(self.callbacks, f) end

	-- picker popup
	local popup = makePopup()
	local W = 176
	local sv = new("TextButton", {
		AutoButtonColor = false,
		Size = UDim2.new(0, W - 16, 0, 84),
		Position = UDim2.new(0, 8, 0, 8),
		Parent = popup,
	})
	corner(sv, 4)
	local hueBg = new("UIGradient", {
		Color = ColorSequence.new(Color3.new(1, 1, 1)),
	}, sv)
	local whiteGrad = new("UIGradient", {
		Color = ColorSequence.new(Color3.new(1, 1, 1)),
		Transparency = NumberSequence.new{
			NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1),
		},
	}, sv)
	local blackGrad = new("UIGradient", {
		Color = ColorSequence.new(Color3.new(0, 0, 0)),
		Transparency = NumberSequence.new{
			NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0),
		},
	}, sv)
	blackGrad.Rotation = 90
	local svKnob = new("Frame", {
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		Size = UDim2.new(0, 7, 0, 7),
		Parent = sv,
		ZIndex = 3,
	})
	corner(svKnob, 4)
	stroke(svKnob, Color3.fromRGB(0, 0, 0), 0.4, 1)

	local hueBar = new("TextButton", {
		AutoButtonColor = false,
		Size = UDim2.new(0, W - 16, 0, 8),
		Position = UDim2.new(0, 8, 0, 100),
		Parent = popup,
	})
	corner(hueBar, 4)
	local hueGrad = new("UIGradient", {
		Color = ColorSequence.new{
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
			ColorSequenceKeypoint.new(1 / 6, Color3.fromRGB(255, 255, 0)),
			ColorSequenceKeypoint.new(2 / 6, Color3.fromRGB(0, 255, 0)),
			ColorSequenceKeypoint.new(3 / 6, Color3.fromRGB(0, 255, 255)),
			ColorSequenceKeypoint.new(4 / 6, Color3.fromRGB(0, 0, 255)),
			ColorSequenceKeypoint.new(5 / 6, Color3.fromRGB(255, 0, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
		},
	}, hueBar)
	local hueKnob = new("Frame", {
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		Size = UDim2.new(0, 4, 0, 12),
		Position = UDim2.new(0, 0, 0.5, -6),
		Parent = hueBar,
	})
	corner(hueKnob, 2)

	local alphaBar = new("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		Size = UDim2.new(0, W - 16, 0, 8),
		Position = UDim2.new(0, 8, 0, 114),
		Parent = popup,
	})
	corner(alphaBar, 4)
	local alphaGrad = new("UIGradient", {
		Transparency = NumberSequence.new{
			NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0),
		},
	}, alphaBar)
	local alphaKnob = new("Frame", {
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		Size = UDim2.new(0, 4, 0, 12),
		Position = UDim2.new(0, 0, 0.5, -6),
		Parent = alphaBar,
	})
	corner(alphaKnob, 2)
	stroke(alphaKnob, Color3.fromRGB(0, 0, 0), 0.4, 1)

	local function renderKnobs()
		hueBg.Color = ColorSequence.new(colorUtils.hue2rgb(state.H))
		alphaGrad.Color = ColorSequence.new(state.Value)
		svKnob.Position = UDim2.new(state.S, -3, 1 - state.V, -3)
		hueKnob.Position = UDim2.new(state.H, -2, 0.5, -6)
		alphaKnob.Position = UDim2.new(state.Alpha, -2, 0.5, -6)
	end

	-- sv box uses 2D drag
	do
		local dragging = false
		local function upd(pos)
			local ap, asz = sv.AbsolutePosition, sv.AbsoluteSize
			state.S = math.clamp((pos.X - ap.X) / asz.X, 0, 1)
			state.V = 1 - math.clamp((pos.Y - ap.Y) / asz.Y, 0, 1)
			apply()
			renderKnobs()
		end
		sv.InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; upd(i.Position) end
		end)
		UserInputService.InputChanged:Connect(function(i)
			if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then upd(i.Position) end
		end)
		UserInputService.InputEnded:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
		end)
	end
	dragRatio(hueBar, function() return hueBar end, function(r)
		state.H = r
		apply()
		renderKnobs()
	end)
	dragRatio(alphaBar, function() return alphaBar end, function(r)
		state.Alpha = r
		renderKnobs()
		for _, f in ipairs(state.callbacks) do f(state.Value, state.Alpha) end
	end)

	popup.Size = UDim2.new(0, W, 0, 130)

	local btn = button(row)
	hoverRow(btn, row)
	btn.MouseButton1Click:Connect(function()
		if popup.Visible then
			popup.Visible = false
			return
		end
		closeAllPopups()
		local rp, op = row.AbsolutePosition, overlay.AbsolutePosition
		popup.Position = UDim2.new(0, rp.X - op.X + row.AbsoluteSize.X - W, 0, rp.Y - op.Y + row.AbsoluteSize.Y + 3)
		popup.Visible = true
		renderKnobs()
		registerPopup(popup)
	end)

	apply(true)
	renderKnobs()
	return state
end

Airflow.theme = theme
Airflow.colorUtils = colorUtils

return Airflow
