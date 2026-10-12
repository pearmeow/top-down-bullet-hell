extends Node

## Autoload "Settings": player options, saved to user://settings.cfg and applied on launch.
## Sound effects should play on the "SFX" bus and music on the "Music" bus so the sliders work.

const PATH := "user://settings.cfg"
const BUSES := ["Master", "Music", "SFX"]
var volumes := {"Master": 0.8, "Music": 0.7, "SFX": 0.8}
var fullscreen := false
var screen_shake := true

func _ready() -> void:
	for bus in BUSES:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, "Master")
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		for bus in BUSES:
			volumes[bus] = clampf(float(config.get_value("audio", bus, volumes[bus])), 0.0, 1.0)
		fullscreen = bool(config.get_value("video", "fullscreen", fullscreen))
		screen_shake = bool(config.get_value("video", "screen_shake", screen_shake))
	apply()

func apply() -> void:
	for bus in BUSES:
		var index := AudioServer.get_bus_index(bus)
		var value: float = volumes[bus]
		AudioServer.set_bus_mute(index, value <= 0.001)
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.001)))
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.get_name() != "headless" and DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)

func save() -> void:
	var config := ConfigFile.new()
	for bus in BUSES:
		config.set_value("audio", bus, volumes[bus])
	config.set_value("video", "fullscreen", fullscreen)
	config.set_value("video", "screen_shake", screen_shake)
	config.save(PATH)
