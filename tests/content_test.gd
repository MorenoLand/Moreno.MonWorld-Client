extends SceneTree

func _init() -> void:
	var invalid_data: PackedByteArray = PackedByteArray([0, 1, 2])
	var rom_result: Dictionary = MonWorldContent.from_rom_bytes(invalid_data)
	if bool(rom_result.get("ok", false)):
		push_error("invalid ROM bytes were accepted")
		quit(1)
		return
	var path: String = OS.get_environment("MONWORLD_ROM")
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var index: int = 0
	while index < args.size():
		if args[index] == "--rom" and index + 1 < args.size():
			path = args[index + 1]
			index += 2
			continue
		index += 1
	if path.is_empty():
		quit(0)
		return
	var result: Dictionary = MonWorldContent.from_rom_path(path)
	if not bool(result.get("ok", false)):
		push_error(str(result.get("error", "content load failed")))
		quit(1)
		return
	var content: MonWorldContent = result.get("content") as MonWorldContent
	if (content.manifest.get("maps", []) as Array).size() < 50:
		push_error("ROM map manifest did not expose the selectable map table")
		quit(1)
		return
	for extra_map_id in ["rom-map-3-2", "rom-map-3-20", "viridian-forest", "pallet-players-house-1f", "viridian-pokemon-center-1f"]:
		var extra_result: Dictionary = content.render_map(extra_map_id)
		if not bool(extra_result.get("ok", false)):
			push_error("additional map render failed for %s: %s" % [extra_map_id, str(extra_result.get("error", "unknown error"))])
			quit(1)
			return
	var preview_phase: int = clampi(int(OS.get_environment("MONWORLD_PREVIEW_PHASE")), 0, 39)
	var preview_map: String = OS.get_environment("MONWORLD_PREVIEW_MAP")
	for expected_map in [{"id": "pallet-town", "width": 384, "height": 320}, {"id": "route-1", "width": 384, "height": 640}, {"id": "viridian-city", "width": 768, "height": 640}]:
		var map_id: String = str(expected_map.get("id", ""))
		var render_result: Dictionary = content.render_map(map_id, preview_phase)
		if not bool(render_result.get("ok", false)):
			push_error("map render failed: %s" % str(render_result.get("error", "unknown error")))
			quit(1)
			return
		var image: Image = render_result.get("image") as Image
		if image == null or image.get_width() != int(expected_map.get("width", 0)) or image.get_height() != int(expected_map.get("height", 0)):
			push_error("map render dimensions are incorrect for %s" % map_id)
			quit(1)
			return
		var colors: Dictionary = {}
		var sample_step_x: int = maxi(image.get_width() / 8, 1)
		var sample_step_y: int = maxi(image.get_height() / 8, 1)
		for sample_y in range(0, image.get_height(), sample_step_y):
			for sample_x in range(0, image.get_width(), sample_step_x):
				colors[image.get_pixel(sample_x, sample_y).to_html(false)] = true
		if colors.size() < 2:
			push_error("map render produced no palette variation for %s" % map_id)
			quit(1)
			return
		var preview_path: String = OS.get_environment("MONWORLD_PREVIEW_PNG")
		var should_save_preview: bool = map_id == "pallet-town" if preview_map.is_empty() else map_id == preview_map
		if not preview_path.is_empty() and should_save_preview:
			image.save_png(preview_path)
		if map_id == "pallet-town" and (render_result.get("objects", []) as Array).size() != 3:
			push_error("Pallet Town object events were not decoded")
			quit(1)
			return
		if map_id == "pallet-town":
			for y in image.get_height():
				for x in image.get_width():
					if image.get_pixel(x, y) == Color(1, 0, 1):
						push_error("Pallet Town contains an unmapped magenta palette pixel")
						quit(1)
						return
		if map_id == "viridian-city":
			for y in range(image.get_height()):
				for x in range(image.get_width()):
					if image.get_pixel(x, y) == Color(0, 0, 1):
						push_error("Viridian City contains a secondary palette placeholder-blue pixel")
						quit(1)
						return
	var static_result: Dictionary = content.render_map("pallet-town", 0)
	var animated_result: Dictionary = content.render_map("pallet-town", 7)
	var static_image: Image = static_result.get("image") as Image
	var animated_image: Image = animated_result.get("image") as Image
	var differing_pixels: int = 0
	for y in range(0, static_image.get_height(), 8):
		for x in range(0, static_image.get_width(), 8):
			if static_image.get_pixel(x, y) != animated_image.get_pixel(x, y):
				differing_pixels += 1
	if differing_pixels == 0:
		push_error("map animation did not change any pixels")
		quit(1)
		return
	var pallet_result: Dictionary = content.render_map("pallet-town")
	if (pallet_result.get("connections", []) as Array).size() != 2 or (pallet_result.get("warps", []) as Array).size() != 3:
		push_error("Pallet Town connections or warps were not decoded")
		quit(1)
		return
	var spawn: Dictionary = content.default_spawn("pallet-town")
	if not bool(spawn.get("ok", false)) or not bool(content.map_cell("pallet-town", int(spawn.get("x", 0)), int(spawn.get("y", 0))).get("collision", 1) == 0):
		push_error("Pallet Town did not produce a walkable spawn")
		quit(1)
		return
	var blocked_cell_found: bool = false
	var walkable_step_found: bool = false
	var jump_behavior_found: bool = false
	for map_id in ["pallet-town", "route-1", "viridian-city", "rom-map-3-20", "viridian-forest"]:
		var map_value: Dictionary = content.map_data(map_id)
		for y in range(int(map_value.get("height", 0))):
			for x in range(int(map_value.get("width", 0))):
				var cell: Dictionary = content.map_cell(map_id, x, y)
				if int(cell.get("collision", 0)) != 0:
					blocked_cell_found = true
				if int(cell.get("behavior", 0)) >= 0x38 and int(cell.get("behavior", 0)) <= 0x3B:
					jump_behavior_found = true
				if blocked_cell_found and jump_behavior_found and walkable_step_found:
					break
				for direction in [1, 2, 3, 4]:
					var movement: Dictionary = content.movement_result(map_id, x, y, direction)
					if bool(movement.get("ok", false)) and not bool(movement.get("jump", false)):
						walkable_step_found = true
						break
			if blocked_cell_found and jump_behavior_found and walkable_step_found:
				break
		if blocked_cell_found and jump_behavior_found and walkable_step_found:
			break
	if not blocked_cell_found or not walkable_step_found or not jump_behavior_found:
		push_error("ROM movement data did not expose collision, movement, and ledge behavior")
		quit(1)
		return
	var warp_result: Dictionary = content.warp_at("pallet-town", 6, 7)
	if not bool(warp_result.get("ok", false)) or str(warp_result.get("map_id", "")).is_empty():
		push_error("Pallet Town warp transition was not resolved")
		quit(1)
		return
	var provider: MonWorldContentProvider = MonWorldContentProvider.new()
	provider._save_rom_path(path)
	if not provider.restore_saved_rom():
		provider._clear_saved_rom()
		push_error("saved ROM path could not be restored")
		quit(1)
		return
	provider._clear_saved_rom()
	quit(0)
