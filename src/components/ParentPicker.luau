-- Pick a service or any parent selected in Explorer. No folder structure is created.
const Selection = game:GetService("Selection")
const DropdownSetting = require("./DropdownSetting")
const TextBoxSetting = require("./TextBoxSetting")

const ParentPicker = {}

function ParentPicker.selection(): (Instance?, string?)
	const selected = Selection:Get()
	if #selected ~= 1 then
		return nil, "Select one parent in Explorer."
	end
	const object = selected[1]
	const parent = if object:IsA("LuaSourceContainer") then object.Parent else object
	if parent == nil or (parent ~= game and not parent:IsDescendantOf(game)) then
		return nil, "The selected parent is no longer in the game."
	end
	return parent, nil
end

function ParentPicker.rows(target: (Instance?) -> Instance, onProblem: (string) -> (), firstOrder: number): { Frame }
	const choices = { "ReplicatedStorage", "ServerScriptService", "ServerStorage", "Workspace", "StarterGui" }
	const function useSelection()
		const parent, problem = ParentPicker.selection()
		if parent then
			target(parent)
			onProblem("")
		else
			onProblem(problem or "Select a parent.")
		end
	end
	return {
		DropdownSetting({
			name = "Parent", index = firstOrder,
			text = function() return target().Name end,
			options = function()
				const options = { { label = "Explorer selection", value = "selection" } }
				for _, service in choices do
					table.insert(options, { label = service, value = service })
				end
				return options
			end,
			onSelect = function(value)
				if value == "selection" then
					useSelection()
				else
					target(game:GetService(value))
					onProblem("")
				end
			end,
		}),
		TextBoxSetting({
			name = "Path", index = firstOrder + 1,
			description = "Select any parent in Explorer, then click Use. Selecting a script uses its parent.",
			readOnly = true,
			value = function() return target():GetFullName() end,
			button = { text = "Use", activated = useSelection },
		}),
	}
end

return ParentPicker
