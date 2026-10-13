extends Node

## Autoload "Audio": every sound in the game goes through here.
## Audio.play("enemy_hit") plays a random variant on the "SFX" bus; Audio.play_music("boss") crossfades on "Music".
## To swap a sound, edit its entry in SOUNDS. "db" is volume, "gap" is the minimum seconds between retriggers.

const SFX_DIR := "res://assets/Audio/sfx/"
const MUSIC_DIR := "res://assets/Audio/music/"
const SOUNDS := {
	"shoot": {"files": ["shot_0.wav", "shot_1.wav", "shot_2.wav"], "db": -10.0},
	"wall_hit": {"files": ["impactGeneric_light_000.ogg", "impactGeneric_light_001.ogg", "impactGeneric_light_002.ogg"], "db": -16.0},
	"enemy_hit": {"files": ["impactPunch_medium_000.ogg", "impactPunch_medium_001.ogg", "impactPunch_medium_002.ogg"], "db": -6.0},
	"enemy_die": {"files": ["impactWood_heavy_000.ogg", "impactWood_heavy_001.ogg", "impactWood_heavy_002.ogg"], "db": -3.0},
	"enemy_shoot": {"files": ["knifeSlice.ogg", "knifeSlice2.ogg"], "db": -12.0, "gap": 0.08},
	"spawn": {"files": ["phaserUp1.ogg"], "db": -14.0, "gap": 0.3},
	"player_hurt": {"files": ["impactPunch_heavy_000.ogg", "impactPunch_heavy_001.ogg", "impactPunch_heavy_002.ogg"], "db": -2.0},
	"player_die": {"files": ["zapThreeToneDown.ogg"], "db": -4.0, "pitch": 0.0},
	"roll": {"files": ["cloth1.ogg", "cloth2.ogg", "cloth3.ogg"], "db": -4.0},
	"pit_fall": {"files": ["phaserDown1.ogg"], "db": -6.0},
	"coin": {"files": ["handleCoins.ogg", "handleCoins2.ogg"], "db": -10.0, "gap": 0.07},
	"heal": {"files": ["powerUp2.ogg"], "db": -6.0, "pitch": 0.0},
	"purchase": {"files": ["powerUp7.ogg"], "db": -6.0, "pitch": 0.0},
	"denied": {"files": ["error_004.ogg"], "db": -8.0, "pitch": 0.0},
	"gate_close": {"files": ["impactMetal_heavy_000.ogg"], "db": -4.0},
	"room_clear": {"files": ["jingles_NES00.ogg"], "db": -6.0, "pitch": 0.0},
	"boss_phase": {"files": ["impactBell_heavy_000.ogg"], "db": -2.0, "pitch": 0.0},
	"boss_slam": {"files": ["impactPlate_heavy_000.ogg"], "db": -2.0},
	"boss_charge": {"files": ["phaserUp4.ogg"], "db": -8.0},
	"shop_open": {"files": ["maximize_001.ogg"], "db": -10.0, "pitch": 0.0},
	"shop_close": {"files": ["minimize_001.ogg"], "db": -10.0, "pitch": 0.0},
	"book_open": {"files": ["bookOpen.ogg"], "db": -6.0},
	"book_close": {"files": ["bookClose.ogg"], "db": -6.0},
	"click": {"files": ["click_001.ogg"], "db": -8.0},
	"hover": {"files": ["tick_002.ogg"], "db": -16.0, "gap": 0.05},
}
const MUSIC := {"title": "title.mp3", "dungeon": "dungeon.mp3", "boss": "boss.mp3", "victory": "victory.mp3"}
const ONE_SHOT_MUSIC := ["victory"]
const POOL_SIZE := 24
const DEFAULT_GAP := 0.03
const DEFAULT_PITCH := 0.08
const MUSIC_DB := -6.0

var streams := {}
var pool: Array[AudioStreamPlayer] = []
var next_voice := 0
var last_played := {}
var music_players: Array[AudioStreamPlayer] = []
var active_music := 0
var current_track := ""
var fade_tween: Tween

func _ready() -> void:
	# Keep menus, crossfades and the pause screen audible while the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for sound in SOUNDS:
		var variants: Array[AudioStream] = []
		for file in SOUNDS[sound].files:
			variants.append(load(SFX_DIR + file))
		streams[sound] = variants
	for index in POOL_SIZE:
		var voice := AudioStreamPlayer.new()
		voice.bus = &"SFX"
		add_child(voice)
		pool.append(voice)
	for index in 2:
		var music := AudioStreamPlayer.new()
		music.bus = &"Music"
		add_child(music)
		music_players.append(music)
	get_tree().node_added.connect(_on_node_added)

func play(sound: String) -> void:
	var entry: Dictionary = SOUNDS.get(sound, {})
	if entry.is_empty():
		push_warning("Audio: unknown sound '%s'" % sound)
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(last_played.get(sound, -1.0)) < float(entry.get("gap", DEFAULT_GAP)):
		return
	last_played[sound] = now
	var voice := _free_voice()
	var variants: Array = streams[sound]
	var jitter: float = entry.get("pitch", DEFAULT_PITCH)
	voice.stream = variants.pick_random()
	voice.volume_db = entry.get("db", 0.0)
	voice.pitch_scale = randf_range(1.0 - jitter, 1.0 + jitter)
	voice.play()

func play_music(track: String, fade := 1.0) -> void:
	if track == current_track:
		return
	current_track = track
	var old := music_players[active_music]
	active_music = 1 - active_music
	var music := music_players[active_music]
	var stream := load(MUSIC_DIR + MUSIC[track]) as AudioStreamMP3
	stream.loop = not ONE_SHOT_MUSIC.has(track)
	music.stream = stream
	music.volume_db = -40.0
	music.play()
	_restart_fade()
	fade_tween.set_parallel()
	fade_tween.tween_property(music, "volume_db", MUSIC_DB, fade)
	if old.playing:
		fade_tween.tween_property(old, "volume_db", -40.0, fade)
		fade_tween.chain().tween_callback(old.stop)

func stop_music(fade := 1.0) -> void:
	current_track = ""
	var music := music_players[active_music]
	if not music.playing:
		return
	_restart_fade()
	fade_tween.tween_property(music, "volume_db", -40.0, fade)
	fade_tween.tween_callback(music.stop)

func _restart_fade() -> void:
	if fade_tween != null:
		fade_tween.kill()
	fade_tween = create_tween()

func _free_voice() -> AudioStreamPlayer:
	for index in POOL_SIZE:
		var voice := pool[(next_voice + index) % POOL_SIZE]
		if not voice.playing:
			next_voice = (next_voice + index + 1) % POOL_SIZE
			return voice
	# Every voice is busy: steal the oldest one.
	var voice := pool[next_voice]
	next_voice = (next_voice + 1) % POOL_SIZE
	return voice

func _on_node_added(node: Node) -> void:
	# Every button in every menu gets click and hover sounds without per-screen wiring.
	if node is BaseButton:
		node.pressed.connect(play.bind("click"))
		node.mouse_entered.connect(play.bind("hover"))
