extends Control

signal battle_requested

var title_label: Label
var status_label: Label
var character_box: VBoxContainer
var create_name_input: LineEdit
var chat_log: RichTextLabel
var chat_input: LineEdit
var snapshot: Dictionary = {}
var entities: Dictionary = {}
var selected_character_id := 0
var map_rect := Rect2()

func _ready() -> void:
	set_process_unhandled_input(true)
	GameState.characters_changed.connect(_on_characters_changed)
	GameState.world_snapshot_received.connect(_on_world_snapshot)
	GameState.entity_update_received.connect(_on_entity_update)
	GameState.chat_received.connect(_on_chat)
	GameState.connection_error.connect(_on_connection_error)
	_build_ui()
	_on_characters_changed(GameState.characters)
	queue_redraw()

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("101721")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	move_child(background, 0)
	title_label = Label.new()
	title_label.position = Vector2(24, 18)
	title_label.add_theme_font_size_override("font_size", 22)
	add_child(title_label)
	status_label = Label.new()
	status_label.position = Vector2(24, 47)
	add_child(status_label)
	var side := VBoxContainer.new()
	side.set_anchor(SIDE_LEFT, 1.0)
	side.set_anchor(SIDE_RIGHT, 1.0)
	side.offset_left = -320
	side.offset_right = -24
	side.offset_top = 72
	side.offset_bottom = -158
	side.add_theme_constant_override("separation", 8)
	add_child(side)
	var character_title := Label.new()
	character_title.text = "Characters"
	character_title.add_theme_font_size_override("font_size", 18)
	side.add_child(character_title)
	character_box = VBoxContainer.new()
	character_box.add_theme_constant_override("separation", 6)
	side.add_child(character_box)
	create_name_input = LineEdit.new()
	create_name_input.placeholder_text = "New character name"
	side.add_child(create_name_input)
	var create_button := Button.new()
	create_button.text = "Create character"
	create_button.pressed.connect(_create_character)
	side.add_child(create_button)
	var battle_button := Button.new()
	battle_button.text = "Open battle foundation"
	battle_button.pressed.connect(func(): battle_requested.emit())
	side.add_child(battle_button)
	chat_log = RichTextLabel.new()
	chat_log.bbcode_enabled = false
	chat_log.scroll_active = true
	chat_log.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	chat_log.offset_left = 24
	chat_log.offset_top = -142
	chat_log.offset_right = -344
	chat_log.offset_bottom = -58
	add_child(chat_log)
	chat_input = LineEdit.new()
	chat_input.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	chat_input.offset_left = 24
	chat_input.offset_top = -50
	chat_input.offset_right = -424
	chat_input.offset_bottom = -18
	chat_input.placeholder_text = "Chat"
	chat_input.text_submitted.connect(_send_chat)
	add_child(chat_input)
	var send_button := Button.new()
	send_button.text = "Send"
	send_button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	send_button.offset_left = -392
	send_button.offset_top = -50
	send_button.offset_right = -344
	send_button.offset_bottom = -18
	send_button.pressed.connect(func(): _send_chat(chat_input.text))
	add_child(send_button)
	resized.connect(_layout_ui)
	_layout_ui()

func _layout_ui() -> void:
	map_rect = Rect2(24, 78, max(320.0, size.x - 368.0), max(260.0, size.y - 246.0))
	queue_redraw()

func _draw() -> void:
	var width := int(snapshot.get("width", 32))
	var height := int(snapshot.get("height", 20))
	var tile_size := min(map_rect.size.x / max(width, 1), map_rect.size.y / max(height, 1))
	var board_size := Vector2(tile_size * width, tile_size * height)
	var board := Rect2(map_rect.position, board_size)
	draw_rect(board, Color("1b2933"), true)
	for x in range(width + 1):
		var start := board.position + Vector2(x * tile_size, 0)
		draw_line(start, start + Vector2(0, board_size.y), Color("304653"), 1.0)
	for y in range(height + 1):
		var start := board.position + Vector2(0, y * tile_size)
		draw_line(start, start + Vector2(board_size.x, 0), Color("304653"), 1.0)
	for key in entities:
		var entity: Dictionary = entities[key]
		if str(entity.get("map_id", "")) != str(snapshot.get("map_id", "")):
			continue
		var position := board.position + Vector2((int(entity.get("x", 0)) + 0.5) * tile_size, (int(entity.get("y", 0)) + 0.5) * tile_size)
		var color := Color("8fc4ff") if int(entity.get("character_id", 0)) == selected_character_id else Color("f4b86a")
		draw_circle(position, max(5.0, tile_size * 0.32), color)

func _on_characters_changed(value: Array) -> void:
	if character_box == null:
		return
	for child in character_box.get_children():
		child.queue_free()
	for character_value in value:
		if not character_value is Dictionary:
			continue
		var character: Dictionary = character_value
		var button := Button.new()
		button.text = "%s  (%s, %d, %d)" % [character.get("name", "Character"), character.get("map_id", ""), character.get("x", 0), character.get("y", 0)]
		button.pressed.connect(_select_character.bind(int(character.get("id", 0))))
		character_box.add_child(button)
	if value.is_empty():
		status_label.text = "Create a character to enter the world."

func _select_character(character_id: int) -> void:
	if GameState.select_character(character_id):
		selected_character_id = character_id
		status_label.text = "Selecting character…"

func _create_character() -> void:
	var name := create_name_input.text.strip_edges()
	if name.is_empty():
		return
	var result: Dictionary = await GameState.create_character(name)
	if result.ok:
		create_name_input.clear()
		status_label.text = "Character created. Select it to enter the map."
	else:
		status_label.text = str(result.error)

func _on_world_snapshot(value: Dictionary) -> void:
	snapshot = value
	entities.clear()
	for player_value in value.get("players", []):
		if player_value is Dictionary:
			var player: Dictionary = player_value
			entities[str(player.get("user_id", 0))] = player
	title_label.text = "Map: %s" % str(snapshot.get("map_id", "unknown"))
	status_label.text = "Authoritative movement active. Arrow keys or WASD move one tile."
	queue_redraw()

func _on_entity_update(value: Dictionary) -> void:
	var player: Variant = value.get("player")
	if player is Dictionary:
		entities[str(player.get("user_id", 0))] = player
		queue_redraw()

func _on_chat(value: Dictionary) -> void:
	chat_log.append_text("%s: %s\n" % [value.get("name", "Player"), value.get("text", "")])

func _send_chat(text: String) -> void:
	var trimmed := text.strip_edges()
	if not trimmed.is_empty() and GameState.send_chat(trimmed):
		chat_input.clear()

func _on_connection_error(message: String) -> void:
	status_label.text = message

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if get_viewport().gui_get_focus_owner() == chat_input or get_viewport().gui_get_focus_owner() == create_name_input:
		return
	var direction := ""
	match event.keycode:
		KEY_UP, KEY_W:
			direction = "up"
		KEY_DOWN, KEY_S:
			direction = "down"
		KEY_LEFT, KEY_A:
			direction = "left"
		KEY_RIGHT, KEY_D:
			direction = "right"
	if not direction.is_empty():
		GameState.send_input(direction)
