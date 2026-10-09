<div align="center">
  <img src="assets/icon.png" width="72" />
  <h1>Photon</h1>
  <p>Save, load, share and preview Roblox lighting presets, right inside Studio.</p>
</div>

Photon keeps a library of lighting presets that follows you between places. Preview any preset rendered by Roblox itself, load it into your place, insert it for scripts to use, or share it as a short code.

Everything runs inside Studio. There's no backend or account.

## Install

Install Photon from the Creator Store, or download `Photon.rbxm` from the [latest release](https://github.com/twistedsignal/photon/releases/latest), put it in your Studio Plugins folder (Plugins → Plugins Folder) and restart Studio.

To build it yourself, install [Rokit](https://github.com/rojo-rbx/rokit), then:

```sh
rokit install
wally install
./scripts/build.bash   # writes build/Photon.rbxm and build/PhotonLoader.rbxm
```

## Use Photon

Click **Photon** in the Plugins tab and pick a preset. The bar at the bottom acts on it:

The **Insert loader** button in the header opens a popup. Check the functions you need, choose function casing, `const` or `local` bindings, and whether to include types. The default has only `Load`, PascalCase, `const` and types.

- **Load** applies the preset to your place's Lighting. Ctrl+Z undoes it.
- **Insert** opens a destination picker for the selected preset.
- The icons on the right **save** your current Studio lighting as a new preset, **import** a code someone shared, and **export** the selected preset as a code, such as `PHEB...`.

Each card's **•••** menu also has **Retake preview**. Your own presets add **Move to folder**, **Update from Studio** (replaces the preset with your current lighting, after asking first), **Rename** and **Delete**.

### Folders

Presets are grouped in collapsible folders. **Built-in** holds the 14 presets that come with Photon: Roblox Default, Clear Day, Golden Hour, Sunset, Overcast, Foggy Morning, Night, Moonlit, Neon City, Horror, Desert Heat, Arctic, Underwater and Cartoon. Create your own folders with the folder button next to the search box, then rename or delete them from their **•••** menu. Presets in a deleted folder move to **Unsorted**.

Your presets and folders are stored with your Studio settings, so they're there in every place you open.

### Previews

When you pick a preset, Photon shows a picture of it taken by Roblox itself, so you see exactly how the lighting looks: shadows, atmosphere, sky, clouds, bloom and color grading included. To take it, Photon:

1. starts a change-history recording,
2. applies the preset and builds a small test scene far from your map (a baseplate with material spheres, a figure, a wall and a pillar),
3. points the camera at it and takes screenshots until the picture stops changing, since Roblox takes a few seconds to finish updating lighting,
4. cancels the recording, which puts your lighting back and leaves nothing in the undo history.

Your camera and selection are restored afterwards. While this happens, Studio's viewport shows the preset for a few seconds. Previews are saved, so each preset is only previewed once. Retake one from the preview's refresh button or the card's menu.

### Preview settings

Settings has controls for camera distance, field of view, orbit and elevation, floor color, grid, reference props and capture settle time. Turn off **Automatic previews** to capture only when you click refresh.

To use your own preview model, select a Model or part in Explorer and click **Use selection** in Settings. Photon saves a copy with Studio's native instance serializer, including meshes, unions and textures. The copy stays available across places and Studio restarts. Scripts are removed and parts are anchored. **Use default** restores the built-in scene.

**Model size** fits the longest side to a chosen number of studs; **Model rotation** turns it on the baseplate. Settings also persist across places. Changing the scene or camera invalidates previews taken with the previous settings.

### What a preset contains

Photon saves everything a preset needs. `Lighting.Technology` is the exception: scripts can't read it.

- **Lighting**: Ambient, Brightness, both ColorShifts, environment diffuse and specular scale, GlobalShadows, OutdoorAmbient, ShadowSoftness, ClockTime, GeographicLatitude, ExposureCompensation, fog, LightingStyle and PrioritizeLightingQuality.
- **Instances**: Sky, Atmosphere, Bloom, Blur, ColorCorrection, ColorGrading, DepthOfField and SunRays effects, plus `Terrain.Clouds`.

## Load presets from scripts

Loaders and preset folders can go anywhere. In either insertion popup, choose a service or select your own parent in Explorer and click **Use**. You can rename the loader and move it later. Photon does not create a folder structure or insert a loader alongside a preset.

For example, you could choose this structure:

```
ReplicatedStorage
└── Shared
    ├── Lighting       (one self-contained ModuleScript)
    └── LightingPresets
        └── Golden Hour
            ├── Ambient, Brightness, ClockTime, ...   (one value per Lighting property)
            └── child
                └── Sky, Atmosphere, ColorCorrection, ...
```

Preset folders are ordinary instances, so you can edit the values and effects in Studio. Delete a value and loading leaves that property alone.

```lua
local Photon = require(game.ReplicatedStorage.Shared.Lighting)
local presets = game.ReplicatedStorage.Shared.LightingPresets

Photon.Load(presets["Golden Hour"])             -- instant
Photon.Load(presets.Night, TweenInfo.new(3))     -- tween over 3 seconds
Photon.Load("PHEBAAAA...")                     -- a share code works too
Photon.Load("Golden Hour", nil, presets)       -- name lookup in any container
```

Only checked functions appear in the returned module. Required helpers stay private. With PascalCase, the available functions are:

| Function | What it does |
| --- | --- |
| `Load(target, tweenInfo?, container?)` | Load a name, folder, share code or data table. |
| `Apply(data, tweenInfo?)` | Apply a data table directly. |
| `List(container?)` | List preset names in a container. |
| `Capture()` | Capture current Lighting and effects as data. |
| `Encode(data)` / `Decode(code)` | Convert between data and a PH share code. |
| `Resolve(target, container?)` | Read a target as data without applying it. |
| `ToFolder(data, name)` / `FromFolder(folder)` | Convert between data and editable preset folders. |
| `Stop()` | Cancel this module's active lighting tweens. |
| `SetPresets(container?)` | Set or clear a default container for name lookups. |

For name lookups, pass a container explicitly or enable `SetPresets`. As a convenience, the loader also recognizes a child or sibling folder named `Presets`. Direct folder references, share codes and data tables need no container.

`const` keeps reassigned variables `local`. Turning types off removes annotations and type declarations. Casing changes public function names, such as `ToFolder`, `toFolder`, `to_folder` or `TO_FOLDER`.

Loading from a server Script changes lighting for everyone. Loading from a LocalScript changes it for that player only.

When tweening, numbers and colors on Lighting and on matching effects animate. ClockTime takes the short way around midnight. Sky textures, toggles and enum values switch at the start. Effects the preset doesn't have are removed. Photon never removes anything else under Lighting, such as scripts or lights.

The default loader is also attached to each release as `PhotonLoader.rbxm`. Use the plugin popup to generate other configurations.

## Lighting codes

Codes are kept short by packing bits instead of writing text:

- A code is `PH` followed by base64url.
- Inside are a 4-bit format version, then every Lighting property, then each effect.
- Each property starts with one bit that says whether it differs from Roblox's default. Unchanged properties cost that single bit.
- Changed numbers are rounded to a fixed step (0.01 for Brightness, one minute for ClockTime) and packed into as few bits as their range needs.
- Colors take 24 bits and asset IDs are varints.

Default lighting encodes to `PHEAAAAA`. The built-in presets encode to 46–96 characters.

Because of the rounding, an imported preset can differ from the original by less than one step. Presets you save yourself keep full precision.

## Development

```sh
./scripts/dev.bash    # rebuilds Photon-dev.rbxm into your Plugins folder on every change
./scripts/test.bash   # selene and the lune tests
```

Dev builds (any plugin file with `dev` in its name) expose `shared.PhotonDev` for testing from the command bar. `scripts/bundle.py` bundles modules into one chunk that you can paste into the command bar.

`scripts/generate-loader.py` derives loader variants from `src/Loader`, using Darklua to remove types. Build and test scripts regenerate them automatically. Restart the dev watcher after changing the loader runtime or generator.

[`RELEASING.md`](RELEASING.md) lists the steps for a release, including the Roblox plugin description to update each time.

## License

MIT © Twisted Signal. Lucide icons are under the [ISC license](third_party/lucide-LICENSE).
