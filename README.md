<div align="center">
  <img src="assets/icon.png" width="72" />
  <h1>Photon</h1>
  <p>Lighting presets for Roblox Studio.</p>
</div>

Save your lighting, preview presets and share them as codes. Your library, settings and preview model carry across places.

## Install

Install Photon from the Creator Store, or download `Photon.rbxm` from the [latest release](https://github.com/twistedsignal/photon/releases/latest). Put it in your Studio Plugins folder, found under Plugins > Plugins Folder, then restart Studio.

## Use

Open Photon from the Plugins tab and pick a preset.

- **Load** applies it to your place. Ctrl+Z undoes it.
- **Insert** adds an editable preset folder wherever you choose.
- **Save** captures your current lighting.
- **Import / Export** lets you share presets as codes.

Use folders to organize your library. A preset's **•••** menu lets you retake its preview, or rename, move, update and delete your own presets.

### Previews

Roblox renders previews on a temporary baseplate. This takes a few seconds and briefly changes the viewport. Photon restores your lighting, camera and selection afterwards, then saves the preview for next time.

Settings has controls for the camera, floor, grid and reference props. To use your own preview model, select a model or part in Explorer and click **Use selection**. You can adjust its size and rotation, or click **Use default** to reset it. Turn off **Automatic previews** to capture only when you click refresh.

## Use presets in scripts

Click **Insert loader** to choose functions, casing, `const` or `local`, and types. The default is just `Load`, with PascalCase, `const` and types enabled.

Choose a service as the destination, or select your own parent in Explorer and click **Use**. The loader is a single ModuleScript you can rename or move. Preset folders can live anywhere too.

For example, with a loader named `PhotonLoader` and a folder named `LightingPresets` in ReplicatedStorage:

```lua
local Photon = require(game.ReplicatedStorage.PhotonLoader)
local presets = game.ReplicatedStorage.LightingPresets

Photon.Load(presets["Golden Hour"])
Photon.Load(presets.Night, TweenInfo.new(3)) -- tween over 3 seconds
Photon.Load("Golden Hour", nil, presets)   -- look up a name in this folder
Photon.Load("PHEAAAAA")                    -- load a share code
```

The module only exposes the functions you check. Names below use PascalCase.

| Function | What it does |
| --- | --- |
| `Load` | Load a preset folder, name, code or data table. Accepts an optional TweenInfo. |
| `Apply` | Apply a data table directly. Also accepts TweenInfo. |
| `List` | List names in a preset container. |
| `Capture` | Read current lighting and effects as data. |
| `Encode` / `Decode` | Convert between data and share codes. |
| `Resolve` | Read a preset as data without applying it. |
| `ToFolder` / `FromFolder` | Convert between data and editable preset folders. |
| `Stop` | Cancel the loader's lighting tweens. |
| `SetPresets` | Set a default container for name lookups. |

For name lookups, pass a container as shown above, call `SetPresets(container)` if included, or keep a folder named `Presets` beside the loader.

You can edit the values and effects inside a preset folder. Delete a value to leave that property alone when loading.

A server Script changes lighting for everyone. A LocalScript changes it for that player. Presets include lighting properties, skies, atmosphere, post-processing effects and clouds. `Lighting.Technology` is excluded because scripts can't read it.

You can also download the default loader as `PhotonLoader.rbxm` from the release page.

## Development

Install [Rokit](https://github.com/rojo-rbx/rokit), then run:

```sh
rokit install
wally install
./scripts/build.bash  # builds the plugin and loader in build/
./scripts/test.bash   # lint and tests
./scripts/dev.bash    # rebuilds a local dev plugin when files change
```

Restart the dev watcher after changing `src/Loader` or `scripts/generate-loader.py`. Build and test scripts regenerate loader variants automatically.

See [RELEASING.md](RELEASING.md) for publishing steps.

## License

MIT © Twisted Signal. Lucide icons use the [ISC license](third_party/lucide-LICENSE).
