extends Control

signal character_selected
signal logout_requested

var card_grid: GridContainer
var status_label: Label
var play_buttons: Array[Button] = []
var selecting: bool = false
var warmed_map_ids: Dictionary = {}

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process_unhandled_input(true)
	GameState.characters_changed.connect(_on_characters_changed)
	GameState.connection_error.connect(_on_connection_error)
	_build_ui()
	_on_characters_changed(GameState.characters)

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("0b111b")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var glow := ColorRect.new()
	glow.color = Color("172842")
	glow.anchor_right = 1.0
	glow.offset_bottom = 220.0
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow)
	move_child(glow, 1)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(680, 0)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("151d29"), Color("334760"), 14, 1))
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)
	var title := Label.new()
	title.text = "Character Selection"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("f4f7fb"))
	box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Choose a character to enter the world."
	subtitle.add_theme_color_override("font_color", Color("aebbd0"))
	box.add_child(subtitle)
	var separator := HSeparator.new()
	separator.add_theme_color_override("separator", Color("2a384b"))
	box.add_child(separator)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 278)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	card_grid = GridContainer.new()
	card_grid.columns = 2
	card_grid.add_theme_constant_override("h_separation", 12)
	card_grid.add_theme_constant_override("v_separation", 12)
	card_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(card_grid)
	status_label = Label.new()
	status_label.custom_minimum_size = Vector2(0, 30)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", Color("b8c7d9"))
	box.add_child(status_label)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	actions.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(actions)
	var new_button := Button.new()
	new_button.text = "NEW CHARACTER"
	new_button.tooltip_text = "Character creation is not exposed by the current OpenMMO server protocol."
	new_button.disabled = true
	_style_button(new_button)
	actions.add_child(new_button)
	var delete_button := Button.new()
	delete_button.text = "DELETE CHARACTER"
	delete_button.tooltip_text = "Character deletion is not exposed by the current OpenMMO server protocol."
	delete_button.disabled = true
	_style_button(delete_button)
	actions.add_child(delete_button)
	var logout_button := Button.new()
	logout_button.text = "LOGOUT"
	logout_button.pressed.connect(_logout)
	_style_button(logout_button, true)
	actions.add_child(logout_button)

func _on_characters_changed(value: Array) -> void:
	if card_grid == null:
		return
	for child in card_grid.get_children():
		child.queue_free()
	play_buttons.clear()
	if value.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No characters are available on this account."
		empty_label.add_theme_color_override("font_color", Color("aebbd0"))
		card_grid.add_child(empty_label)
		status_label.text = "This server does not currently expose character creation."
		return
	status_label.text = "Select a character to continue."
	for character_value in value:
		if character_value is Dictionary:
			_add_character_card(character_value as Dictionary)
	call_deferred("_warm_character_maps", value.duplicate())

func _warm_character_maps(values: Array) -> void:
	if GameState.content == null:
		return
	for character_value in values:
		if not character_value is Dictionary:
			continue
		var character: Dictionary = character_value
		var map_id: String = GameState.content.map_id_for_location(int(character.get("bank_id", -1)), int(character.get("map_id", -1)))
		if map_id.is_empty() or warmed_map_ids.has(map_id):
			continue
		warmed_map_ids[map_id] = true
		await get_tree().process_frame
		if selecting or GameState.content == null:
			return
		GameState.content.prepare_map(map_id, false)

func _add_character_card(character: Dictionary) -> void:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(316, 250)
	card.add_theme_stylebox_override("panel", _panel_style(Color("1b2635"), Color("405873"), 10, 1))
	card_grid.add_child(card)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	card.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	box.add_child(top)
	var avatar := TextureRect.new()
	avatar.custom_minimum_size = Vector2(92, 116)
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	avatar.texture = _character_texture()
	top.add_child(avatar)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 4)
	top.add_child(details)
	var name_label := Label.new()
	name_label.text = str(character.get("name", "Character"))
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", Color("f4f7fb"))
	details.add_child(name_label)
	var location_label := Label.new()
	location_label.text = _location_text(character)
	location_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	location_label.add_theme_color_override("font_color", Color("aebbd0"))
	details.add_child(location_label)
	var money_label := Label.new()
	money_label.text = "$%s" % _format_money(int(character.get("money", 0)))
	money_label.add_theme_color_override("font_color", Color("89d6a3"))
	details.add_child(money_label)
	var guild_name := str(character.get("guild_name", ""))
	if not guild_name.is_empty():
		var guild_label := Label.new()
		guild_label.text = guild_name
		guild_label.add_theme_color_override("font_color", Color("d8b4ff"))
		details.add_child(guild_label)
	var party_title := Label.new()
	party_title.text = "PARTY"
	party_title.add_theme_font_size_override("font_size", 12)
	party_title.add_theme_color_override("font_color", Color("91a0b5"))
	box.add_child(party_title)
	var party_box := HBoxContainer.new()
	party_box.add_theme_constant_override("separation", 5)
	box.add_child(party_box)
	var party: Array = character.get("party", [])
	for index in range(6):
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(42, 42)
		slot.add_theme_stylebox_override("panel", _panel_style(Color("101923"), Color("334760"), 5, 1))
		var slot_label := Label.new()
		slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot_label.add_theme_font_size_override("font_size", 10)
		slot_label.text = _party_slot_text(party[index]) if index < party.size() and party[index] is Dictionary else ""
		slot.add_child(slot_label)
		party_box.add_child(slot)
	var play_button := Button.new()
	play_button.text = "PLAY"
	play_button.pressed.connect(_select_character.bind(int(character.get("id", 0))))
	_style_button(play_button, true)
	box.add_child(play_button)
	play_buttons.append(play_button)

func _character_texture() -> Texture2D:
	if GameState.content == null:
		return null
	var sprite: Dictionary = GameState.content.render_facing_object_sprite(19, 1, false, 0)
	return sprite.get("texture") as Texture2D

func _location_text(character: Dictionary) -> String:
	if GameState.content == null:
		return "Kanto"
	var local_id: String = GameState.content.map_id_for_location(int(character.get("bank_id", -1)), int(character.get("map_id", -1)))
	if local_id.is_empty():
		return "Kanto"
	var map_value: Dictionary = GameState.content.map_data(local_id)
	return str(map_value.get("name", local_id))

func _party_slot_text(member: Dictionary) -> String:
	var nickname := str(member.get("nickname", ""))
	if nickname.is_empty():
		nickname = "#%03d" % int(member.get("dex_id", 0))
	return "%s\nLv %d" % [nickname.left(7), int(member.get("level", 0))]

func _select_character(character_id: int) -> void:
	if selecting:
		return
	if not GameState.select_character(character_id):
		status_label.text = "The character could not be selected."
		status_label.modulate = Color("ff9a9a")
		return
	selecting = true
	for button in play_buttons:
		button.disabled = true
	status_label.modulate = Color("b8c7d9")
	status_label.text = "Entering the world…"
	character_selected.emit()

func _logout() -> void:
	GameState.disconnect_game()
	GameState.current_character.clear()
	selecting = false
	logout_requested.emit()

func _on_connection_error(message: String) -> void:
	selecting = false
	for button in play_buttons:
		button.disabled = false
	if status_label != null:
		status_label.modulate = Color("ff9a9a")
		status_label.text = message

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_logout()
	elif key_event.keycode == KEY_ENTER and play_buttons.size() == 1:
		get_viewport().set_input_as_handled()
		play_buttons[0].pressed.emit()

func _panel_style(background: Color, border: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 10.0
	style.content_margin_top = 8.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 8.0
	return style

func _style_button(button: Button, accent: bool = false) -> void:
	button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, 40.0)
	var normal_color := Color("567cff") if accent else Color("202c3c")
	var hover_color := Color("668cff") if accent else Color("2a394d")
	var pressed_color := Color("4569e5") if accent else Color("182331")
	button.add_theme_stylebox_override("normal", _panel_style(normal_color, normal_color, 8, 0))
	button.add_theme_stylebox_override("hover", _panel_style(hover_color, hover_color, 8, 0))
	button.add_theme_stylebox_override("pressed", _panel_style(pressed_color, pressed_color, 8, 0))
	button.add_theme_stylebox_override("disabled", _panel_style(Color("18212d"), Color("18212d"), 8, 0))
	button.add_theme_color_override("font_color", Color("ffffff"))
	button.add_theme_color_override("font_disabled_color", Color("657286"))

func _format_money(value: int) -> String:
	var negative := value < 0
	var digits := str(absi(value))
	var formatted := ""
	while digits.length() > 3:
		formatted = "," + digits.substr(digits.length() - 3) + formatted
		digits = digits.substr(0, digits.length() - 3)
	formatted = digits + formatted
	return "-" + formatted if negative else formatted
