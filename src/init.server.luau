const RunService = game:GetService("RunService")

if not RunService:IsEdit() then
	return
end

const vide = require("@self/vide")
const App = require("@self/App")
const Icons = require("@self/Icons")

const WIDGET_ID = "photon-main"

const toolbar = plugin:CreateToolbar("Photon")
const button = toolbar:CreateButton("Photon", "Save, load, share and preview lighting presets", Icons.plugin)
button.ClickableWhenViewportHidden = true

const widget = plugin:CreateDockWidgetPluginGuiAsync(
	WIDGET_ID,
	DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, false, false, 520, 760, 380, 480)
)
widget.Name = "Photon"
widget.Title = "Photon"
widget.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- dev builds (Photon-dev.rbxm from scripts/dev.bash) expose their modules to the command bar.
const dev = string.find(plugin.Name, "dev", 1, true) ~= nil

local unmount: (() -> ())? = nil

const function mount()
	if unmount then
		return
	end
	unmount = vide.mount(function()
		return App({
			plugin = plugin,
			onStore = if dev
				then function(store)
					const tools = {
						store = store,
						Capture = require("@self/Preview/Capture"),
						Snapshot = require("@self/Loader/Snapshot"),
						Codec = require("@self/Loader/Codec"),
					}
					-- selene: allow(global_usage)
					const globals = shared :: any
					globals.PhotonDev = tools
				end
				else nil,
		})
	end, widget)
end

button.Click:Connect(function()
	widget.Enabled = not widget.Enabled
end)

widget:GetPropertyChangedSignal("Enabled"):Connect(function()
	button:SetActive(widget.Enabled)
	if widget.Enabled then
		mount()
	end
end)

if widget.Enabled then
	button:SetActive(true)
	mount()
end

plugin.Unloading:Connect(function()
	if unmount then
		unmount()
		unmount = nil
	end
end)
