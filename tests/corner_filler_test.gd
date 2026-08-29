extends SceneTree

const CONTENT_SCRIPT: GDScript = preload("res://scripts/content/content.gd")

func _init() -> void:
	var rom_path: String = OS.get_environment("MONWORLD_ROM")
	if rom_path.is_empty():
		quit(0)
		return
	var loaded: Dictionary = CONTENT_SCRIPT.from_rom_path(rom_path)
	if not bool(loaded.get("ok", false)):
		push_error("failed to load regression ROM: %s" % str(loaded.get("error", "unknown error")))
		quit(1)
		return
	var content = loaded.get("content")
	var cases: Array = [
		{"root": "rom-map-3-6", "gaps": [{"origin": Vector2i(-48, 0), "size": Vector2i(48, 10)}, {"origin": Vector2i(-24, 30), "size": Vector2i(24, 10)}]},
		{"root": "rom-map-3-34", "gaps": [{"origin": Vector2i(0, -10), "size": Vector2i(48, 10)}, {"origin": Vector2i(24, 20), "size": Vector2i(24, 10)}]}
	]
	for case_value in cases:
		var test_case: Dictionary = case_value
		var world: Dictionary = content.prepare_connected_world(str(test_case.get("root", "")), 96, 1, {})
		if not bool(world.get("ok", false)):
			push_error("failed to assemble %s: %s" % [str(test_case.get("root", "")), str(world.get("error", "unknown error"))])
			quit(1)
			return
		for gap_value in test_case.get("gaps", []):
			var gap: Dictionary = gap_value
			if not _has_corner_filler(world, gap.get("origin", Vector2i.ZERO), gap.get("size", Vector2i.ZERO)):
				push_error("missing corner filler for %s at %s size %s" % [str(test_case.get("root", "")), str(gap.get("origin", Vector2i.ZERO)), str(gap.get("size", Vector2i.ZERO))])
				quit(1)
				return
	print("corner filler regression passed")
	quit(0)

func _has_corner_filler(world: Dictionary, origin: Vector2i, size: Vector2i) -> bool:
	for region_value in world.get("regions", []):
		if not region_value is Dictionary:
			continue
		var region: Dictionary = region_value
		if not bool(region.get("corner_filler", false)):
			continue
		var region_origin: Vector2i = region.get("origin", Vector2i.ZERO)
		var region_size := Vector2i(int(region.get("width", 0)), int(region.get("height", 0)))
		if region_origin == origin and region_size == size:
			return true
	return false
