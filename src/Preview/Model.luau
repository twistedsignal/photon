-- Native instance serialization retains meshes, unions, materials and internal references.
const SerializationService = game:GetService("SerializationService")
const Base64 = require("../Loader/Base64")

const PreviewModel = {}
const MAX_INSTANCES = 2000
const MAX_BYTES = 4 * 1024 * 1024

export type Saved = { version: number, id: string, name: string, data: string }

const function sanitize(model: Model)
	for _, instance in model:GetDescendants() do
		if instance:IsA("LuaSourceContainer") then
			instance:Destroy()
		elseif instance:IsA("BasePart") then
			instance.Anchored = true
			instance.CanCollide = false
			instance.AssemblyLinearVelocity = Vector3.zero
			instance.AssemblyAngularVelocity = Vector3.zero
		elseif instance:IsA("Sound") then
			instance.Playing = false
		end
	end
end

const function hasParts(model: Model): boolean
	return model:FindFirstChildWhichIsA("BasePart", true) ~= nil
end

function PreviewModel.encode(selected: Instance, id: string): (Saved, Model)
	assert(selected:IsA("Model") or selected:IsA("BasePart"), "Select one Model or part in Explorer.")
	assert(#selected:GetDescendants() + 2 <= MAX_INSTANCES, `Preview models can contain up to {MAX_INSTANCES} instances.`)
	const clone = selected:Clone()
	assert(clone, "Enable Archivable on the selected model first.")
	const model = Instance.new("Model")
	model.Name = selected.Name
	clone.Parent = model
	const ok, result = pcall(function()
		sanitize(model)
		assert(hasParts(model), "The selection has no archivable parts.")
		const pivot, size = model:GetBoundingBox()
		model:PivotTo(CFrame.new(-Vector3.new(pivot.Position.X, pivot.Position.Y - size.Y / 2, pivot.Position.Z)) * model:GetPivot())
		const bytes = SerializationService:SerializeInstancesAsync({ model })
		assert(buffer.len(bytes) <= MAX_BYTES, "This model is too large to save. Select a smaller model.")
		return { version = 1, id = id, name = selected.Name, data = Base64.encode(bytes) }
	end)
	if not ok then
		model:Destroy()
		error(result, 0)
	end
	return result, model
end

function PreviewModel.decode(saved: any): Model
	assert(type(saved) == "table" and saved.version == 1 and type(saved.data) == "string" and type(saved.id) == "string" and type(saved.name) == "string", "Invalid saved preview model.")
	assert(#saved.data <= math.ceil(MAX_BYTES / 3) * 4, "Saved preview model is too large.")
	const roots = SerializationService:DeserializeInstancesAsync(Base64.decode(saved.data))
	const model = roots[1]
	if #roots ~= 1 or model == nil or not model:IsA("Model") or not hasParts(model) or #model:GetDescendants() > MAX_INSTANCES then
		for _, root in roots do
			root:Destroy()
		end
		error("Saved preview model has no usable geometry.")
	end
	sanitize(model)
	return model :: Model
end

return PreviewModel
