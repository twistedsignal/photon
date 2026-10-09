-- the scene a preview is rendered on, built far from the place's own map.
-- nothing here is Archivable; Capture destroys the stage once the screenshots are taken.
const Stage = {}

export type Shot = {
	model: Model,
	camera: CFrame,
	fieldOfView: number,
}

-- far from most maps, at ground level so Atmosphere's height falloff looks normal.
const ORIGIN = Vector3.new(0, 0, 40000)
const Settings = require("./Settings")
const GRID_TEXTURE = "rbxassetid://6372755229"

const function part(parent: Instance, props: { [string]: any }): BasePart
	const instance = Instance.new(props.ClassName or "Part") :: any
	props.ClassName = nil
	instance.Anchored = true
	instance.TopSurface = Enum.SurfaceType.Smooth
	instance.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		instance[key] = value
	end
	instance.Parent = parent
	return instance
end

-- the default Baseplate template's floor.
const function baseplate(parent: Instance, options: Settings.Options)
	const floor = part(parent, {
		Name = "Baseplate",
		Size = Vector3.new(2048, 16, 2048),
		CFrame = CFrame.new(ORIGIN - Vector3.new(0, 8, 0)),
		Color = Color3.fromHex(options.floorColor),
		Material = Enum.Material.Plastic,
	})
	if not options.grid then
		return
	end
	const grid = Instance.new("Texture")
	grid.Texture = GRID_TEXTURE
	grid.Face = Enum.NormalId.Top
	grid.Color3 = Color3.new(0, 0, 0)
	grid.Transparency = 0.8
	grid.StudsPerTileU = 8
	grid.StudsPerTileV = 8
	grid.Parent = floor
end

-- a blocky figure, so skin-like colors and self-shadowing read clearly.
const function figure(parent: Instance, at: Vector3)
	const skin = Color3.fromRGB(234, 184, 146)
	const shirt = Color3.fromRGB(52, 142, 64)
	const pants = Color3.fromRGB(39, 70, 196)
	part(parent, { Name = "LeftLeg", Size = Vector3.new(1, 2, 1), CFrame = CFrame.new(at + Vector3.new(-0.5, 1, 0)), Color = pants })
	part(parent, { Name = "RightLeg", Size = Vector3.new(1, 2, 1), CFrame = CFrame.new(at + Vector3.new(0.5, 1, 0)), Color = pants })
	part(parent, { Name = "Torso", Size = Vector3.new(2, 2, 1), CFrame = CFrame.new(at + Vector3.new(0, 3, 0)), Color = shirt })
	part(parent, { Name = "LeftArm", Size = Vector3.new(1, 2, 1), CFrame = CFrame.new(at + Vector3.new(-1.5, 3, 0)), Color = skin })
	part(parent, { Name = "RightArm", Size = Vector3.new(1, 2, 1), CFrame = CFrame.new(at + Vector3.new(1.5, 3, 0)), Color = skin })
	part(parent, {
		Name = "Head",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.2, 1.25, 1.25),
		CFrame = CFrame.new(at + Vector3.new(0, 4.6, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = skin,
	})
end

-- material spheres, blocks and a wall: shows shading, reflections, glow and cast shadows.
-- the camera looks along +Z, so +X is on the left of the picture.
const function reference(parent: Instance)
	const white = Color3.fromRGB(230, 230, 230)
	const spheres: { { any } } = {
		{ Enum.Material.Plastic, white },
		{ Enum.Material.SmoothPlastic, Color3.fromRGB(196, 40, 28) },
		{ Enum.Material.Metal, Color3.fromRGB(200, 200, 205) },
		{ Enum.Material.Glass, Color3.fromRGB(160, 200, 230) },
		{ Enum.Material.Neon, Color3.fromRGB(0, 200, 255) },
		{ Enum.Material.Wood, Color3.fromRGB(160, 110, 70) },
	}
	for index, sphere in spheres do
		part(parent, {
			Name = sphere[1].Name,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(2.6, 2.6, 2.6),
			CFrame = CFrame.new(ORIGIN + Vector3.new(7.5 - (index - 1) * 3, 1.3, 4)),
			Color = sphere[2],
			Material = sphere[1],
		})
	end
	part(parent, {
		Name = "Wall",
		Size = Vector3.new(20, 6, 1),
		CFrame = CFrame.new(ORIGIN + Vector3.new(0, 3, 10)),
		Color = white,
		Material = Enum.Material.Concrete,
	})
	part(parent, {
		Name = "Pillar",
		Size = Vector3.new(2, 11, 2),
		CFrame = CFrame.new(ORIGIN + Vector3.new(-12, 5.5, 9)),
		Color = Color3.fromRGB(110, 110, 115),
		Material = Enum.Material.Slate,
	})
	part(parent, {
		Name = "Crate",
		Size = Vector3.new(2.6, 2.6, 2.6),
		CFrame = CFrame.new(ORIGIN + Vector3.new(-10, 1.3, 0)) * CFrame.Angles(0, math.rad(25), 0),
		Color = Color3.fromRGB(245, 205, 48),
		Material = Enum.Material.SmoothPlastic,
	})
	figure(parent, ORIGIN + Vector3.new(10.5, 0, 0))
end

-- builds the scene inside container and returns where the camera should look from.
-- the camera looks away from the place's own map, with the horizon in the top third.
function Stage.build(container: Instance, options: Settings.Options?, previewModel: Model?): Shot
	const settings = options or Settings.defaults
	const model = Instance.new("Model")
	model.Name = "PhotonStage"
	model.Archivable = false
	const ok, shot = pcall(function()
		const scene = Instance.new("Model")
		scene.Name = "Subject"
		scene.Parent = model
		if previewModel then
			const subject = previewModel:Clone()
			subject.Parent = scene
			const _, size = subject:GetBoundingBox()
			subject:ScaleTo(subject:GetScale() * settings.modelSize / math.max(size.X, size.Y, size.Z, 0.01))
			subject:PivotTo(CFrame.Angles(0, math.rad(settings.modelRotation), 0) * subject:GetPivot())
			const bounds, scaled = subject:GetBoundingBox()
			subject:PivotTo(CFrame.new(ORIGIN - bounds.Position + Vector3.new(0, scaled.Y / 2, 0)) * subject:GetPivot())
			if settings.referenceProps then
				const props = Instance.new("Model")
				props.Name = "ReferenceProps"
				props.Parent = scene
				reference(props)
				props:PivotTo(CFrame.new(0, 0, scaled.Z / 2 + 8) * props:GetPivot())
			end
		elseif settings.referenceProps then
			reference(scene)
		else
			figure(scene, ORIGIN)
		end
		const bounds, size = scene:GetBoundingBox()
		const target = bounds.Position
		const yaw = math.rad(settings.cameraYaw)
		const pitch = math.rad(settings.cameraElevation)
		const direction = Vector3.new(math.sin(yaw) * math.cos(pitch), math.sin(pitch), -math.cos(yaw) * math.cos(pitch))
		const view = CFrame.lookAt(Vector3.zero, -direction)
		const vertical = math.tan(math.rad(settings.fieldOfView / 2))
		const horizontal = vertical * 16 / 9
		local fitted = 12
		for x = -1, 1, 2 do
			for y = -1, 1, 2 do
				for z = -1, 1, 2 do
					const corner = view:VectorToObjectSpace(bounds:VectorToWorldSpace(size * Vector3.new(x, y, z) / 2))
					fitted = math.max(fitted, math.abs(corner.X) / horizontal + corner.Z, math.abs(corner.Y) / vertical + corner.Z)
				end
			end
		end
		const offset = direction * fitted * 1.1 * settings.cameraDistance
		baseplate(model, settings)
		-- Exclude the whole temporary tree from change history.
		for _, instance in model:GetDescendants() do
			instance.Archivable = false
		end
		model.Parent = container
		return {
			model = model,
			camera = CFrame.lookAt(target + offset, target),
			fieldOfView = settings.fieldOfView,
		}
	end)
	if not ok then
		model:Destroy()
		error(shot, 0)
	end
	return shot
end

return Stage
