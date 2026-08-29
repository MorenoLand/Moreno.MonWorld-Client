extends Node

const MAP_PLAY_CANVAS_SCRIPT = preload("res://scripts/content/map_play_canvas.gd")

class FakeSession extends Node:
	var sent_packets: int = 0

	func send_packet(_opcode: int, _payload: PackedByteArray = PackedByteArray()) -> bool:
		sent_packets += 1
		return true

class FakeContent extends RefCounted:
	var map_cache: Dictionary = {}

	func map_data(_map_id: String) -> Dictionary:
		return {"width": 4, "height": 4}

	func default_spawn(_map_id: String) -> Dictionary:
		return {"x": 1, "y": 1, "elevation": 0, "facing": 1, "ok": true}

	func movement_result(_map_id: String, _x: int, _y: int, _direction: int, _elevation: int, _occupied: Array) -> Dictionary:
		return {"ok": false, "error": "blocked"}

	func render_facing_object_sprite(_graphics_id: int, _facing: int, _walking: bool, _frame_step: int) -> Dictionary:
		return {}

func _ready() -> void:
	var game_state = get_node("/root/GameState")
	var previous_session: Node = game_state.game_session
	var session := FakeSession.new()
	game_state.game_session = session
	game_state.map_transition_pending = false
	var view = MAP_PLAY_CANVAS_SCRIPT.new()
	add_child(view)
	view.set_content(FakeContent.new())
	view.set_map(ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8)), 4, 4, [], "inside")
	view.set_authoritative_state(true)
	view.set_player_state(1, 1, 0, 1)
	if not view.request_move("right") or not view.movement_active or not view.movement_unvalidated:
		_fail("same-map movement fallback did not start")
		return
	view._process(view.movement_duration + 0.001)
	if view.movement_active or view.player_position != Vector2i(2, 1):
		_fail("same-map movement fallback did not complete")
		return
	view.set_player_state(1, 1, 0, 1)
	if not view.request_move("right"):
		_fail("reset test movement did not start")
		return
	view.apply_server_position(1, 1, 0, 1)
	if view.movement_active or view.movement_unvalidated or view.player_position != Vector2i(1, 1):
		_fail("server position reset did not cancel movement")
		return
	if session.sent_packets != 2:
		_fail("unexpected movement packet count")
		return
	view.free()
	game_state.game_session = previous_session
	session.free()
	print("authoritative movement test passed")
	get_tree().quit(0)

func _fail(message: String) -> void:
	printerr(message)
	get_tree().quit(1)
