extends SceneTree
## Real title ownership, replacement data, native looping, and mixer retirement.
const RETIRE_AUDIO: GDScript = preload("res://tests/support/audio_retirement.gd")
var checks: int = 0
var failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("Title music: " + message)


func _run() -> void:
	create_timer(10.0).timeout.connect(func():
		push_error("Title music checks timed out")
		quit(1))
	var definition := load("res://data/music/title_theme_v1.tres") as ArenicTitleMusicDefinition
	check(definition != null and definition.validation_errors().is_empty(), "Shipping definition is valid")
	check(absf(definition.stream.get_length() - 298.92) < 0.15, "Supplied song retains its full duration")
	var source_loop: bool = definition.stream.loop
	var candidate := definition.duplicate() as ArenicTitleMusicDefinition
	candidate.stream = null
	check(not candidate.validation_errors().is_empty(), "Enabled music requires a stream")
	candidate.enabled = false
	check(candidate.validation_errors().is_empty(), "Disabled music may have no track")
	for gain: float in [NAN, INF, -61.0, 1.0]:
		candidate.gain_db = gain
		check(not candidate.validation_errors().is_empty(), "Invalid gain is rejected")
	candidate.gain_db = -12.0
	for fade: float in [NAN, INF, -0.1, 5.1]:
		candidate.fade_in_seconds = fade
		check(not candidate.validation_errors().is_empty(), "Invalid fade is rejected")
	var packed := load("res://scenes/title/title_scene.tscn") as PackedScene
	var title := packed.instantiate()
	root.add_child(title)
	await process_frame
	var music := title.get_node("TitleMusic") as ArenicTitleMusic
	check(music.definition == definition, "Title selects its external definition")
	check(music.playing and music.max_polyphony == 1, "Native title starts one voice")
	check(music.playback_type == AudioServer.PLAYBACK_TYPE_STREAM, "Music uses streaming playback")
	check(music.stream != definition.stream, "Playback cannot mutate the imported source")
	await create_timer(definition.fade_in_seconds + 0.1).timeout
	check(is_equal_approx(music.volume_db, definition.gain_db), "Fade reaches configured gain")
	# Replacement can be applied by a future settings interface without scene edits.
	candidate = definition.duplicate() as ArenicTitleMusicDefinition
	candidate.stream = load("res://assets/music/guild_house_v3.mp3") as AudioStreamMP3
	candidate.gain_db = -18.0
	candidate.fade_in_seconds = 0.0
	candidate.loop = false
	music.configure(candidate)
	check(music.playing and is_equal_approx(music.volume_db, -18.0), "Replacement applies immediately")
	check(is_equal_approx(music.stream.get_length(), candidate.stream.get_length()), "Replacement chooses its own track")
	check(not (music.stream as AudioStreamMP3).loop and candidate.stream.loop, "Loop override leaves shared track untouched")
	music.play(music.stream.get_length() - 0.05)
	await create_timer(0.25).timeout
	check(not music.playing, "Non-looping replacement ends naturally")
	candidate.loop = true
	music.configure(candidate)
	music.play(music.stream.get_length() - 0.05)
	await create_timer(0.25).timeout
	check(music.playing and music.get_playback_position() < 1.0, "Looping replacement wraps to the beginning")
	candidate.enabled = false
	music.configure(candidate)
	check(not music.playing and music.stream == null, "Disable releases the voice")
	music.configure(definition)
	check(music.playing, "Original definition can be restored")
	root.remove_child(title)
	check(not music.playing and music.stream == null, "Leaving title retires audio even during fade")
	title.free()
	await process_frame
	title = packed.instantiate()
	root.add_child(title)
	music = title.get_node("TitleMusic") as ArenicTitleMusic
	check(music.playing and music.get_playback_position() < 1.0, "Returning to title starts one fresh voice")
	music.configure(null)
	check(not music.playing and music.stream == null, "Clearing the configuration stops playback")
	title.free()
	check(definition.stream.loop == source_loop, "Source import settings remain unchanged")
	check(await RETIRE_AUDIO.wait_for_mixer(self), "Audio retires before process exit")
	print("Title music checks: %d assertions, %s." % [checks, "FAILED" if failed else "passed"])
	quit(1 if failed else 0)
