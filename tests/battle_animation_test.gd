extends SceneTree

func _init() -> void:
	var data := PackedByteArray()
	data.resize(0x3300)
	var picture_table: int = 0x1000
	var palette_table: int = picture_table + 289 * 8
	var move_table: int = 0x2300
	var pixel_data: int = 0x3000
	var palette_data: int = 0x3100
	var script_data: int = 0x3200
	_write_u32(data, picture_table, 0x08000000 + pixel_data)
	_write_u16(data, picture_table + 4, 32)
	_write_u16(data, picture_table + 6, 10000)
	_write_u32(data, palette_table, 0x08000000 + palette_data)
	_write_u16(data, palette_table + 4, 10000)
	_write_u32(data, move_table + 52 * 4, 0x08000000 + script_data)
	for index in range(32):
		data[pixel_data + index] = 0x11
	_write_u16(data, palette_data + 2, 0x001F)
	var script := PackedByteArray([0x00, 0x10, 0x27, 0x02, 0x00, 0x00, 0x00, 0x08, 0x80, 0x02, 0x00, 0x00, 0x00, 0x00, 0x04, 0x06, 0x08])
	for index in range(script.size()):
		data[script_data + index] = script[index]
	var content := OpenMMOContent.new()
	content.rom_data = data
	content.battle_tables_scanned = true
	content.battle_table_cache = {"animation_pic_table": picture_table, "animation_palette_table": palette_table, "animation_move_table": move_table}
	content.battle_move_info_cache["52"] = {"id": 52, "name": "EMBER", "type": 10, "power": 40}
	var plan: Dictionary = content.battle_move_animation_plan(52)
	if not bool(plan.get("ok", false)) or (plan.get("spawns", []) as Array).size() != 1 or int((plan.get("spawns", []) as Array)[0].get("tag", 0)) != 10000:
		push_error("battle animation script plan did not preserve the ROM sprite tag")
		quit(1)
		return
	var sheet: Dictionary = content.battle_animation_sheet(10000)
	var frames: Array = sheet.get("frames", [])
	if not bool(sheet.get("ok", false)) or frames.size() != 1:
		push_error("battle animation sheet did not decode")
		quit(1)
		return
	var image: Image = (frames[0] as Texture2D).get_image()
	if image.get_width() != 8 or image.get_height() != 8 or image.get_pixel(0, 0).r < 0.9:
		push_error("battle animation 4bpp pixels or palette were decoded incorrectly")
		quit(1)
		return
	quit(0)

func _write_u16(data: PackedByteArray, offset: int, value: int) -> void:
	data[offset] = value & 0xFF
	data[offset + 1] = (value >> 8) & 0xFF

func _write_u32(data: PackedByteArray, offset: int, value: int) -> void:
	data[offset] = value & 0xFF
	data[offset + 1] = (value >> 8) & 0xFF
	data[offset + 2] = (value >> 16) & 0xFF
	data[offset + 3] = (value >> 24) & 0xFF
