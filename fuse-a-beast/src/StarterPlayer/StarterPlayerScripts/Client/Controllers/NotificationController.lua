--!strict
--[[
	NotificationController
	Renders transient toast messages from the server's "Notify" remote. Stacks
	toasts, auto-dismisses, and colours them by kind (success/warn/offline/etc).
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Create = require(script.Parent.Parent.UI.Create)

local NotificationController = {}

local KIND_COLORS = {
	info = Color3.fromRGB(60, 90, 160),
	success = Color3.fromRGB(50, 150, 80),
	warn = Color3.fromRGB(180, 120, 40),
	achievement = Color3.fromRGB(150, 90, 220),
	offline = Color3.fromRGB(70, 110, 150),
}

local container: Frame

function NotificationController.init()
	local gui = Create("ScreenGui", {
		Name = "FaBToasts",
		ResetOnSpawn = false,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	container = Create("Frame", {
		Size = UDim2.new(0, 320, 1, -120),
		Position = UDim2.new(1, -330, 0, 60),
		BackgroundTransparency = 1,
		Parent = gui,
	}) :: Frame
	Create("UIListLayout", {
		VerticalAlignment = Enum.VerticalAlignment.Top,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = container,
	})
end

function NotificationController.show(payload)
	if not container or typeof(payload) ~= "table" then
		return
	end
	local color = KIND_COLORS[payload.kind] or KIND_COLORS.info
	local toast = Create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = color,
		BackgroundTransparency = 0.05,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		TextWrapped = true,
		TextColor3 = Color3.fromRGB(245, 248, 255),
		Text = tostring(payload.text),
		Parent = container,
	}) :: TextLabel
	Create("UICorner", { CornerRadius = UDim.new(0, 8), Parent = toast })
	Create("UIPadding", {
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		Parent = toast,
	})

	task.delay(4, function()
		if toast and toast.Parent then
			local tween = TweenService:Create(toast, TweenInfo.new(0.4), { BackgroundTransparency = 1, TextTransparency = 1 })
			tween.Completed:Connect(function()
				toast:Destroy()
			end)
			tween:Play()
		end
	end)
end

return NotificationController
