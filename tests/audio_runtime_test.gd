extends Node

var audio: MonWorldAudio
var elapsed: float = 0.0
var started_at: int = 0
var max_frame_msec: float = 0.0
var playback_started_at: int = 0
var playback_elapsed: float = 0.0
var playback_max_frame_msec: float = 0.0

func _ready() -> void:
	var path: String = OS.get_environment("MONWORLD_ROM")
	if path.is_empty():
		get_tree().quit(0)
		return
	var result: Dictionary = MonWorldContent.from_rom_path(path)
	if not bool(result.get("ok", false)):
		push_error(str(result.get("error", "content load failed")))
		get_tree().quit(1)
		return
	var content: MonWorldContent = result.get("content") as MonWorldContent
	audio = MonWorldAudio.new()
	add_child(audio)
	started_at = Time.get_ticks_msec()
	audio.play_map_music(content, "pallet-town")

func _process(delta: float) -> void:
	if audio == null:
		return
	elapsed += delta
	max_frame_msec = maxf(max_frame_msec, delta * 1000.0)
	if audio.music_player.playing and playback_started_at == 0:
		playback_started_at = Time.get_ticks_msec()
		print("ROM map music ready in %d ms; startup_max_frame=%.2f ms" % [playback_started_at - started_at, max_frame_msec])
	if playback_started_at > 0:
		playback_elapsed += delta
		playback_max_frame_msec = maxf(playback_max_frame_msec, delta * 1000.0)
	if playback_elapsed >= 3.0:
		var skips: int = audio.music_playback.get_skips() if audio.music_playback != null else -1
		print("ROM map music sustained for 3 seconds; skips=%d; playback_max_frame=%.2f ms" % [skips, playback_max_frame_msec])
		audio.stop_music()
		get_tree().quit(0 if skips == 0 else 1)
		return
	if elapsed >= 15.0:
		var thread_started: bool = audio.music_render_thread != null and audio.music_render_thread.is_started()
		var thread_alive: bool = thread_started and audio.music_render_thread.is_alive()
		push_error("ROM map music did not start: thread_started=%s thread_alive=%s rendering=%s requested=%s queued=%s cache=%d" % [thread_started, thread_alive, audio.rendering_music_key, audio.requested_music_key, audio.queued_music_key, audio.music_cache.size()])
		get_tree().quit(1)
