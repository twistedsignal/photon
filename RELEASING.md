# Releasing Photon

Every release updates two places: GitHub and the Roblox plugin page. Do both, in this order.

## 1. Bump the version

Set the new version in `wally.toml` (`version = "x.y.z"`). The build writes it into `src/Version.luau`, and the plugin shows it in Settings.

## 2. Push to GitHub

Commit with a message that describes the release. The release workflow uses that message as the release notes, then tags `vX.Y.Z` and attaches `Photon.rbxm` and `PhotonLoader.rbxm`. Push to `main`.

## 3. Publish the plugin on Roblox

Roblox's Open Cloud API can't upload plugins, so this step happens in Studio:

1. Run `./scripts/build.bash`.
2. Get `build/Photon.rbxm` into Studio, for example by dragging it into the Explorer.
3. Right-click the `Photon` script and choose **Save as Local Plugin...** or **Publish as Plugin...**. To update the existing plugin, pick it in the publish dialog instead of creating a new one.
4. Use these details:

   - **Name:** Photon
   - **Icon:** `assets/icon.png` (already uploaded as `rbxassetid://128686913190067`)
   - **Description:** the text below. **Change the `Release` line for every release.**

```
Load, save, import, and share lighting profiles across your game, and with fellow developers!

Release v0.1.0 - First release!
```

## Release history

Add the description's `Release` line here each time, newest first.

- `Release v0.1.0 - First release!`
