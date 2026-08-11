-- Example menu in the Airflow style (see screenshots).
-- Load the library first: local Airflow = loadstring(...)() or dofile("airflow.lua")

local Airflow = dofile("airflow.lua") -- replace with loadstring in your executor

local ui = Airflow:CreateWindow({
	Title = "Airflow",
	Size = UDim2.new(0, 600, 0, 400),
	ToggleKey = Enum.KeyCode.Insert,
})

---------------------------------------------------------------- Ragebot
local rage = ui:Tab("Ragebot")
do
	local aim = rage:Page("Aimbot")
	local g = aim:Group("General", "Left")
	g:Toggle({ Name = "Enable" })
	g:Dropdown({ Name = "Target hitbox", Options = { "Head", "Neck", "Chest", "Pelvis" }, Default = "Head" })
	g:Slider({ Name = "Hitchance", Min = 0, Max = 100, Default = 76, Suffix = "%" })
	g:Keybind({ Name = "Target key" })

	local h = aim:Group("Anti-aim safe", "Right")
	h:Toggle({ Name = "Auto scope" })
	h:Toggle({ Name = "Auto stop" })
	h:Slider({ Name = "Min damage", Min = 0, Max = 130, Default = 20 })
end

---------------------------------------------------------------- Legitbot
local legit = ui:Tab("Legitbot")
do
	local aim = legit:Page("Aimbot")
	local g = aim:Group("General", "Left")
	g:Toggle({ Name = "Enable" })
	g:Slider({ Name = "FOV", Min = 0, Max = 30, Default = 4, Suffix = "°" })
	g:Slider({ Name = "Smooth", Min = 0, Max = 100, Default = 60, Suffix = "%" })
	g:Toggle({ Name = "Visible check" })
end

---------------------------------------------------------------- Antiaims
local aa = ui:Tab("Antiaims")
do
	local p = aa:Page("Pitch")
	local g = p:Group("Angles", "Left")
	g:Dropdown({ Name = "Pitch", Options = { "None", "Down", "Up", "Zero", "Custom" }, Default = "Down" })
	g:Dropdown({ Name = "Yaw", Options = { "None", "Backwards", "Jitter", "Spin" }, Default = "Backwards" })
	g:Slider({ Name = "Jitter range", Min = 0, Max = 180, Default = 45, Suffix = "°" })
end

---------------------------------------------------------------- Visuals (as on screenshot 2)
local visuals = ui:Tab("Visuals")
do
	local enemy = visuals:Page("Enemy")

	local gen = enemy:Group("General", "Left")
	gen:Toggle({ Name = "Enable", Default = true })
	gen:Dropdown({
		Name = "Elements", Multi = true,
		Options = { "Box", "Name", "Health", "Weapon", "Ammo" },
		Default = { "Box", "Name", "Health" },
	})
	gen:Color({ Name = "Box color", Default = Color3.fromRGB(46, 204, 155) })
	gen:Color({ Name = "Name color", Default = Color3.fromRGB(255, 255, 255) })
	gen:Color({ Name = "Health color", Default = Color3.fromRGB(146, 227, 122) })
	gen:Color({ Name = "Weapon color", Default = Color3.fromRGB(255, 255, 255) })
	gen:Color({ Name = "Ammo color", Default = Color3.fromRGB(74, 144, 226) })

	local chams = enemy:Group("Chams", "Right")
	chams:Dropdown({ Name = "Type", Options = { "Visible", "Hidden", "Both" }, Default = "Visible" })
	chams:Toggle({ Name = "Enable", Default = true })
	chams:Dropdown({ Name = "Material", Options = { "Textured", "Flat", "Glow" }, Default = "Textured" })
	chams:Color({ Name = "Material color", Default = Color3.fromRGB(154, 205, 50) })

	local oof = enemy:Group("Player OOF", "Right")
	oof:Slider({ Name = "Distance", Min = 0, Max = 500, Default = 250, Suffix = " ft" })
	oof:Slider({ Name = "Size", Min = 4, Max = 40, Default = 16, Suffix = " px" })

	local local_ = visuals:Page("Local")
	local lg = local_:Group("General", "Left")
	lg:Toggle({ Name = "Fullbright" })
	lg:Slider({ Name = "FOV override", Min = 60, Max = 120, Default = 90 })
	lg:Color({ Name = "World modulation" })
end

---------------------------------------------------------------- Miscellaneous (as on screenshot 1)
local misc = ui:Tab("Miscellaneous")
do
	local movement = misc:Page("Movement")

	local main = movement:Group("Main", "Left")
	main:Toggle({ Name = "Auto jump" })
	main:Toggle({ Name = "Auto strafe" })
	main:Slider({ Name = "Turn smooth", Min = 0, Max = 100, Default = 70, Suffix = "%" })
	main:Keybind({ Name = "Edge jump" })
	main:Toggle({ Name = "Fast stop" })
	main:Toggle({ Name = "Slide walk" })

	local helpers = movement:Group("Helpers", "Right")
	helpers:Keybind({ Name = "Auto peek" })
	helpers:Color({ Name = "Start color" })
	helpers:Color({ Name = "Move color" })
	helpers:Toggle({ Name = "Return on key release" })

	local events = misc:Page("Events")
	local eg = events:Group("General", "Left")
	eg:Toggle({ Name = "Auto accept" })
	eg:Toggle({ Name = "Clan tag" })
end

---------------------------------------------------------------- Skinchanger / Configs / Scripts
local skin = ui:Tab("Skinchanger")
do
	local p = skin:Page("Knives")
	local g = p:Group("General", "Left")
	g:Toggle({ Name = "Enable" })
	g:Dropdown({ Name = "Knife model", Options = { "Karambit", "M9 Bayonet", "Butterfly", "Skeleton" }, Default = "Karambit" })
	g:Color({ Name = "Skin color" })
end

local configs = ui:Tab("Configs")
do
	local p = configs:Page("Manage")
	local g = p:Group("Configs", "Left")
	g:Dropdown({ Name = "Selected", Options = { "legit.cfg", "rage.cfg", "hvH.cfg" }, Default = "legit.cfg" })
	g:Keybind({ Name = "Double tap" })
end

local scripts = ui:Tab("Scripts")
do
	local p = scripts:Page("Lua")
	local g = p:Group("Executor", "Left")
	g:Toggle({ Name = "Auto exec" })
	g:Slider({ Name = "Timeout", Min = 1, Max = 30, Default = 10, Suffix = "s" })
end

-- demo callbacks
ui:Notify("Airflow loaded")
