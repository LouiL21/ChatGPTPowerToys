--!strict
--[[
	ArenaStage
	The physical presentation of one Arena battle.

	The first version of combat was entirely a UI panel: your pet teleported to
	the Arena, stood perfectly still, and fought an opponent that did not exist
	anywhere in the world. A stage fixes that — two creatures face each other,
	lunge, land hits, take visible damage and one of them goes down.

	Division of responsibility: BattleService still decides EVERY outcome. This
	module is told what happened and shows it. Nothing here can change a result,
	which keeps combat server-authoritative even though it now looks like a
	fight.

	Cost: one Heartbeat connection per live battle, over exactly two models whose
	parts are already anchored. Effects are short-lived parts that delete
	themselves.
]]

local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Util.Format)

local BeastModelFactory = require(script.Parent.BeastModelFactory)
local Build = require(script.Parent.Build)

local ArenaStage = {}
ArenaStage.__index = ArenaStage

-- Fighters stand this far either side of the arena centre.
local FIGHT_GAP = 12
local LUNGE_DURATION = 0.34
local LUNGE_REACH = 6.5
local RECOIL_DURATION = 0.26
local RECOIL_REACH = 2.2

export type Visual = {
	model: Model,
	name: string,
	maxHealth: number,
	color: Color3,
	temporary: boolean, -- true = the stage owns it and destroys it on teardown
}

type Side = {
	visual: Visual,
	base: CFrame,
	phase: number,
	lungeAt: number, -- os.clock() when the last lunge began (0 = none)
	recoilAt: number,
	health: number,
	bar: Frame,
	defeated: boolean,
	fallAt: number,
	height: number,
	-- Fighters legitimately carry transparency (wings, auras, a wisp's shell), so
	-- the defeat fade has to work from each part's OWN starting value and restore
	-- it afterwards. Resetting everything to 0 would permanently flatten a pet.
	baseTransparency: { [BasePart]: number },
}

--[[
	A health bar floating over a fighter. Reading damage off a HUD panel while
	the creatures below it are motionless is what made the fight feel like a
	spreadsheet; the number belongs on the thing taking the hit.
]]
local function attachHealthBar(model: Model, name: string, color: Color3, height: number): Frame
	local root = model.PrimaryPart
	assert(root, "fighter model has no PrimaryPart")

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "HealthBar"
	billboard.Adornee = root
	billboard.Size = UDim2.fromOffset(200, 56)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, height + 3.5, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 220
	billboard.Parent = root

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 24)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.TextStrokeColor3 = Color3.fromRGB(10, 7, 19)
	label.Text = name
	label.Parent = billboard

	local track = Instance.new("Frame")
	track.Size = UDim2.new(0.9, 0, 0, 14)
	track.Position = UDim2.new(0.05, 0, 0, 28)
	track.BackgroundColor3 = Color3.fromRGB(18, 14, 32)
	track.BorderSizePixel = 0
	track.Parent = billboard
	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(1, 0)
	trackCorner.Parent = track
	local trackStroke = Instance.new("UIStroke")
	trackStroke.Thickness = 2
	trackStroke.Color = Color3.fromRGB(10, 7, 19)
	trackStroke.Parent = track

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Parent = track
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill

	return fill
end

local function makeSide(visual: Visual, base: CFrame, phase: number): Side
	local height = (visual.model:GetAttribute("Height") :: number?) or 6

	local baseTransparency: { [BasePart]: number } = {}
	for _, part in ipairs(visual.model:GetChildren()) do
		if part:IsA("BasePart") then
			baseTransparency[part] = part.Transparency
		end
	end

	return {
		visual = visual,
		base = base,
		phase = phase,
		lungeAt = 0,
		recoilAt = 0,
		health = visual.maxHealth,
		bar = attachHealthBar(visual.model, visual.name, visual.color, height),
		defeated = false,
		fallAt = 0,
		height = height,
		baseTransparency = baseTransparency,
	}
end

--[[
	centre — the point on the arena floor the fighters face across.
	a      — the challenger, placed on -X.
	b      — the opponent, placed on +X.
]]
function ArenaStage.new(centre: Vector3, a: Visual, b: Visual)
	local self = setmetatable({}, ArenaStage)

	self.centre = centre
	self.effects = Instance.new("Folder")
	self.effects.Name = "ArenaEffects"
	self.effects.Parent = workspace:FindFirstChild("FaBWorld") or workspace

	local function facing(side: number): CFrame
		local position = centre + Vector3.new(side * FIGHT_GAP, 0, 0)
		-- Look across at the opponent, level — lookAt with a Y difference would
		-- tip the whole creature forward.
		return CFrame.lookAt(position, Vector3.new(centre.X, position.Y, centre.Z))
	end

	self.a = makeSide(a, facing(-1), 0)
	self.b = makeSide(b, facing(1), math.pi)

	-- A ring on the floor marking the fight, so the Arena reads as "in use".
	self.ring = Build.part({
		size = Vector3.new(FIGHT_GAP * 2 + 16, 0.4, 20),
		position = centre + Vector3.new(0, 0.3, 0),
		color = Color3.fromRGB(196, 84, 62),
		material = Enum.Material.Neon,
		canCollide = false,
		transparency = 0.55,
		name = "BattleRing",
		parent = self.effects,
	})

	self:_place(self.a, 0)
	self:_place(self.b, 0)

	self.connection = RunService.Heartbeat:Connect(function()
		self:_step()
	end)

	return self
end

function ArenaStage:_place(side: Side, forward: number)
	local drop = 0
	local tilt = CFrame.identity
	if side.defeated then
		-- Topple: rotate onto its side and sink as it fades out.
		local t = math.clamp((os.clock() - side.fallAt) / 1.1, 0, 1)
		tilt = CFrame.Angles(0, 0, math.rad(78 * t))
		drop = -t * side.height * 0.35
	end
	BeastModelFactory.pivot(side.visual.model, side.base * CFrame.new(0, drop, -forward) * tilt)
end

function ArenaStage:_step()
	local now = os.clock()

	for _, side in ipairs({ self.a, self.b }) do
		local forward = 0

		if side.defeated then
			-- Fade from each part's own starting transparency toward invisible.
			-- Absolute rather than incremental, so the dissolve takes the same
			-- 1.1s regardless of frame rate.
			local t = math.clamp((now - side.fallAt) / 1.1, 0, 1)
			for part, original in pairs(side.baseTransparency) do
				part.Transparency = original + (1 - original) * t
			end
		else
			-- Idle: breathe on the spot, so a fighter waiting its turn is never
			-- a statue.
			forward = math.sin(now * 2.6 + side.phase) * 0.35

			if side.lungeAt > 0 then
				local t = (now - side.lungeAt) / LUNGE_DURATION
				if t >= 1 then
					side.lungeAt = 0
				else
					-- Out and back in one arc.
					forward += math.sin(t * math.pi) * LUNGE_REACH
				end
			end

			-- recoilAt is scheduled slightly in the FUTURE so the flinch lands when
			-- the attacker's lunge arrives, hence the `now >=` guard: without it a
			-- negative t would push the defender forward instead of back.
			if side.recoilAt > 0 and now >= side.recoilAt then
				local t = (now - side.recoilAt) / RECOIL_DURATION
				if t >= 1 then
					side.recoilAt = 0
				else
					forward -= math.sin(t * math.pi) * RECOIL_REACH
				end
			end
		end

		self:_place(side, forward)
	end

	-- The ring pulses so the arena itself feels live.
	if self.ring.Parent then
		self.ring.Transparency = 0.55 + math.sin(now * 4) * 0.15
	end
end

-- Floating damage number over the defender.
function ArenaStage:_damageNumber(side: Side, damage: number, crit: boolean, advantage: boolean)
	local origin = side.base.Position + Vector3.new(0, side.height + 2, 0)

	local host = Build.part({
		size = Vector3.new(0.2, 0.2, 0.2),
		position = origin,
		transparency = 1,
		canCollide = false,
		name = "DamageNumber",
		parent = self.effects,
	})
	host.CanQuery = false

	local billboard = Instance.new("BillboardGui")
	billboard.Adornee = host
	billboard.Size = UDim2.fromOffset(crit and 190 or 140, crit and 60 or 44)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 200
	billboard.Parent = host

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = crit and Color3.fromRGB(255, 208, 72)
		or (advantage and Color3.fromRGB(140, 240, 160) or Color3.fromRGB(255, 236, 236))
	label.TextStrokeTransparency = 0.15
	label.TextStrokeColor3 = Color3.fromRGB(10, 7, 19)
	label.Text = (crit and "CRIT  " or "") .. "-" .. Format.abbreviate(damage)
	label.Parent = billboard

	-- Drift up and sideways so simultaneous numbers do not overlap.
	local drift = Vector3.new(math.random(-25, 25) / 10, 0, math.random(-15, 15) / 10)
	task.spawn(function()
		local start = os.clock()
		while host.Parent and os.clock() - start < 1.1 do
			local t = (os.clock() - start) / 1.1
			host.Position = origin + drift * t + Vector3.new(0, t * 5.5, 0)
			label.TextTransparency = math.max(0, (t - 0.5) / 0.5)
			label.TextStrokeTransparency = 0.15 + label.TextTransparency * 0.85
			task.wait()
		end
		host:Destroy()
	end)
end

-- Impact burst where the blow lands.
function ArenaStage:_impact(side: Side, crit: boolean)
	local spark = Build.part({
		size = Vector3.new(1, 1, 1),
		position = side.base.Position + Vector3.new(0, side.height * 0.5, 0),
		transparency = 1,
		canCollide = false,
		name = "Impact",
		parent = self.effects,
	})
	spark.CanQuery = false

	local burst = Instance.new("ParticleEmitter")
	burst.Color = ColorSequence.new(crit and Color3.fromRGB(255, 208, 72) or Color3.fromRGB(255, 150, 130))
	burst.LightEmission = 1
	burst.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, crit and 3.2 or 2),
		NumberSequenceKeypoint.new(1, 0),
	})
	burst.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	burst.Lifetime = NumberRange.new(0.25, 0.5)
	burst.Speed = NumberRange.new(10, 22)
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.Rate = 0
	burst.Parent = spark
	burst:Emit(crit and 34 or 18)

	Debris:AddItem(spark, 1.2)
end

--[[
	Called once per exchange. `attackerIsA` says who swung; the health values are
	the server's post-hit truth for both fighters.
]]
function ArenaStage:hit(attackerIsA: boolean, damage: number, crit: boolean, advantage: boolean, aHealth: number, bHealth: number)
	local attacker = attackerIsA and self.a or self.b
	local defender = attackerIsA and self.b or self.a

	attacker.lungeAt = os.clock()
	defender.recoilAt = os.clock() + LUNGE_DURATION * 0.45 -- land the recoil on contact

	self.a.health = aHealth
	self.b.health = bHealth
	self.a.bar.Size = UDim2.fromScale(math.clamp(aHealth / math.max(1, self.a.visual.maxHealth), 0, 1), 1)
	self.b.bar.Size = UDim2.fromScale(math.clamp(bHealth / math.max(1, self.b.visual.maxHealth), 0, 1), 1)

	-- Delay the impact to the moment the lunge actually reaches the defender.
	task.delay(LUNGE_DURATION * 0.45, function()
		if not self.connection or not self.connection.Connected then
			return
		end
		self:_impact(defender, crit)
		self:_damageNumber(defender, damage, crit, advantage)
	end)
end

function ArenaStage:finish(winnerIsA: boolean)
	local loser = winnerIsA and self.b or self.a
	loser.defeated = true
	loser.fallAt = os.clock()

	local bar = loser.bar.Parent and loser.bar.Parent.Parent
	if bar then
		bar:Destroy()
	end
end

function ArenaStage:destroy()
	if self.connection then
		self.connection:Disconnect()
		self.connection = nil
	end

	for _, side in ipairs({ self.a, self.b }) do
		-- Health bars live on the fighter, and a pet outlives the battle — always
		-- strip them, whether or not the stage owns the model.
		local root = side.visual.model.PrimaryPart
		local existing = root and root:FindFirstChild("HealthBar")
		if existing then
			existing:Destroy()
		end
		if side.visual.temporary then
			side.visual.model:Destroy()
		else
			-- Undo the dissolve on a surviving pet, restoring each part's own
			-- original transparency rather than flattening it to opaque.
			for part, original in pairs(side.baseTransparency) do
				if part.Parent then
					part.Transparency = original
				end
			end
		end
	end

	self.effects:Destroy()
end

return ArenaStage
