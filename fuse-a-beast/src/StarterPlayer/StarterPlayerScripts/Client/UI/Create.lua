--!strict
--[[
	Create
	Tiny declarative instance builder used by the code-built UI. Assets in this
	repo are generated in code (no .rbxmx binaries in git) so the whole interface
	is diffable and reviewable. Swap for designer-built ScreenGuis later if desired.

	Usage:
		local frame = Create("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(0, 0, 0),
			Parent = someParent,
		}, {
			Create("TextLabel", { Text = "Hi" }),
		})
]]

local function Create(className: string, props: { [string]: any }?, children: { Instance }?): Instance
	local instance = Instance.new(className)
	if props then
		local parent = props.Parent
		props.Parent = nil
		for key, value in pairs(props) do
			(instance :: any)[key] = value
		end
		if children then
			for _, child in ipairs(children) do
				child.Parent = instance
			end
		end
		-- Parent last so all properties/children exist before it enters the tree.
		if parent then
			instance.Parent = parent
		end
	elseif children then
		for _, child in ipairs(children) do
			child.Parent = instance
		end
	end
	return instance
end

return Create
