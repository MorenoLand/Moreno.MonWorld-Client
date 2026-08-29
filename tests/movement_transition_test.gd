extends SceneTree

const MAP_CANVAS: GDScript = preload("res://scripts/content/map_play_canvas.gd")

class FakeContent extends RefCounted:
	func default_spawn(_map_id: String) -> Dictionary:
		return {"ok": true, "x": 1, "y": 1, "elevation": 3}

	func render_facing_object_sprite(_graphics_id: int, _facing: int, _moving: bool, _frame: int) -> Dictionary:
		return {"ok": false}

	func movement_result(map_id: String, x: int, y: int, direction: int, elevation: int = 3, _occupied: Array = []) -> Dictionary:
		var vector := Vector2i.DOWN if direction == 1 else Vector2i.UP if direction == 2 else Vector2i.LEFT if direction == 3 else Vector2i.RIGHT
		return {"ok": true, "map_id": map_id, "x": x + vector.x, "y": y + vector.y, "elevation": elevation, "jump": false, "stair": false, "door": false, "warp": {}}

func _init() -> void:
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var texture := ImageTexture.create_from_image(image)
	var view = MAP_CANVAS.new()
	view.set_content(FakeContent.new())
	view.set_map(texture, 4, 4, [], "outside")
	view.set_authoritative_state(true)
	view.set_transition_active(true)
	if view.request_move("down"):
		push_error("movement was allowed during a map transition")
		quit(1)
		return
	view.set_transition_active(false)
	if not view.request_move("down") or not view.movement_active:
		push_error("movement did not resume after a map transition")
		quit(1)
		return
	view._reset_movement_state(true)
	view.has_spawn = true
	view.player_position = Vector2i(2, 2)
	view.regions.append({"map_id": "inside", "origin": Vector2i.ZERO, "width": 4, "height": 4, "background_texture": texture, "foreground_texture": null, "objects": [], "ready": true})
	view.region_origins["inside"] = Vector2i.ZERO
	if not view.set_active_map("inside") or view.has_spawn:
		push_error("map handoff retained the old authoritative spawn")
		quit(1)
		return
	view.free()
	quit(0)
