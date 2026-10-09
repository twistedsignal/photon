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
const FIELD_OF_VIEW = 50
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
const function baseplate(parent: Instance)
	const floor = part(parent, {
		Name = "Baseplate",
		Size = Vector3.new(2048, 16, 2048),
		CFrame = CFrame.new(ORIGIN - Vector3.new(0, 8, 0)),
		Color = Color3.fromRGB(91, 91, 91),
		Material = Enum.Material.Plastic,
	})
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
function Stage.build(container: Instance): Shot
	const model = Instance.new("Model")
	model.Name = "PhotonStage"
	model.Archivable = false
	baseplate(model)
	reference(model)
	model.Parent = container
	return {
		model = model,
		camera = CFrame.lookAt(ORIGIN + Vector3.new(0, 6, -15), ORIGIN + Vector3.new(0, 2.6, 6)),
		fieldOfView = FIELD_OF_VIEW,
	}
end

return Stage
