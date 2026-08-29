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
			if not _has_tree_corner_filler(world, gap.get("origin", Vector2i.ZERO), gap.get("size", Vector2i.ZERO)):
				push_error("missing corner filler for %s at %s size %s" % [str(test_case.get("root", "")), str(gap.get("origin", Vector2i.ZERO)), str(gap.get("size", Vector2i.ZERO))])
				quit(1)
				return
	var streaming_world: Dictionary = content.prepare_connected_world("rom-map-3-25", 96, 2, {})
	if not bool(streaming_world.get("ok", false)) or not _has_ready_region(streaming_world, "rom-map-3-34"):
		push_error("two-hop connected-world preload did not prepare Route 16 from east Celadon")
		quit(1)
		return
	print("corner filler regression passed")
	quit(0)

func _has_tree_corner_filler(world: Dictionary, origin: Vector2i, size: Vector2i) -> bool:
	for region_value in world.get("regions", []):
		if not region_value is Dictionary:
			continue
		var region: Dictionary = region_value
		if not bool(region.get("corner_filler", false)):
			continue
		var region_origin: Vector2i = region.get("origin", Vector2i.ZERO)
		var region_size := Vector2i(int(region.get("width", 0)), int(region.get("height", 0)))
		if region_origin == origin and region_size == size:
			var texture: Texture2D = region.get("background_texture")
			if texture == null:
				return false
			var image: Image = texture.get_image()
			for y in range(0, image.get_height(), 8):
				for x in range(0, image.get_width(), 8):
					var color: Color = image.get_pixel(x, y)
					if color.g > color.r * 1.1 and color.g > color.b * 1.1:
						return true
			return false
	return false

func _has_ready_region(world: Dictionary, map_id: String) -> bool:
	for region_value in world.get("regions", []):
		if region_value is Dictionary and str(region_value.get("map_id", "")) == map_id and bool(region_value.get("ready", false)) and region_value.get("background_texture") is Texture2D:
			return true
	return false
