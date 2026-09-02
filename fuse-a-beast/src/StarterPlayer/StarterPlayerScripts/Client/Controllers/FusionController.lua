--!strict
--[[
	FusionController
	Renders the fusion result popup — the game's dopamine moment. New discoveries
	get a louder, longer, colour-coded celebration (this is the "I found a Secret!"
	screenshot moment that fuels organic growth).
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Create = require(script.Parent.Parent.UI.Create)

local FusionController = {}

local RARITY_COLORS = {
	Common = Color3.fromRGB(180, 180, 180),
	Uncommon = Color3.fromRGB(90, 200, 100),
	Rare = Color3.fromRGB(70, 140, 240),
	Epic = Color3.fromRGB(170, 90, 240),
	Legendary = Color3.fromRGB(245, 180, 40),
	Mythic = Color3.fromRGB(240, 70, 120),
	Secret = Color3.fromRGB(255, 255, 255),
}

local gui: ScreenGui

function FusionController.init()
	gui = Create("ScreenGui", {
		Name = "FaBFusionResult",
		ResetOnSpawn = false,
		DisplayOrder = 5,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	}) :: ScreenGui
end

function FusionController.show(result)
	if not gui or typeof(result) ~= "table" then
		return
	end
	local color = RARITY_COLORS[result.rarity] or Color3.fromRGB(200, 200, 200)
	local card = Create("Frame", {
		Size = UDim2.new(0, 260, 0, 120),
		Position = UDim2.new(0.5, -130, 0.35, -60),
		BackgroundColor3 = Color3.fromRGB(28, 30, 40),
		BackgroundTransparency = 0.05,
		BorderSizePixel = 0,
		Parent = gui,
	}) :: Frame
	Create("UICorner", { CornerRadius = UDim.new(0, 12), Parent = card })
	Create("UIStroke", { Thickness = result.isNew and 4 or 2, Color = color, Parent = card })

	-- The banner tells the player which of the three outcomes just happened.
	local banner
	if result.isNew then
		banner = "★ NEW DISCOVERY ★"
	elseif result.kind == "variant" then
		banner = result.success and "★ VARIANT UP! ★" or "Fusion failed…"
	elseif result.kind == "hybrid" then
		banner = "Hybrid created!"
	else
		banner = "Summoned!"
	end

	Create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 24),
		Position = UDim2.new(0, 0, 0, 10),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextSize = 16,
		TextColor3 = (result.kind == "variant" and not result.success) and Color3.fromRGB(190, 120, 120) or color,
		Text = banner,
		Parent = card,
	})
	Create("TextLabel", {
		Size = UDim2.new(1, -16, 0, 30),
		Position = UDim2.new(0, 8, 0, 40),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 22,
		TextColor3 = Color3.fromRGB(240, 243, 250),
		Text = tostring(result.name),
		Parent = card,
	})
	Create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.new(0, 0, 0, 76),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		TextColor3 = color,
		Text = tostring(result.rarity),
		Parent = card,
	})

	-- pop-in
	card.Size = UDim2.new(0, 0, 0, 0)
	TweenService:Create(card, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 260, 0, 120),
	}):Play()

	local holdTime = result.isNew and 2.5 or 1.2
	task.delay(holdTime, function()
		if card and card.Parent then
			local tween = TweenService:Create(card, TweenInfo.new(0.3), {
				Position = card.Position + UDim2.fromOffset(0, -30),
				BackgroundTransparency = 1,
			})
			tween.Completed:Connect(function()
				card:Destroy()
			end)
			tween:Play()
		end
	end)
end

return FusionController
