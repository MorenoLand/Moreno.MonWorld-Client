extends SceneTree

func _init() -> void:
	var invalid_data: PackedByteArray = PackedByteArray([0, 1, 2])
	var rom_result: Dictionary = MonWorldContent.from_rom_bytes(invalid_data)
	if bool(rom_result.get("ok", false)):
		push_error("invalid ROM bytes were accepted")
		quit(1)
		return
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var index: int = 0
	while index < args.size():
		var argument: String = args[index]
		if argument == "--rom" and index + 1 < args.size():
			var path: String = args[index + 1]
			var result: Dictionary = MonWorldContent.from_rom_path(path)
			if not bool(result.get("ok", false)):
				push_error(str(result.get("error", "content load failed")))
				quit(1)
				return
			var content: MonWorldContent = result.get("content") as MonWorldContent
			for expected_map in [{"id": "pallet-town", "width": 384, "height": 320}, {"id": "route-1", "width": 384, "height": 640}, {"id": "viridian-city", "width": 768, "height": 640}]:
				var render_result: Dictionary = content.render_map(str(expected_map.get("id", "")))
				if not bool(render_result.get("ok", false)):
					push_error("map render failed: %s" % str(render_result.get("error", "unknown error")))
					quit(1)
					return
				var image: Image = render_result.get("image") as Image
				if image == null or image.get_width() != int(expected_map.get("width", 0)) or image.get_height() != int(expected_map.get("height", 0)):
					push_error("map render dimensions are incorrect for %s" % str(expected_map.get("id", "")))
					quit(1)
					return
				var colors: Dictionary = {}
				for sample in [Vector2i(0, 0), Vector2i(image.get_width() / 2, image.get_height() / 2), Vector2i(image.get_width() - 1, image.get_height() - 1)]:
					colors[image.get_pixel(sample.x, sample.y).to_html(false)] = true
				if colors.size() < 2:
					push_error("map render produced no palette variation for %s" % str(expected_map.get("id", "")))
					quit(1)
					return
				var preview_path: String = OS.get_environment("MONWORLD_PREVIEW_PNG")
				if not preview_path.is_empty() and str(expected_map.get("id", "")) == "pallet-town":
					image.save_png(preview_path)
			var provider: MonWorldContentProvider = MonWorldContentProvider.new()
			provider._save_rom_path(path)
			if not provider.restore_saved_rom():
				provider._clear_saved_rom()
				push_error("saved ROM path could not be restored")
				quit(1)
				return
			provider._clear_saved_rom()
			index += 2
			continue
		index += 1
	quit(0)
