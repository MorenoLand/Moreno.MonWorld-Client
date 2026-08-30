extends SceneTree

const WORLD_SCRIPT: GDScript = preload("res://scripts/world/world.gd")

func _init() -> void:
	var world: Control = WORLD_SCRIPT.new()
	var npc: Dictionary = {"entity_id": 7004, "npc": true, "map_id": "pallet-oaks-lab", "x": 8, "y": 4}
	world.call("_on_entity_update", {"player": npc, "spawn": true, "map_load_spawn": true})
	if not (world.get("entities") as Dictionary).has("7004"):
		push_error("initial authoritative NPC spawn was discarded")
		quit(1)
		return
	world.call("_on_entity_update", {"remove_entity_id": 7004})
	world.call("_on_entity_update", {"player": npc, "spawn": true, "map_load_spawn": true})
	if (world.get("entities") as Dictionary).has("7004"):
		push_error("removed story NPC respawned during map reload")
		quit(1)
		return
	world.call("_on_entity_update", {"player": npc, "spawn": true, "map_load_spawn": false})
	if not (world.get("entities") as Dictionary).has("7004"):
		push_error("explicit scripted NPC re-add was discarded")
		quit(1)
		return
	world.free()
	quit(0)
