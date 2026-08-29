extends SceneTree

const CONTENT_SCRIPT: GDScript = preload("res://scripts/content/content.gd")

func _map_cache(width: int, height: int, blocked_index: int = -1) -> Dictionary:
	var map_cells: PackedInt32Array = PackedInt32Array()
	for index in range(width * height):
		map_cells.append(0x400 if index == blocked_index else 0)
	return {"ok": true, "width": width, "height": height, "map_cells": map_cells, "objects": [], "warps": [], "connections": []}

func _init() -> void:
	var content = CONTENT_SCRIPT.new()
	content.map_cache["server-map-indoor"] = _map_cache(3, 3)
	var movement: Dictionary = content.movement_result("server-map-indoor", 1, 1, 4, 0)
	if not bool(movement.get("ok", false)) or int(movement.get("x", -1)) != 2 or int(movement.get("y", -1)) != 1:
		push_error("cached server map movement was not accepted")
		quit(1)
		return
	content.map_cache["server-map-blocked"] = _map_cache(3, 3, 5)
	var blocked: Dictionary = content.movement_result("server-map-blocked", 1, 1, 4, 0)
	if bool(blocked.get("ok", false)) or str(blocked.get("error", "")) != "blocked":
		push_error("cached server map collision was not enforced")
		quit(1)
		return
	quit(0)
