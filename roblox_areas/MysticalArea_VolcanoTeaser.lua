-- Builds the Mystical area and a sealed Volcanic area teaser with an "ERUPTS IN" countdown.
--
-- How to use: in Roblox Studio open View > Command Bar, paste this whole file, press Enter.
-- It builds on the ground in front of your camera (look at an empty spot first), facing away
-- from you: the Mystical area first, the volcano behind it. Move the two models afterwards with
-- the Move tool if needed. Ctrl+Z undoes the build.
--
-- The eruption time is the "EruptsAt" attribute (Unix time, UTC) on the VolcanicAreaTeaser model.
-- It is set to 7 days from when you run this; change the attribute to move the date.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Selection = game:GetService("Selection")

local DAYS_UNTIL_ERUPTION = 7
local MYSTICAL_RADIUS = 110
local VOLCANO_DISTANCE = 275 -- centre of the Mystical area to centre of the volcano
local GY = 0.6 -- walkable surface sits slightly above your ground so it doesn't z-fight a baseplate

ChangeHistoryService:SetWaypoint("Before Mystical + Volcano build")

local rng = Random.new(2026)

local cam = workspace.CurrentCamera
local look = cam.CFrame.LookVector
local flat = Vector3.new(look.X, 0, look.Z)
if flat.Magnitude < 0.01 then
	flat = Vector3.new(0, 0, -1)
end
flat = flat.Unit
local aim = cam.CFrame.Position + flat * 160
local hit = workspace:Raycast(aim + Vector3.new(0, 500, 0), Vector3.new(0, -1500, 0))
local origin = Vector3.new(aim.X, hit and hit.Position.Y or 0, aim.Z)
local MYST = CFrame.lookAt(origin, origin + flat)
local VOLC = MYST * CFrame.new(0, 0, -VOLCANO_DISTANCE)

local C = {
	ground = Color3.fromRGB(110, 84, 178),
	rim = Color3.fromRGB(90, 235, 255),
	path = Color3.fromRGB(176, 164, 220),
	stone = Color3.fromRGB(62, 54, 92),
	trunk = Color3.fromRGB(74, 48, 78),
	pink = Color3.fromRGB(255, 125, 215),
	cyan = Color3.fromRGB(85, 225, 255),
	violet = Color3.fromRGB(165, 105, 255),
	gold = Color3.fromRGB(255, 220, 130),
	basalt = Color3.fromRGB(46, 40, 40),
	basaltLight = Color3.fromRGB(70, 58, 54),
	lava = Color3.fromRGB(255, 95, 20),
	flame = Color3.fromRGB(255, 130, 40),
	white = Color3.fromRGB(255, 255, 255),
	yellow = Color3.fromRGB(255, 220, 70),
}

local function part(parent, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props.Shape then
		p.Shape = props.Shape
	end
	for key, value in props do
		if key ~= "Shape" then
			p[key] = value
		end
	end
	p.Parent = parent
	return p
end

-- Vertical cylinder centred on cf (Roblox cylinders run along X, so turn it upright).
local function disc(parent, cf, diameter, height, props)
	props.Shape = Enum.PartType.Cylinder
	props.Size = Vector3.new(height, diameter, diameter)
	props.CFrame = cf * CFrame.Angles(0, 0, math.pi / 2)
	return part(parent, props)
end

local function ball(parent, cf, diameter, props)
	props.Shape = Enum.PartType.Ball
	props.Size = Vector3.new(diameter, diameter, diameter)
	props.CFrame = cf
	return part(parent, props)
end

local function light(parent, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Parent = parent
	return l
end

local function sparkles(parent, rate, c1, c2, size)
	local e = Instance.new("ParticleEmitter")
	e.Name = "Sparkles"
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Rate = rate
	e.Lifetime = NumberRange.new(2, 4)
	e.Speed = NumberRange.new(1, 3)
	e.SpreadAngle = Vector2.new(180, 180)
	e.LightEmission = 1
	e.Size = NumberSequence.new(size)
	e.Color = ColorSequence.new(c1, c2)
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Parent = parent
	return e
end

local function label(parent, name, text, color, heightScale, order, font)
	local t = Instance.new("TextLabel")
	t.Name = name
	t.LayoutOrder = order
	t.Size = UDim2.fromScale(1, heightScale)
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextScaled = true
	t.Font = font or Enum.Font.FredokaOne
	t.TextColor3 = color
	t.TextStrokeColor3 = Color3.fromRGB(25, 10, 10)
	t.TextStrokeTransparency = 0
	t.Parent = parent
	return t
end

local function surfaceGui(target, face)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = target
	return gui
end

local function teaserText(container)
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Parent = container
	label(container, "Title", "🌋 VOLCANIC AREA 🌋", C.flame, 0.34, 1)
	label(container, "Subtitle", "ERUPTS IN", C.white, 0.22, 2)
	label(container, "Countdown", ("%dd 00h 00m 00s"):format(DAYS_UNTIL_ERUPTION), C.yellow, 0.4, 3)
end

-- A crystal grows from `base`, tipped by `tilt` radians toward the direction picked by `yaw`.
local function crystal(parent, base, height, width, color, tilt, yaw)
	local cf = base
		* CFrame.Angles(0, yaw, 0)
		* CFrame.Angles(tilt, 0, 0)
		* CFrame.new(0, height / 2 - 1, 0)
		* CFrame.Angles(0, math.pi / 4, 0)
	part(parent, {
		Name = "Crystal",
		Size = Vector3.new(width, height, width),
		CFrame = cf,
		Material = Enum.Material.Glass,
		Color = color,
		Transparency = 0.25,
		Reflectance = 0.15,
	})
	part(parent, {
		Name = "CrystalCore",
		Size = Vector3.new(width * 0.45, height * 0.9, width * 0.45),
		CFrame = cf,
		Material = Enum.Material.Neon,
		Color = color,
		CanCollide = false,
	})
end

------------------------------------------------------------------------------------------------
-- Mystical area
------------------------------------------------------------------------------------------------
local mystical = Instance.new("Model")
mystical.Name = "MysticalArea"

local function M(x, y, z)
	return MYST * CFrame.new(x, y, z)
end

-- Random spot in a ring that keeps the entrance path and the far teaser sign clear.
local function randomSpot(minR, maxR)
	for _ = 1, 60 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(minR, maxR)
		local x, z = math.cos(a) * r, math.sin(a) * r
		local onPath = math.abs(x) < 14 and z > 10
		local nearSign = math.abs(x) < 26 and z < -80
		if not onPath and not nearSign then
			return x, z
		end
	end
	return MYSTICAL_RADIUS * 0.6, 0
end

local ground = disc(mystical, M(0, GY - 2, 0), MYSTICAL_RADIUS * 2, 4, {
	Name = "Ground",
	Material = Enum.Material.Grass,
	Color = C.ground,
})
disc(mystical, M(0, GY - 2.4, 0), MYSTICAL_RADIUS * 2 + 6, 4, {
	Name = "GlowRim",
	Material = Enum.Material.Neon,
	Color = C.rim,
})
mystical.PrimaryPart = ground

for z = MYSTICAL_RADIUS - 6, 26, -7 do
	part(mystical, {
		Name = "PathStone",
		Size = Vector3.new(9, 0.4, 5.5),
		CFrame = M(rng:NextNumber(-1.5, 1.5), GY + 0.2, z) * CFrame.Angles(0, rng:NextNumber(-0.15, 0.15), 0),
		Material = Enum.Material.Slate,
		Color = C.path,
	})
end

-- Entrance arch with a walk-through portal and the area name.
local AZ = MYSTICAL_RADIUS - 4
for _, x in { -12, 12 } do
	part(mystical, {
		Name = "ArchPillar",
		Size = Vector3.new(5, 26, 5),
		CFrame = M(x, GY + 13, AZ),
		Material = Enum.Material.Slate,
		Color = C.stone,
	})
end
part(mystical, {
	Name = "ArchTop",
	Size = Vector3.new(32, 4, 6),
	CFrame = M(0, GY + 28, AZ),
	Material = Enum.Material.Slate,
	Color = C.stone,
})
part(mystical, {
	Name = "Portal",
	Size = Vector3.new(19, 25.5, 0.6),
	CFrame = M(0, GY + 13, AZ),
	Material = Enum.Material.ForceField,
	Color = C.violet,
	CanCollide = false,
	CanQuery = false,
	CastShadow = false,
})
local archSign = part(mystical, {
	Name = "AreaSign",
	Size = Vector3.new(22, 6, 1),
	CFrame = M(0, GY + 33.2, AZ),
	Material = Enum.Material.Slate,
	Color = C.stone,
})
for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
	label(surfaceGui(archSign, face), "Title", "✦ MYSTICAL REALM ✦", C.gold, 1, 1, Enum.Font.Fantasy)
end
for _, x in { -14, 14 } do
	local orb = ball(mystical, M(x, GY + 32, AZ), 4, {
		Name = "ArchOrb",
		Material = Enum.Material.Neon,
		Color = C.cyan,
	})
	light(orb, C.cyan, 16, 2)
end

-- Centre: big crystal cluster with a floating orb above it.
crystal(mystical, M(0, GY, 0), 30, 7, C.violet, 0, 0)
for i = 1, 6 do
	local a = i / 6 * math.pi * 2
	crystal(
		mystical,
		M(math.cos(a) * 5, GY, math.sin(a) * 5),
		rng:NextNumber(12, 20),
		4.5,
		i % 2 == 0 and C.pink or C.cyan,
		0.35,
		math.pi / 2 - a
	)
end
local orb = ball(mystical, M(0, GY + 44, 0), 9, {
	Name = "Orb",
	Material = Enum.Material.Neon,
	Color = C.pink,
	CanCollide = false,
})
light(orb, C.pink, 40, 3)
sparkles(orb, 12, C.pink, C.cyan, 1)

-- Ring of rune stones facing the centre.
for i = 1, 8 do
	local a = (i + 0.5) / 8 * math.pi * 2
	local h = rng:NextNumber(7, 10)
	local x, z = math.cos(a) * 22, math.sin(a) * 22
	local stone = part(mystical, {
		Name = "RuneStone",
		Size = Vector3.new(3, h, 2),
		CFrame = CFrame.lookAt(M(x, GY + h / 2, z).Position, M(0, GY + h / 2, 0).Position),
		Material = Enum.Material.Slate,
		Color = C.stone,
	})
	part(mystical, {
		Name = "Rune",
		Size = Vector3.new(0.8, h * 0.6, 0.2),
		CFrame = stone.CFrame * CFrame.new(0, 0, -1.05),
		Material = Enum.Material.Neon,
		Color = C.cyan,
		CanCollide = false,
	})
end

local glowColors = { C.pink, C.cyan, C.violet }

for _ = 1, 16 do
	local x, z = randomSpot(40, MYSTICAL_RADIUS - 10)
	local h = rng:NextNumber(12, 18)
	disc(mystical, M(x, GY + h / 2, z), 2.6, h, {
		Name = "Trunk",
		Material = Enum.Material.Wood,
		Color = C.trunk,
	})
	local leaf = glowColors[rng:NextInteger(1, 3)]
	for j = 1, 3 do
		local leaves = ball(
			mystical,
			M(x + rng:NextNumber(-3, 3), GY + h + rng:NextNumber(-1, 3), z + rng:NextNumber(-3, 3)),
			rng:NextNumber(8, 12),
			{ Name = "Leaves", Material = Enum.Material.SmoothPlastic, Color = leaf }
		)
		if j == 1 then
			sparkles(leaves, 3, leaf, C.gold, 0.5)
		end
	end
end

for i = 1, 22 do
	local x, z = randomSpot(26, MYSTICAL_RADIUS - 5)
	local h = rng:NextNumber(1.5, 4)
	local capColor = i % 2 == 0 and C.cyan or C.pink
	disc(mystical, M(x, GY + h / 2, z), 1.2, h, {
		Name = "MushroomStem",
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(240, 235, 255),
	})
	local cap = disc(mystical, M(x, GY + h + 0.5, z), rng:NextNumber(3.5, 6), 1.2, {
		Name = "MushroomCap",
		Material = Enum.Material.Neon,
		Color = capColor,
	})
	if i % 3 == 0 then
		light(cap, capColor, 10, 1)
	end
end

for _ = 1, 8 do
	local x, z = randomSpot(35, MYSTICAL_RADIUS - 8)
	local color = glowColors[rng:NextInteger(1, 3)]
	for k = 1, 3 do
		local a = k / 3 * math.pi * 2
		crystal(
			mystical,
			M(x + math.cos(a) * 1.5, GY, z + math.sin(a) * 1.5),
			rng:NextNumber(5, 10),
			2.5,
			color,
			0.3,
			math.pi / 2 - a
		)
	end
end

-- Floating islands (bobbed up and down by the MysticalEffects script).
local function crystalTopper(m, cf)
	crystal(m, cf, 12, 4, C.cyan, 0, 0)
	crystal(m, cf * CFrame.new(3, 0, 1), 7, 3, C.pink, 0.35, math.pi / 2)
	crystal(m, cf * CFrame.new(-3, 0, -1), 8, 3, C.violet, 0.35, -math.pi / 2)
end

local function treeTopper(m, cf)
	disc(m, cf * CFrame.new(0, 6, 0), 2.4, 12, { Name = "Trunk", Material = Enum.Material.Wood, Color = C.trunk })
	ball(m, cf * CFrame.new(0, 13, 0), 11, { Name = "Leaves", Material = Enum.Material.SmoothPlastic, Color = C.pink })
	ball(m, cf * CFrame.new(3, 11, 2), 8, { Name = "Leaves", Material = Enum.Material.SmoothPlastic, Color = C.violet })
end

for i = 1, 4 do
	local a = (i - 0.5) / 4 * math.pi * 2
	local top = M(math.cos(a) * 72, GY + 30 + i * 4, math.sin(a) * 72)
	local island = Instance.new("Model")
	island.Name = "FloatingIsland"
	disc(island, top * CFrame.new(0, -1.5, 0), 26, 3, { Name = "IslandTop", Material = Enum.Material.Grass, Color = C.ground })
	disc(island, top * CFrame.new(0, -5, 0), 22, 4, { Name = "IslandRock", Material = Enum.Material.Slate, Color = C.stone })
	disc(island, top * CFrame.new(0, -9, 0), 15, 4, { Name = "IslandRock", Material = Enum.Material.Slate, Color = C.stone })
	disc(island, top * CFrame.new(0, -13, 0), 8, 4, { Name = "IslandRock", Material = Enum.Material.Slate, Color = C.stone })
	if i % 2 == 0 then
		crystalTopper(island, top)
	else
		treeTopper(island, top)
	end
	island.Parent = mystical
end

local air = part(mystical, {
	Name = "AmbientSparkles",
	Size = Vector3.new(190, 1, 190),
	CFrame = M(0, GY + 18, 0),
	Transparency = 1,
	CanCollide = false,
	CanQuery = false,
	CanTouch = false,
	CastShadow = false,
})
sparkles(air, 30, C.cyan, C.pink, 0.7)

local mysticalEffects = Instance.new("Script")
mysticalEffects.Name = "MysticalEffects"
mysticalEffects.Source = [==[
local TweenService = game:GetService("TweenService")
local area = script.Parent

for _, island in area:GetChildren() do
	if island:IsA("Model") and island.Name == "FloatingIsland" then
		local info = TweenInfo.new(2.5 + math.random() * 1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
		for _, p in island:GetDescendants() do
			if p:IsA("BasePart") then
				TweenService:Create(p, info, { CFrame = p.CFrame + Vector3.new(0, 3, 0) }):Play()
			end
		end
	end
end

local orb = area:FindFirstChild("Orb")
if orb then
	local info = TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	TweenService:Create(orb, info, { CFrame = orb.CFrame + Vector3.new(0, 4, 0) }):Play()
end
]==]
mysticalEffects.Parent = mystical

------------------------------------------------------------------------------------------------
-- Volcanic area teaser
------------------------------------------------------------------------------------------------
local volcano = Instance.new("Model")
volcano.Name = "VolcanicAreaTeaser"

local function V(x, y, z)
	return VOLC * CFrame.new(x, y, z)
end

local volcanoGround = disc(volcano, V(0, GY - 2, 0), 190, 4, {
	Name = "Ground",
	Material = Enum.Material.Basalt,
	Color = C.basalt,
})
volcano.PrimaryPart = volcanoGround

for _ = 1, 26 do
	local a = rng:NextNumber(0, math.pi * 2)
	local r = rng:NextNumber(64, 84)
	part(volcano, {
		Name = "LavaCrack",
		Size = Vector3.new(1.4, 0.3, rng:NextNumber(8, 18)),
		CFrame = V(math.cos(a) * r, GY + 0.1, math.sin(a) * r) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
		Material = Enum.Material.Neon,
		Color = C.lava,
	})
end

-- Stepped cone.
local LAYERS, LAYER_H, R_BOTTOM, R_TOP = 10, 8, 62, 16
local radii = {}
for i = 1, LAYERS do
	radii[i] = R_BOTTOM + (R_TOP - R_BOTTOM) * (i - 1) / (LAYERS - 1)
	disc(volcano, V(0, GY + LAYER_H * (i - 0.5), 0), radii[i] * 2, LAYER_H, {
		Name = "VolcanoRock",
		Material = Enum.Material.Basalt,
		Color = i % 2 == 0 and C.basalt or C.basaltLight,
	})
end
local peakY = GY + LAYERS * LAYER_H
local crater = disc(volcano, V(0, peakY - 0.3, 0), R_TOP * 2 - 6, 1, {
	Name = "CraterLava",
	Material = Enum.Material.Neon,
	Color = C.lava,
})

-- Lava running down four sides of the cone, step by step.
local function lava(name, size, cf)
	part(volcano, { Name = name, Size = size, CFrame = cf, Material = Enum.Material.Neon, Color = C.lava })
end
for _, deg in { 20, 110, 200, 290 } do
	local spin = VOLC * CFrame.Angles(0, math.rad(deg), 0)
	lava("LavaFlow", Vector3.new(4, 0.4, 5), spin * CFrame.new(0, peakY + 0.2, -(R_TOP - 2.5)))
	for i = 1, LAYERS do
		local outer = radii[i]
		lava("LavaFall", Vector3.new(4, LAYER_H, 0.6), spin * CFrame.new(0, GY + LAYER_H * (i - 0.5), -(outer + 0.2)))
		if i < LAYERS then
			local inner = radii[i + 1] - 1
			lava("LavaFlow", Vector3.new(4, 0.4, outer - inner), spin * CFrame.new(0, GY + LAYER_H * i + 0.2, -(outer + inner) / 2))
		end
	end
	lava("LavaPool", Vector3.new(9, 0.3, 10), spin * CFrame.new(0, GY + 0.15, -(R_BOTTOM + 5)))
end

light(crater, C.lava, 60, 4)
local fire = Instance.new("Fire")
fire.Size = 25
fire.Heat = 20
fire.Color = C.flame
fire.SecondaryColor = Color3.fromRGB(255, 50, 0)
fire.Parent = crater
local smoke = Instance.new("Smoke")
smoke.Color = Color3.fromRGB(45, 38, 38)
smoke.Opacity = 0.25
smoke.RiseVelocity = 12
smoke.Size = 30
smoke.Parent = crater
local embers = Instance.new("ParticleEmitter")
embers.Name = "Embers"
embers.Texture = "rbxasset://textures/particles/fire_main.dds"
embers.Rate = 15
embers.Lifetime = NumberRange.new(2, 3.5)
embers.Speed = NumberRange.new(35, 60)
embers.SpreadAngle = Vector2.new(25, 25)
embers.Acceleration = Vector3.new(0, -35, 0)
embers.Size = NumberSequence.new(2)
embers.LightEmission = 1
embers.Color = ColorSequence.new(Color3.fromRGB(255, 200, 60), Color3.fromRGB(255, 60, 0))
embers.EmissionDirection = Enum.NormalId.Right -- the crater cylinder is turned upright, so its +X points up
embers.Parent = crater

for _ = 1, 18 do
	local a = rng:NextNumber(0, math.pi * 2)
	local r = rng:NextNumber(66, 88)
	local s = rng:NextNumber(4, 9)
	part(volcano, {
		Name = "Boulder",
		Size = Vector3.new(s, s * 0.8, s * 1.1),
		CFrame = V(math.cos(a) * r, GY + s * 0.3, math.sin(a) * r)
			* CFrame.Angles(rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28)),
		Material = Enum.Material.Basalt,
		Color = C.basaltLight,
	})
end

-- Sealed until it opens: players can see the volcano but not walk in.
ball(volcano, V(0, GY, 0), 250, {
	Name = "SealedBarrier",
	Material = Enum.Material.ForceField,
	Color = C.flame,
	Transparency = 0.3,
	CastShadow = false,
})

-- Big countdown floating above the volcano, visible from far away.
local anchor = part(volcano, {
	Name = "TeaserBillboardAnchor",
	Size = Vector3.new(1, 1, 1),
	CFrame = V(0, peakY + 65, 0),
	Transparency = 1,
	CanCollide = false,
	CanQuery = false,
	CanTouch = false,
})
local billboard = Instance.new("BillboardGui")
billboard.Size = UDim2.fromScale(80, 32) -- in studs
billboard.LightInfluence = 0
billboard.MaxDistance = 1500
billboard.Parent = anchor
teaserText(billboard)

-- Countdown sign at the far edge of the Mystical area, facing back into it.
local SZ = -(MYSTICAL_RADIUS - 14)
local signCF = MYST * CFrame.new(0, GY + 15, SZ)
local board = part(volcano, {
	Name = "TeaserSign",
	Size = Vector3.new(30, 14, 1.5),
	CFrame = signCF,
	Material = Enum.Material.Basalt,
	Color = C.basalt,
})
part(volcano, {
	Name = "TeaserSignGlow",
	Size = Vector3.new(31, 15, 1.2),
	CFrame = signCF * CFrame.new(0, 0, -0.4),
	Material = Enum.Material.Neon,
	Color = C.lava,
})
for _, x in { -16.5, 16.5 } do
	part(volcano, {
		Name = "TeaserPost",
		Size = Vector3.new(3, 23, 3),
		CFrame = MYST * CFrame.new(x, GY + 11.5, SZ),
		Material = Enum.Material.Basalt,
		Color = C.basaltLight,
	})
	local torch = ball(volcano, MYST * CFrame.new(x, GY + 24.5, SZ), 3, {
		Name = "LavaOrb",
		Material = Enum.Material.Neon,
		Color = C.lava,
	})
	light(torch, C.lava, 18, 2)
end
teaserText(surfaceGui(board, Enum.NormalId.Back))

local eruptsAt = os.time() + DAYS_UNTIL_ERUPTION * 86400
volcano:SetAttribute("EruptsAt", eruptsAt)
volcano:SetAttribute(
	"EruptsAtUTC",
	DateTime.fromUnixTimestamp(eruptsAt):FormatUniversalTime("YYYY-MM-DD HH:mm", "en-us") .. " UTC"
)

local volcanoEffects = Instance.new("Script")
volcanoEffects.Name = "EruptionCountdown"
volcanoEffects.Source = [==[
local TweenService = game:GetService("TweenService")
local model = script.Parent

local labels = {}
for _, d in model:GetDescendants() do
	if d:IsA("TextLabel") and d.Name == "Countdown" then
		table.insert(labels, d)
	end
end

local function format(left)
	if left <= 0 then
		return "ERUPTING NOW!"
	end
	local days = left // 86400
	local hours = left % 86400 // 3600
	local minutes = left % 3600 // 60
	local seconds = left % 60
	return string.format("%dd %02dh %02dm %02ds", days, hours, minutes, seconds)
end

-- Every so often the volcano rumbles: a burst of lava bombs and a flash of light.
local crater = model:FindFirstChild("CraterLava")
local embers = crater and crater:FindFirstChild("Embers")
local glow = crater and crater:FindFirstChildOfClass("PointLight")
if embers then
	task.spawn(function()
		while true do
			task.wait(math.random(12, 25))
			embers:Emit(60)
			if glow then
				glow.Brightness = 12
				TweenService:Create(glow, TweenInfo.new(2), { Brightness = 4 }):Play()
			end
		end
	end)
end

while true do
	local text = format((model:GetAttribute("EruptsAt") or 0) - os.time())
	for _, label in labels do
		label.Text = text
	end
	task.wait(1)
end
]==]
volcanoEffects.Parent = volcano

mystical.Parent = workspace
volcano.Parent = workspace
Selection:Set({ mystical, volcano })
ChangeHistoryService:SetWaypoint("Built Mystical area + Volcano teaser")
print(
	("Built MysticalArea and VolcanicAreaTeaser. The volcano erupts %s (%d days from now)."):format(
		volcano:GetAttribute("EruptsAtUTC"),
		DAYS_UNTIL_ERUPTION
	)
)
