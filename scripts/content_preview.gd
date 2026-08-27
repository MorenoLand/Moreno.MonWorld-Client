extends Control

signal exit_requested

var content: MonWorldContent
var selected_map_id: String = ""
var map_title: Label
var map_details: Label
var map_status: Label
var map_view: TextureRect

func _ready() -> void:
	if content == null:
		var rom_path: String = OS.get_environment("MONWORLD_ROM")
		if not rom_path.is_empty():
			var local_result: Dictionary = MonWorldContent.from_rom_path(rom_path)
			if bool(local_result.get("ok", false)):
				content = local_result.get("content") as MonWorldContent
	_build_ui()
	if content == null:
		return
	var maps: Array = content.manifest.get("maps", [])
	if not maps.is_empty() and maps[0] is Dictionary:
		_select_map(str(maps[0].get("id", "")))

func _build_ui() -> void:
	var background: ColorRect = ColorRect.new()
	background.color = Color("101721")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	move_child(background, 0)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 22)
	add_child(margin)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	var title: Label = Label.new()
	title.text = "ROM-backed Kanto map preview"
	title.add_theme_font_size_override("font_size", 30)
	box.add_child(title)
	var subtitle: Label = Label.new()
	subtitle.text = "Rendered directly from the selected FireRed ROM; no account or server connection is used."
	subtitle.modulate = Color("b8c7d9")
	box.add_child(subtitle)
	var metadata: Label = Label.new()
	metadata.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	metadata.text = _metadata_text()
	metadata.modulate = Color("d7e0eb")
	box.add_child(metadata)
	var map_controls: HBoxContainer = HBoxContainer.new()
	map_controls.add_theme_constant_override("separation", 8)
	var maps: Array = content.manifest.get("maps", []) if content != null else []
	for map_value in maps:
		if not map_value is Dictionary:
			continue
		var map_dictionary: Dictionary = map_value
		var button: Button = Button.new()
		button.text = str(map_dictionary.get("name", map_dictionary.get("id", "Map")))
		button.pressed.connect(_select_map.bind(str(map_dictionary.get("id", ""))))
		map_controls.add_child(button)
	box.add_child(map_controls)
	map_title = Label.new()
	map_title.add_theme_font_size_override("font_size", 23)
	box.add_child(map_title)
	map_details = Label.new()
	map_details.modulate = Color("b8c7d9")
	box.add_child(map_details)
	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(panel)
	map_view = TextureRect.new()
	map_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	map_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_view.custom_minimum_size = Vector2(0, 260)
	panel.add_child(map_view)
	map_status = Label.new()
	map_status.modulate = Color("b8c7d9")
	box.add_child(map_status)
	var footer: HBoxContainer = HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	var back_button: Button = Button.new()
	back_button.text = "Back to login"
	back_button.pressed.connect(func() -> void: exit_requested.emit())
	footer.add_child(back_button)
	box.add_child(footer)

func _metadata_text() -> String:
	if content == null:
		return "No local ROM is loaded."
	var source: Dictionary = content.manifest.get("source", {})
	var header: Dictionary = content.rom_header
	return "%s %s  •  %s  •  %s  •  %s\nSHA-1: %s  •  Content ID: %s" % [str(source.get("game", "Unknown")), str(source.get("revision", "")), str(header.get("title", "Unknown")), str(header.get("game_code", "Unknown")), str(header.get("maker_code", "Unknown")), content.rom_sha1, content.content_id()]

func _select_map(map_id: String) -> void:
	if content == null:
		return
	var map_value: Dictionary = content.map_data(map_id)
	if map_value.is_empty():
		return
	selected_map_id = map_id
	map_title.text = str(map_value.get("name", map_id))
	map_details.text = "Loading ROM tiles..."
	map_status.text = ""
	map_view.texture = null
	var result: Dictionary = content.render_map(map_id)
	if not bool(result.get("ok", false)):
		map_details.text = "%d × %d map cells" % [int(map_value.get("width", 0)), int(map_value.get("height", 0))]
		map_status.text = str(result.get("error", "Map rendering failed"))
		return
	var texture: Texture2D = result.get("texture") as Texture2D
	map_view.texture = texture
	map_details.text = "%d × %d map cells  •  actual 16×16 metatiles" % [int(result.get("width", 0)), int(result.get("height", 0))]
	map_status.text = "Rendered from the selected ROM in memory."
