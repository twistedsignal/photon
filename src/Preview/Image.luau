-- EditableImage helpers: fitting a screenshot into a preview, and packing pixels for storage.
const AssetService = game:GetService("AssetService")
const EncodingService = game:GetService("EncodingService")

const Image = {}

-- samples per axis when shrinking; more is smoother and slower.
const MAX_SAMPLES = 3

function Image.create(width: number, height: number): EditableImage
	return AssetService:CreateEditableImage({ Size = Vector2.new(width, height) })
end

-- center-crops source to the target's aspect ratio and box-filters it down to width x height.
function Image.fit(source: EditableImage, width: number, height: number): EditableImage
	const sourceSize = source.Size
	const aspect = width / height
	local cropWidth, cropHeight = sourceSize.X, sourceSize.X / aspect
	if cropHeight > sourceSize.Y then
		cropWidth, cropHeight = sourceSize.Y * aspect, sourceSize.Y
	end
	cropWidth, cropHeight = math.floor(cropWidth), math.floor(cropHeight)
	const left = math.floor((sourceSize.X - cropWidth) / 2)
	const top = math.floor((sourceSize.Y - cropHeight) / 2)
	const pixels = source:ReadPixelsBuffer(Vector2.new(left, top), Vector2.new(cropWidth, cropHeight))

	const output = buffer.create(width * height * 4)
	const scaleX, scaleY = cropWidth / width, cropHeight / height
	const samplesX = math.clamp(math.floor(scaleX), 1, MAX_SAMPLES)
	const samplesY = math.clamp(math.floor(scaleY), 1, MAX_SAMPLES)
	const count = samplesX * samplesY
	for y = 0, height - 1 do
		for x = 0, width - 1 do
			local r, g, b = 0, 0, 0
			for sy = 0, samplesY - 1 do
				const py = math.min(math.floor((y + (sy + 0.5) / samplesY) * scaleY), cropHeight - 1)
				for sx = 0, samplesX - 1 do
					const px = math.min(math.floor((x + (sx + 0.5) / samplesX) * scaleX), cropWidth - 1)
					const offset = (py * cropWidth + px) * 4
					r += buffer.readu8(pixels, offset)
					g += buffer.readu8(pixels, offset + 1)
					b += buffer.readu8(pixels, offset + 2)
				end
			end
			const offset = (y * width + x) * 4
			buffer.writeu8(output, offset, r // count)
			buffer.writeu8(output, offset + 1, g // count)
			buffer.writeu8(output, offset + 2, b // count)
			buffer.writeu8(output, offset + 3, 255)
		end
		if y % 64 == 63 then
			task.wait()
		end
	end

	const image = Image.create(width, height)
	image:WritePixelsBuffer(Vector2.zero, Vector2.new(width, height), output)
	return image
end

-- opaque RGB pixels, zstd-compressed. returns nil if EncodingService isn't available.
function Image.pack(image: EditableImage): buffer?
	const size = image.Size
	const rgba = image:ReadPixelsBuffer(Vector2.zero, size)
	const rgb = buffer.create(size.X * size.Y * 3)
	for i = 0, size.X * size.Y - 1 do
		buffer.writeu8(rgb, i * 3, buffer.readu8(rgba, i * 4))
		buffer.writeu8(rgb, i * 3 + 1, buffer.readu8(rgba, i * 4 + 1))
		buffer.writeu8(rgb, i * 3 + 2, buffer.readu8(rgba, i * 4 + 2))
	end
	const ok, packed = pcall(function()
		return EncodingService:CompressBuffer(rgb, Enum.CompressionAlgorithm.Zstd, 9)
	end)
	return if ok then packed else nil
end

function Image.unpack(packed: buffer, width: number, height: number): EditableImage?
	const ok, rgb = pcall(function()
		return EncodingService:DecompressBuffer(packed, Enum.CompressionAlgorithm.Zstd)
	end)
	if not ok or buffer.len(rgb) ~= width * height * 3 then
		return nil
	end
	const rgba = buffer.create(width * height * 4)
	for i = 0, width * height - 1 do
		buffer.writeu8(rgba, i * 4, buffer.readu8(rgb, i * 3))
		buffer.writeu8(rgba, i * 4 + 1, buffer.readu8(rgb, i * 3 + 1))
		buffer.writeu8(rgba, i * 4 + 2, buffer.readu8(rgb, i * 3 + 2))
		buffer.writeu8(rgba, i * 4 + 3, 255)
	end
	const image = Image.create(width, height)
	image:WritePixelsBuffer(Vector2.zero, Vector2.new(width, height), rgba)
	return image
end

return Image
