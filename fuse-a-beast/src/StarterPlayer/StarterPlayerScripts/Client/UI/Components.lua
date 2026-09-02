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

--[[
	Adds the raised-key treatment shared by every pressable control: a heavy dark
	outline, a light rim catching the top edge, a vertical gradient and a hard
	shadow underneath.

	The rim is the piece that does the work. A flat fill with an outline still
	reads as a label on a dark background; a highlight along the top edge is what
	makes the eye see a physical key standing off the surface.
]]
local function raise(btn: GuiObject, color: Color3)
	Components.corner(Theme.radiusSmall, btn)
	Components.stroke(btn, Theme.buttonStroke)
	Components.gradient(btn, color:Lerp(Color3.new(1, 1, 1), 0.26), color:Lerp(Color3.new(0, 0, 0), 0.24))

	local rim = Create("Frame", {
		Name = "Rim",
		Size = UDim2.new(1, -14, 0, 3),
		Position = UDim2.fromOffset(7, 4),
		BackgroundColor3 = Theme.rim,
		BackgroundTransparency = 0.62,
		BorderSizePixel = 0,
		ZIndex = btn.ZIndex + 1,
		Parent = btn,
	})
	Components.corner(999, rim)

	local shadow = Create("Frame", {
		Name = "Lift",
		Size = btn.Size,
		Position = btn.Position + UDim2.fromOffset(0, Theme.shadowOffset),
		AnchorPoint = btn.AnchorPoint,
		BackgroundColor3 = Theme.stroke,
		BorderSizePixel = 0,
		ZIndex = btn.ZIndex - 1,
		Parent = btn.Parent,
	})
	Components.corner(Theme.radiusSmall, shadow)
	return shadow
end

-- Press = sink into its own shadow. Cheap, and it feels great.
local function pressable(btn: TextButton, shadow: Frame?)
	local basePosition = btn.Position
	btn.MouseButton1Down:Connect(function()
		btn.Position = basePosition + UDim2.fromOffset(0, Theme.pressDepth)
	end)
	local function release()
		btn.Position = basePosition
	end
	btn.MouseButton1Up:Connect(release)
	btn.MouseLeave:Connect(release)
	return shadow
end

-- Chunky button with press feedback.
function Components.button(text: string, color: Color3, props: { [string]: any }?): TextButton
	local merged: { [string]: any } = {
		Text = text,
		Font = Theme.fontDisplay,
		TextSize = 19,
		TextColor3 = Theme.text,
		TextStrokeTransparency = 0.55,
		TextStrokeColor3 = Theme.stroke,
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
	-- Inside a UIListLayout the shadow would become a layout item of its own, so
	-- only draw it for absolutely-positioned buttons.
	local layoutParent = btn.Parent and (btn.Parent:FindFirstChildOfClass("UIListLayout")
		or btn.Parent:FindFirstChildOfClass("UIGridLayout"))
	if layoutParent then
		Components.corner(Theme.radiusSmall, btn)
		Components.stroke(btn, Theme.buttonStroke)
		Components.gradient(btn, color:Lerp(Color3.new(1, 1, 1), 0.26), color:Lerp(Color3.new(0, 0, 0), 0.24))
		local rim = Create("Frame", {
			Name = "Rim",
			Size = UDim2.new(1, -14, 0, 3),
			Position = UDim2.fromOffset(7, 4),
			BackgroundColor3 = Theme.rim,
			BackgroundTransparency = 0.62,
			BorderSizePixel = 0,
			Parent = btn,
		})
		Components.corner(999, rim)
	else
		raise(btn, color)
	end

	pressable(btn)
	return btn
end

--[[
	Bottom-nav button: a glyph over a small label. Eight identical word-buttons
	in a row is what made the old HUD read as a toolbar; a glyph gives each
	destination its own shape, so players find things by silhouette.
]]
function Components.navButton(glyph: string, text: string, color: Color3, props: { [string]: any }?): TextButton
	local merged: { [string]: any } = {
		Text = "",
		BackgroundColor3 = color,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(92, 64),
	}
	if props then
		for key, value in pairs(props) do
			merged[key] = value
		end
	end

	local btn = Create("TextButton", merged) :: TextButton
	Components.corner(Theme.radiusSmall, btn)
	Components.stroke(btn, Theme.buttonStroke)
	Components.gradient(btn, color:Lerp(Color3.new(1, 1, 1), 0.28), color:Lerp(Color3.new(0, 0, 0), 0.26))

	local rim = Create("Frame", {
		Name = "Rim",
		Size = UDim2.new(1, -16, 0, 3),
		Position = UDim2.fromOffset(8, 4),
		BackgroundColor3 = Theme.rim,
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
		Parent = btn,
	})
	Components.corner(999, rim)

	Components.label(glyph, {
		Size = UDim2.new(1, 0, 0, 28),
		Position = UDim2.fromOffset(0, 8),
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = btn,
	})
	-- Labels get a dark outline: white-on-mid-purple is the pairing most likely
	-- to wash out on a bright phone screen outdoors.
	Components.label(string.upper(text), {
		Size = UDim2.new(1, 0, 0, 16),
		Position = UDim2.new(0, 0, 1, -22),
		Font = Theme.fontBold,
		TextSize = 12,
		TextStrokeTransparency = 0.5,
		TextStrokeColor3 = Theme.stroke,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = btn,
	})

	pressable(btn)
	return btn
end

--[[
	Horizontal progress bar. Used wherever a number alone is unreadable — how
	far through an Altar level you are, how close a quest is to done.
]]
function Components.bar(fraction: number, color: Color3, props: { [string]: any }?): Frame
	local merged: { [string]: any } = {
		BackgroundColor3 = Theme.bg,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 10),
	}
	if props then
		for key, value in pairs(props) do
			merged[key] = value
		end
	end
	local track = Create("Frame", merged) :: Frame
	Components.corner(999, track)
	Components.stroke(track, 2)

	local fill = Create("Frame", {
		Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = track,
	})
	Components.corner(999, fill)
	Components.gradient(fill, color:Lerp(Color3.new(1, 1, 1), 0.3), color)
	return track
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
	Components.gradient(frame, Theme.panel, Theme.bg)

	local header = Create("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundColor3 = Theme.panel,
		BorderSizePixel = 0,
		ZIndex = 11,
		Parent = frame,
	})
	Components.corner(Theme.radius, header)
	Components.gradient(header, Theme.panelLight, Theme.panel)
	-- Square off the header's bottom corners so it reads as a bar, not a card
	-- floating inside another card.
	Create("Frame", {
		Size = UDim2.new(1, 0, 0, Theme.radius),
		Position = UDim2.new(0, 0, 1, -Theme.radius),
		BackgroundColor3 = Theme.panel,
		BorderSizePixel = 0,
		ZIndex = 11,
		Parent = header,
	})
	-- Accent rule under the title: one bright line does more for perceived
	-- polish than any amount of extra chrome.
	local rule = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 3),
		Position = UDim2.new(0, 0, 1, -3),
		BackgroundColor3 = Theme.accentLight,
		BorderSizePixel = 0,
		ZIndex = 12,
		Parent = header,
	})
	Components.gradient(rule, Theme.accentLight, Theme.accent)

	Components.label(title, {
		Size = UDim2.new(1, -60, 1, -3),
		Position = UDim2.fromOffset(18, 0),
		Font = Theme.fontDisplay,
		TextSize = 22,
		ZIndex = 12,
		Parent = header,
	})

	local close = Components.button("✕", Theme.red, {
		Size = UDim2.fromOffset(36, 32),
		Position = UDim2.new(1, -46, 0, 9),
		TextSize = 16,
		ZIndex = 12,
		Parent = header,
	})
	close.MouseButton1Click:Connect(function()
		frame.Visible = false
	end)

	local body = Create("ScrollingFrame", {
		Name = "Body",
		Size = UDim2.new(1, -24, 1, -68),
		Position = UDim2.fromOffset(12, 60),
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
