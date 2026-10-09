const HttpService = game:GetService("HttpService")

const MAX_ATTEMPTS = 8
const RETRY_DELAY = 0.1

const function getEquivalentTableValue(container: { [any]: any }, key: any): any
	const value = container[key]
	if value ~= nil then
		return value
	end

	if typeof(key) == "number" then
		return container[tostring(key)]
	end
	if typeof(key) == "string" then
		const numericKey = tonumber(key)
		if numericKey ~= nil then
			return container[numericKey]
		end
	end

	return nil
end

const function valuesEqual(left: any, right: any): boolean
	if typeof(left) ~= typeof(right) then
		return false
	end
	if typeof(left) ~= "table" then
		return left == right
	end

	local leftCount = 0
	for key, value in left do
		leftCount += 1
		const rightValue = getEquivalentTableValue(right, key)
		if rightValue == nil or not valuesEqual(value, rightValue) then
			return false
		end
	end

	local rightCount = 0
	for _ in right do
		rightCount += 1
	end
	return leftCount == rightCount
end

const function readRaw(plugin: Plugin, key: string): (boolean, any)
	local readSucceeded = false
	for attempt = 1, MAX_ATTEMPTS do
		const success, value = pcall(function()
			return plugin:GetSetting(key)
		end)
		if success then
			readSucceeded = true
		end
		if success and value ~= nil then
			return true, value
		end

		if attempt < MAX_ATTEMPTS then
			task.wait(RETRY_DELAY)
		end
	end

	return readSucceeded, nil
end

const function load(plugin: Plugin, key: string, fallback: any): any
	const readSucceeded, saved = readRaw(plugin, key)
	if not readSucceeded then
		error(`Photon could not read saved data for {key} after {MAX_ATTEMPTS} attempts.`)
	end
	if saved == nil then
		return fallback
	end
	if typeof(saved) == "table" then
		return saved
	end
	if typeof(saved) ~= "string" then
		warn(`Photon found an invalid saved value for {key}; using defaults.`)
		return fallback
	end

	const success, decoded = pcall(function()
		return HttpService:JSONDecode(saved)
	end)
	if not success then
		warn(`Photon could not decode saved data for {key}; using defaults.`)
		return fallback
	end
	return decoded
end

const function save(plugin: Plugin, key: string, value: any)
	const serialized = HttpService:JSONEncode(value)
	for attempt = 1, MAX_ATTEMPTS do
		const success = pcall(function()
			plugin:SetSetting(key, serialized)
		end)
		if success then
			task.wait(RETRY_DELAY * attempt)
			const readSuccess, saved = readRaw(plugin, key)
			if readSuccess then
				if saved == serialized then
					return
				end

				if typeof(saved) == "string" then
					const decodedSuccess, decoded = pcall(function()
						return HttpService:JSONDecode(saved)
					end)
					if decodedSuccess and valuesEqual(decoded, value) then
						return
					end
				elseif valuesEqual(saved, value) then
					return
				end
			end
		end

		if attempt < MAX_ATTEMPTS then
			task.wait(RETRY_DELAY)
		end
	end

	error(`Photon could not verify saved data for {key} after {MAX_ATTEMPTS} attempts.`)
end

return {
	load = load,
	save = save,
}
