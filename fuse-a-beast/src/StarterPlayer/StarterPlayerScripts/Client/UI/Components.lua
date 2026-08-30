--!strict
--[[
	Components
	Reusable UI pieces built on Theme. Every panel in the game is assembled from
	these, so the interface stays visually consistent and a restyle is one file.

	The "chunky" recipe used throughout: rounded corner + thick dark stroke + a
	hard offset shadow behind. It's what makes a flat frame read as a pressable
	game object rather than a div.
]]

local TweenService = game:GetService("TweenService")

local Create = require(script.Parent.Create)
local Theme = require(script.Parent.Theme)

local Components = {}

function Components.corner(radius: number, parent: Instance)
	Create("UICorner", { CornerRadius = UDim.new(0, radius), Parent = parent })
end

function Components.stroke(parent: Instance, thickness: number?, color: Color3?)
	Create("UIStroke", {
		Thickness = thickness or Theme.strokeWidth,
		Color = color or Theme.stroke,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

function Components.padding(px: number, parent: Instance)
	Create("UIPadding", {
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		Parent = parent,
	})
end

function Components.gradient(parent: Instance, top: Color3, bottom: Color3)
	Create("UIGradient", {
		Color = ColorSequence.new(top, bottom),
		Rotation = 90,
		Parent = parent,
	})
end

--[[
	A raised surface. `shadow` draws the hard offset block behind it, which is
	what gives everything its tactile depth.
]]
function Components.surface(props: { [string]: any }, shadow: boolean?): Frame
	local frame = Create("Frame", props) :: Frame
	Components.corner(Theme.radius, frame)
	Components.stroke(frame)

	if shadow ~= false then
		local behind = Create("Frame", {
			Name = "Shadow",
			Size = frame.Size,
			Position = frame.Position + UDim2.fromOffset(0, Theme.shadowOffset),
			AnchorPoint = frame.AnchorPoint,
			BackgroundColor3 = Theme.stroke,
			BorderSizePixel = 0,
			ZIndex = frame.ZIndex - 1,
			Parent = frame.Parent,
		})
		Components.corner(Theme.radius, behind)
	end
	return frame
end

-- Chunky button with press feedback.
function Components.button(text: string, color: Color3, props: { [string]: any }?): TextButton
	local merged: { [string]: any } = {
		Text = text,
		Font = Theme.fontDisplay,
		TextSize = 18,
		TextColor3 = Theme.text,
		BackgroundColor3 = color,
		AutoButtonColor = false,
		BorderSizePixel = 0,
	}
	if props then
		for key, value in pairs(props) do
			merged[key] = value
		end
	end

	local btn = Create("TextButton", merged) :: TextButton
	Components.corner(Theme.radiusSmall, btn)
	Components.stroke(btn)
	Components.gradient(btn, color:Lerp(Color3.new(1, 1, 1), 0.18), color:Lerp(Color3.new(0, 0, 0), 0.18))

	-- Press = sink into its own shadow. Cheap, and it feels great.
	local basePosition = btn.Position
	btn.MouseButton1Down:Connect(function()
		btn.Position = basePosition + UDim2.fromOffset(0, 3)
	end)
	local function release()
		btn.Position = basePosition
	end
	btn.MouseButton1Up:Connect(release)
	btn.MouseLeave:Connect(release)

	return btn
end

-- Small rounded tag, e.g. a rarity chip or an element pill.
function Components.pill(text: string, color: Color3, props: { [string]: any }?): TextLabel
	local merged: { [string]: any } = {
		Text = text,
		Font = Theme.fontBold,
		TextSize = 12,
		TextColor3 = Theme.text,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(76, 22),
	}
	if props then
		for key, value in pairs(props) do
			merged[key] = value
		end
	end
	local label = Create("TextLabel", merged) :: TextLabel
	Components.corner(999, label)
	Components.stroke(label, 2)
	return label
end

function Components.label(text: string, props: { [string]: any }?): TextLabel
	local merged: { [string]: any } = {
		Text = text,
		Font = Theme.fontBody,
		TextSize = 14,
		TextColor3 = Theme.text,
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
	}
	if props then
		for key, value in pairs(props) do
			merged[key] = value
		end
	end
	return Create("TextLabel", merged) :: TextLabel
end

--[[
	Standard modal shell: dark surface, title bar, close button and a scrolling
	body. Returns the frame plus the body to fill.
]]
function Components.panel(gui: Instance, title: string, size: UDim2): (Frame, ScrollingFrame)
	local frame = Create("Frame", {
		Name = title .. "Panel",
		Size = size,
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.bg,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 10,
		Parent = gui,
	}) :: Frame
	Components.corner(Theme.radius, frame)
	Components.stroke(frame)

	local header = Create("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 46),
		BackgroundColor3 = Theme.panel,
		BorderSizePixel = 0,
		ZIndex = 11,
		Parent = frame,
	})
	Components.corner(Theme.radius, header)

	Components.label(title, {
		Size = UDim2.new(1, -60, 1, 0),
		Position = UDim2.fromOffset(18, 0),
		Font = Theme.fontDisplay,
		TextSize = 22,
		ZIndex = 12,
		Parent = header,
	})

	local close = Components.button("X", Theme.red, {
		Size = UDim2.fromOffset(34, 30),
		Position = UDim2.new(1, -44, 0, 8),
		TextSize = 16,
		ZIndex = 12,
		Parent = header,
	})
	close.MouseButton1Click:Connect(function()
		frame.Visible = false
	end)

	local body = Create("ScrollingFrame", {
		Name = "Body",
		Size = UDim2.new(1, -20, 1, -60),
		Position = UDim2.fromOffset(10, 54),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.accentLight,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ZIndex = 11,
		Parent = frame,
	}) :: ScrollingFrame
	Create("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = body,
	})

	return frame, body
end

function Components.clear(container: Instance)
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

function Components.tweenIn(frame: GuiObject)
	local target = frame.Size
	frame.Size = UDim2.new(target.X.Scale * 0.85, target.X.Offset * 0.85, target.Y.Scale * 0.85, target.Y.Offset * 0.85)
	TweenService:Create(frame, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = target,
	}):Play()
end

return Components
