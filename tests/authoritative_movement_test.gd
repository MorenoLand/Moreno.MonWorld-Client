extends Node

const MAP_PLAY_CANVAS_SCRIPT = preload("res://scripts/content/map_play_canvas.gd")

class FakeSession extends Node:
	var sent_packets: int = 0

	func send_packet(_opcode: int, _payload: PackedByteArray = PackedByteArray()) -> bool:
		sent_packets += 1
		return true

class FakeContent extends RefCounted:
	var map_cache: Dictionary = {}
	var sprite_calls: Array = []
	var sprite_texture: ImageTexture = ImageTexture.create_from_image(Image.create(16, 32, false, Image.FORMAT_RGBA8))

	func map_data(_map_id: String) -> Dictionary:
		return {"width": 4, "height": 4}

	func default_spawn(_map_id: String) -> Dictionary:
		return {"x": 1, "y": 1, "elevation": 0, "facing": 1, "ok": true}

	func movement_result(_map_id: String, _x: int, _y: int, _direction: int, _elevation: int, _occupied: Array) -> Dictionary:
		return {"ok": false, "error": "blocked"}

	func render_facing_object_sprite(_graphics_id: int, _facing: int, walking: bool, frame_step: int) -> Dictionary:
		sprite_calls.append({"walking": walking, "frame": frame_step})
		return {"ok": true, "texture": sprite_texture, "width": 16, "height": 32}

func _ready() -> void:
	var game_state = get_node("/root/GameState")
	var previous_session: Node = game_state.game_session
	var session := FakeSession.new()
	game_state.game_session = session
	game_state.map_transition_pending = false
	var view = MAP_PLAY_CANVAS_SCRIPT.new()
	add_child(view)
	var content := FakeContent.new()
	view.set_content(content)
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
	var npc: Dictionary = {"entity_id": 7004, "npc": true, "map_id": "inside", "x": 1, "y": 1, "facing": 1, "graphics_id": 19}
	view.set_world_entities([npc], -1)
	view.queue_scripted_movement(7004, PackedByteArray([0x13, 0x13]))
	view.call("_process_world_entity_movements", 0.13)
	var entity: Dictionary = view.world_entities[0]
	if int(entity.get("movement_frame", -1)) != 2 or view.call("_world_entity_render_position", entity).x <= 1.0:
		_fail("scripted NPC did not interpolate with an animated walking frame")
		return
	view.call("_process_world_entity_movements", 0.13)
	view.set_world_entities([npc], -1)
	entity = view.world_entities[0]
	if int(entity.get("x", 0)) != 2 or not bool(entity.get("movement_active", false)):
		_fail("stale entity refresh reset an active scripted path")
		return
	view.call("_process_world_entity_movements", 0.26)
	view.set_world_entities([npc], -1)
	entity = view.world_entities[0]
	if int(entity.get("x", 0)) != 3 or not bool(entity.get("movement_scripted", false)):
		_fail("stale entity refresh reset the completed scripted endpoint")
		return
	npc["x"] = 3
	view.set_world_entities([npc], -1)
	entity = view.world_entities[0]
	if bool(entity.get("movement_scripted", false)):
		_fail("authoritative scripted endpoint did not release local reconciliation")
		return
	if not content.sprite_calls.any(func(call: Dictionary) -> bool: return bool(call.get("walking", false)) and int(call.get("frame", -1)) == 2):
		_fail("scripted NPC never selected the ROM walking frame")
		return
	view.free()
	game_state.game_session = previous_session
	session.free()
	print("authoritative movement test passed")
	get_tree().quit(0)

func _fail(message: String) -> void:
	printerr(message)
	get_tree().quit(1)
