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
	var preview_phase: int = clampi(int(OS.get_environment("MONWORLD_PREVIEW_PHASE")), 0, 39)
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
		if not preview_path.is_empty() and map_id == "pallet-town":
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
	var provider: MonWorldContentProvider = MonWorldContentProvider.new()
	provider._save_rom_path(path)
	if not provider.restore_saved_rom():
		provider._clear_saved_rom()
		push_error("saved ROM path could not be restored")
		quit(1)
		return
	provider._clear_saved_rom()
	quit(0)
