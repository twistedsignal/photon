-- presets that ship with Photon. every preset sets all Lighting properties and lists all its
-- effects, so loading one gives the same result whatever the place had before.
const Schema = require("../Loader/Schema")
const Codec = require("../Loader/Codec")

export type Builtin = {
	id: string,
	name: string,
	data: Schema.Data,
}

const function rgb(r: number, g: number, b: number): { number }
	return { r / 255, g / 255, b / 255 }
end

-- the Lighting of Studio's Baseplate template. presets only list what they change.
const BASE = {
	Ambient = rgb(70, 70, 70),
	Brightness = 3,
	ColorShift_Bottom = rgb(0, 0, 0),
	ColorShift_Top = rgb(0, 0, 0),
	EnvironmentDiffuseScale = 1,
	EnvironmentSpecularScale = 1,
	GlobalShadows = true,
	OutdoorAmbient = rgb(70, 70, 70),
	ShadowSoftness = 0.2,
	ClockTime = 14.5,
	GeographicLatitude = 0,
	ExposureCompensation = 0,
	FogColor = rgb(192, 192, 192),
	FogEnd = 100000,
	FogStart = 0,
	LightingStyle = "Realistic",
	PrioritizeLightingQuality = true,
}

const function effect(class: string, props: { [string]: any }): Schema.Effect
	const section = Schema.byClass[class]
	const filled = Schema.defaults(section)
	for key, value in props do
		filled[key] = value
	end
	return { class = class, name = section.name, props = filled }
end

const function sky(props: { [string]: any }?): Schema.Effect
	return effect("Sky", props or {})
end

const function atmosphere(density: number, offset: number, color: { number }, decay: { number }, glare: number, haze: number): Schema.Effect
	return effect("Atmosphere", { Density = density, Offset = offset, Color = color, Decay = decay, Glare = glare, Haze = haze })
end

const function bloom(intensity: number, size: number, threshold: number): Schema.Effect
	return effect("BloomEffect", { Intensity = intensity, Size = size, Threshold = threshold })
end

const function sunRays(intensity: number, spread: number): Schema.Effect
	return effect("SunRaysEffect", { Intensity = intensity, Spread = spread })
end

const function correction(brightness: number, contrast: number, saturation: number, tint: { number }?): Schema.Effect
	return effect("ColorCorrectionEffect", {
		Brightness = brightness,
		Contrast = contrast,
		Saturation = saturation,
		TintColor = tint or rgb(255, 255, 255),
	})
end

const function preset(id: string, name: string, lighting: { [string]: any }, effects: { Schema.Effect }): Builtin
	const values = table.clone(BASE)
	for key, value in lighting do
		values[key] = value
	end
	return { id = `builtin:{id}`, name = name, data = { version = Schema.VERSION, lighting = values, effects = effects } }
end

const presets: { Builtin } = {
	preset("roblox-default", "Roblox Default", {}, {
		sky(),
		atmosphere(0.3, 0.25, rgb(199, 199, 199), rgb(106, 112, 125), 0, 0),
		bloom(1, 24, 2),
		effect("DepthOfFieldEffect", { Enabled = false, FarIntensity = 0.1, InFocusRadius = 30 }),
		sunRays(0.01, 0.1),
	}),
	preset("clear-day", "Clear Day", {
		ClockTime = 12.5,
		Ambient = rgb(40, 40, 45),
		OutdoorAmbient = rgb(128, 128, 135),
		ShadowSoftness = 0.15,
	}, {
		sky(),
		atmosphere(0.25, 0.2, rgb(190, 210, 235), rgb(90, 120, 160), 0, 0.5),
		bloom(0.6, 24, 2),
		sunRays(0.05, 0.2),
		correction(0, 0.05, 0.1),
	}),
	preset("golden-hour", "Golden Hour", {
		ClockTime = 17.4,
		Brightness = 2.6,
		ColorShift_Top = rgb(255, 170, 90),
		Ambient = rgb(60, 45, 35),
		OutdoorAmbient = rgb(140, 105, 80),
	}, {
		sky(),
		atmosphere(0.35, 0.1, rgb(255, 190, 130), rgb(200, 110, 60), 0.8, 1.5),
		bloom(0.8, 28, 1.6),
		sunRays(0.12, 0.3),
		correction(0.02, 0.1, 0.15, rgb(255, 240, 225)),
	}),
	preset("sunset", "Sunset", {
		ClockTime = 18.1,
		Brightness = 2,
		ColorShift_Top = rgb(255, 120, 60),
		Ambient = rgb(55, 35, 45),
		OutdoorAmbient = rgb(120, 80, 90),
	}, {
		sky(),
		atmosphere(0.4, 0, rgb(255, 150, 110), rgb(130, 60, 90), 1.5, 2.2),
		bloom(1, 30, 1.4),
		sunRays(0.2, 0.4),
		correction(0, 0.12, 0.2, rgb(255, 230, 225)),
	}),
	preset("overcast", "Overcast", {
		ClockTime = 13,
		Brightness = 1.2,
		ShadowSoftness = 1,
		Ambient = rgb(90, 92, 96),
		OutdoorAmbient = rgb(150, 152, 158),
		EnvironmentSpecularScale = 0.3,
	}, {
		sky(),
		atmosphere(0.5, 0.3, rgb(180, 185, 190), rgb(130, 135, 145), 0, 3),
		effect("Clouds", { Cover = 0.95, Density = 0.8, Color = rgb(200, 200, 205) }),
		correction(0, -0.05, -0.25),
	}),
	preset("foggy-morning", "Foggy Morning", {
		ClockTime = 7.2,
		Brightness = 1.5,
		ColorShift_Top = rgb(255, 220, 190),
		Ambient = rgb(80, 85, 95),
		OutdoorAmbient = rgb(130, 140, 155),
		FogColor = rgb(190, 200, 210),
	}, {
		sky(),
		atmosphere(0.62, 0.6, rgb(200, 210, 220), rgb(170, 180, 200), 0.3, 4),
		sunRays(0.1, 0.6),
		correction(0, 0, -0.1, rgb(240, 245, 255)),
	}),
	preset("night", "Night", {
		ClockTime = 0,
		Brightness = 0.6,
		Ambient = rgb(25, 28, 40),
		OutdoorAmbient = rgb(45, 50, 75),
		ColorShift_Top = rgb(120, 140, 200),
		ExposureCompensation = 0.3,
	}, {
		sky({ StarCount = 5000 }),
		atmosphere(0.3, 0, rgb(40, 50, 80), rgb(20, 25, 45), 0, 0),
		bloom(1, 24, 1.2),
		correction(0, 0, -0.2, rgb(210, 220, 255)),
	}),
	preset("moonlit", "Moonlit", {
		ClockTime = 23,
		Brightness = 1.2,
		ColorShift_Top = rgb(160, 180, 255),
		Ambient = rgb(30, 35, 55),
		OutdoorAmbient = rgb(70, 80, 120),
	}, {
		sky({ MoonAngularSize = 20, StarCount = 4000 }),
		atmosphere(0.25, 0, rgb(60, 80, 130), rgb(30, 40, 80), 0.5, 0.5),
		bloom(0.8, 24, 1.5),
		correction(0, 0.05, -0.3, rgb(200, 215, 255)),
	}),
	preset("neon-city", "Neon City", {
		ClockTime = 21,
		Brightness = 0.4,
		Ambient = rgb(60, 20, 80),
		OutdoorAmbient = rgb(90, 30, 120),
		ColorShift_Top = rgb(255, 0, 180),
		ColorShift_Bottom = rgb(0, 200, 255),
	}, {
		sky({ CelestialBodiesShown = false, StarCount = 0 }),
		atmosphere(0.45, 0.1, rgb(150, 40, 200), rgb(40, 0, 90), 2, 2),
		bloom(2, 40, 0.8),
		correction(0, 0.2, 0.4, rgb(240, 220, 255)),
	}),
	preset("horror", "Horror", {
		ClockTime = 2,
		Brightness = 0.1,
		Ambient = rgb(20, 10, 10),
		OutdoorAmbient = rgb(35, 25, 25),
		ExposureCompensation = -0.4,
	}, {
		sky({ CelestialBodiesShown = false, StarCount = 0 }),
		atmosphere(0.7, 0.4, rgb(60, 50, 50), rgb(30, 15, 15), 0, 5),
		correction(0, 0.25, -0.6, rgb(255, 225, 225)),
	}),
	preset("desert-heat", "Desert Heat", {
		ClockTime = 13.5,
		Brightness = 4,
		ColorShift_Top = rgb(255, 220, 170),
		Ambient = rgb(90, 70, 50),
		OutdoorAmbient = rgb(170, 140, 100),
		ShadowSoftness = 0.05,
	}, {
		sky(),
		atmosphere(0.38, 0.15, rgb(255, 215, 160), rgb(210, 150, 90), 0.4, 2.5),
		bloom(0.9, 30, 1.5),
		sunRays(0.1, 0.25),
		correction(0.05, 0.08, 0.1, rgb(255, 245, 225)),
	}),
	preset("arctic", "Arctic", {
		ClockTime = 10.5,
		Brightness = 3.2,
		GeographicLatitude = 70,
		ColorShift_Top = rgb(200, 225, 255),
		Ambient = rgb(80, 95, 115),
		OutdoorAmbient = rgb(160, 180, 210),
	}, {
		sky(),
		atmosphere(0.33, 0.3, rgb(210, 230, 255), rgb(150, 180, 220), 0.6, 1.5),
		effect("Clouds", { Cover = 0.6, Density = 0.5, Color = rgb(235, 240, 255) }),
		bloom(0.7, 24, 1.8),
		correction(0, 0.05, -0.15, rgb(235, 245, 255)),
	}),
	preset("underwater", "Underwater", {
		ClockTime = 12,
		Brightness = 1,
		Ambient = rgb(0, 60, 90),
		OutdoorAmbient = rgb(0, 90, 120),
		ColorShift_Top = rgb(0, 170, 200),
	}, {
		sky({ CelestialBodiesShown = false }),
		atmosphere(0.85, 0, rgb(20, 110, 140), rgb(0, 40, 70), 0, 3),
		effect("BlurEffect", { Size = 3 }),
		correction(0, -0.1, -0.1, rgb(180, 230, 255)),
	}),
	{
		id = "builtin:cartoon",
		name = "Cartoon",
		data = assert(Codec.decode("PHHa2H_JYz55B_-bQVQX6QbIev65kClJb9cyBS4qeuZApi0_XMgU2aXrmQKXVr1zIEC1bAiIOed1QAQAiniVB6n2f_z6yIUA")),
	},
}

return presets
