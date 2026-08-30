--!strict
--[[
	BattleController
	Renders the Arena fight the server is streaming: two health bars, a running
	log of hits, and the result.

	The server has already decided every outcome — this is presentation only, so
	nothing here can influence a battle.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Create = require(script.Parent.Parent.UI.Create)
local Theme = require(script.Parent.Parent.UI.Theme)
local UI = require(script.Parent.Parent.UI.Components)

local BattleController = {}

local gui: ScreenGui
local frame: Frame?
local refs: { [string]: any } = {}

function BattleController.init()
	gui = Create("ScreenGui", {
		Name = "FaBBattle",
		ResetOnSpawn = false,
		DisplayOrder = 6,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	}) :: ScreenGui
end

local function healthBar(parent: Instance, position: UDim2, color: Color3)
	local holder = Create("Frame", {
		Size = UDim2.fromOffset(190, 18),
		Position = position,
		BackgroundColor3 = Color3.fromRGB(22, 18, 40),
		BorderSizePixel = 0,
		Parent = parent,
	})
	UI.corner(999, holder)
	UI.stroke(holder, 2)
	local fill = Create("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = holder,
	})
	UI.corner(999, fill)
	return fill
end

function BattleController._open(payload)
	BattleController._close()

	local panel = Create("Frame", {
		Size = UDim2.fromOffset(440, 190),
		Position = UDim2.new(0.5, -220, 0, 76),
		BackgroundColor3 = Theme.bg,
		BorderSizePixel = 0,
		Parent = gui,
	}) :: Frame
	UI.corner(Theme.radius, panel)
	UI.stroke(panel)
	frame = panel

	UI.label(payload.a.name, {
		Size = UDim2.fromOffset(190, 20),
		Position = UDim2.fromOffset(16, 12),
		Font = Theme.fontDisplay,
		TextSize = 15,
		TextColor3 = Theme.rarity[payload.a.rarity] or Theme.text,
		Parent = panel,
	})
	UI.label(payload.b.name, {
		Size = UDim2.fromOffset(190, 20),
		Position = UDim2.fromOffset(234, 12),
		Font = Theme.fontDisplay,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Theme.rarity[payload.b.rarity] or Theme.text,
		Parent = panel,
	})

	refs.aFill = healthBar(panel, UDim2.fromOffset(16, 36), Theme.green)
	refs.bFill = healthBar(panel, UDim2.fromOffset(234, 36), Theme.red)
	refs.aMax = payload.a.maxHealth
	refs.bMax = payload.b.maxHealth

	refs.log = UI.label("", {
		Size = UDim2.new(1, -32, 0, 96),
		Position = UDim2.fromOffset(16, 66),
		TextSize = 13,
		TextColor3 = Theme.textMuted,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		Parent = panel,
	})
	refs.lines = {}

	UI.tweenIn(panel)
end

function BattleController._hit(payload)
	if not frame then
		return
	end
	local function setBar(fill: Frame, current: number, max: number)
		TweenService:Create(fill, TweenInfo.new(0.25), {
			Size = UDim2.fromScale(math.clamp(current / math.max(1, max), 0, 1), 1),
		}):Play()
	end
	setBar(refs.aFill, payload.aHealth, refs.aMax)
	setBar(refs.bFill, payload.bHealth, refs.bMax)

	local suffix = ""
	if payload.crit then
		suffix ..= "  CRIT!"
	end
	if payload.advantage then
		suffix ..= "  super effective!"
	end
	table.insert(refs.lines, string.format("%s hits for %d%s", payload.attacker, payload.damage, suffix))
	-- Keep only the most recent lines so the panel never overflows.
	while #refs.lines > 5 do
		table.remove(refs.lines, 1)
	end
	refs.log.Text = table.concat(refs.lines, "\n")
end

function BattleController._end(payload)
	if not frame then
		return
	end
	refs.log.Text = string.format("%s wins!%s", payload.winner, payload.byTimeout and " (by stamina)" or "")
	refs.log.TextColor3 = Theme.goldLight
	task.delay(3, BattleController._close)
end

function BattleController._close()
	if frame then
		frame:Destroy()
		frame = nil
	end
	refs.lines = {}
end

function BattleController.handle(payload)
	if typeof(payload) ~= "table" then
		return
	end
	if payload.phase == "start" then
		BattleController._open(payload)
	elseif payload.phase == "hit" then
		BattleController._hit(payload)
	elseif payload.phase == "end" then
		BattleController._end(payload)
	end
end

-- Incoming duel request: a small accept/decline prompt.
function BattleController.showChallenge(payload, respond: (boolean) -> ())
	local card = Create("Frame", {
		Size = UDim2.fromOffset(320, 110),
		Position = UDim2.new(0.5, -160, 0.5, -55),
		BackgroundColor3 = Theme.bg,
		BorderSizePixel = 0,
		Parent = gui,
	}) :: Frame
	UI.corner(Theme.radius, card)
	UI.stroke(card)

	UI.label(tostring(payload.fromName) .. " challenges you!", {
		Size = UDim2.new(1, -24, 0, 40),
		Position = UDim2.fromOffset(12, 10),
		Font = Theme.fontDisplay,
		TextSize = 16,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = card,
	})

	local accept = UI.button("Fight", Theme.green, {
		Size = UDim2.fromOffset(130, 38),
		Position = UDim2.fromOffset(20, 58),
		Parent = card,
	})
	local decline = UI.button("Decline", Theme.panelLight, {
		Size = UDim2.fromOffset(130, 38),
		Position = UDim2.fromOffset(170, 58),
		Parent = card,
	})
	accept.MouseButton1Click:Connect(function()
		respond(true)
		card:Destroy()
	end)
	decline.MouseButton1Click:Connect(function()
		respond(false)
		card:Destroy()
	end)

	-- Auto-decline if ignored, matching the server's 30s challenge expiry.
	task.delay(28, function()
		if card.Parent then
			card:Destroy()
		end
	end)
end

return BattleController
