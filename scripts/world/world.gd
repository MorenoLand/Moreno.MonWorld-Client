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
var map_view: MonWorldMapPlayCanvas
var hud: MonWorldHud
var dialogue_overlay: MonWorldDialogue
var animation_tick: int = 0
var animation_elapsed: float = 0.0
var held_input: String = ""
var held_input_elapsed: float = 0.0

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
	map_view = MonWorldMapPlayCanvas.new()
	map_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_view.set_content(GameState.content)
	map_view.set_authoritative_state(true)
	map_view.set_input_enabled(false)
	map_view.interaction_requested.connect(_on_interaction_requested)
	add_child(map_view)
	hud = MonWorldHud.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(hud)
	dialogue_overlay = MonWorldDialogue.new()
	dialogue_overlay.action_requested.connect(_on_dialogue_action)
	add_child(dialogue_overlay)
	title_label = Label.new()
	title_label.position = Vector2(24, 18)
	title_label.add_theme_font_size_override("font_size", 22)
	add_child(title_label)
	title_label.visible = false
	status_label = Label.new()
	status_label.position = Vector2(24, 47)
	add_child(status_label)
	status_label.visible = false
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
	map_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

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
	if hud != null:
		hud.set_state(GameState.content, str(snapshot.get("map_id", "")), snapshot, snapshot.get("party", []))
	_load_map_texture(str(snapshot.get("map_id", "")))
	_sync_map_entities()

func _load_map_texture(map_id: String) -> void:
	if GameState.content == null or map_id.is_empty():
		return
	var result: Dictionary = GameState.content.prepare_map(map_id)
	if not bool(result.get("ok", false)):
		status_label.text = "Map renderer: %s" % str(result.get("error", "map rendering failed"))
		return
	var background_texture: Texture2D = result.get("background_texture", result.get("texture")) as Texture2D
	var foreground_texture: Texture2D = result.get("foreground_texture") as Texture2D
	map_view.set_map(background_texture, int(result.get("width", 0)), int(result.get("height", 0)), result.get("objects", []), map_id, foreground_texture)

func _on_entity_update(value: Dictionary) -> void:
	var player: Variant = value.get("player")
	if player is Dictionary:
		entities[str(player.get("user_id", 0))] = player
		_sync_map_entities()

func _sync_map_entities() -> void:
	if map_view == null:
		return
	var players: Array = []
	for key in entities:
		var entity: Dictionary = entities[key]
		players.append(entity)
		if int(entity.get("character_id", 0)) == selected_character_id:
			map_view.set_player_state(int(entity.get("x", 0)), int(entity.get("y", 0)), int(entity.get("elevation", 3)))
	map_view.set_world_entities(players, selected_character_id)

func _process(delta: float) -> void:
	if map_view == null or snapshot.is_empty():
		return
	if not held_input.is_empty():
		held_input_elapsed += delta
		if held_input_elapsed >= MonWorldMapPlayCanvas.NORMAL_STEP_DURATION:
			held_input_elapsed = 0.0
			GameState.send_input(held_input)
	animation_elapsed += delta
	if animation_elapsed < 0.125:
		return
	animation_elapsed = 0.0
	animation_tick += 1
	map_view.set_animation_tick(animation_tick)

func _on_chat(value: Dictionary) -> void:
	chat_log.append_text("%s: %s\n" % [value.get("name", "Player"), value.get("text", "")])

func _send_chat(text: String) -> void:
	var trimmed := text.strip_edges()
	if not trimmed.is_empty() and GameState.send_chat(trimmed):
		chat_input.clear()

func _on_connection_error(message: String) -> void:
	status_label.text = message

func _on_interaction_requested(dialogue: Dictionary) -> void:
	if dialogue_overlay == null or dialogue.is_empty() or dialogue_overlay.is_open():
		return
	var pages: Array = dialogue.get("pages", [])
	if pages.is_empty():
		pages = [str(dialogue.get("text", ""))]
	dialogue_overlay.show_pages(pages)
	map_view.set_dialogue_active(true)

func _on_dialogue_action() -> void:
	if dialogue_overlay != null and dialogue_overlay.handle_action() and not dialogue_overlay.is_open():
		map_view.set_dialogue_active(false)

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if key_event.keycode == KEY_F and key_event.pressed and not key_event.echo:
		get_viewport().set_input_as_handled()
		if dialogue_overlay == null or not dialogue_overlay.is_open():
			map_view.interact()
		return
	if dialogue_overlay != null and dialogue_overlay.is_open():
		return
	var direction: String = ""
	match key_event.keycode:
		KEY_UP, KEY_W:
			direction = "up"
		KEY_DOWN, KEY_S:
			direction = "down"
		KEY_LEFT, KEY_A:
			direction = "left"
		KEY_RIGHT, KEY_D:
			direction = "right"
	if direction.is_empty():
		return
	if not key_event.pressed:
		if held_input == direction:
			held_input = ""
			held_input_elapsed = 0.0
		return
	if key_event.echo or get_viewport().gui_get_focus_owner() == chat_input or get_viewport().gui_get_focus_owner() == create_name_input:
		return
	held_input = direction
	held_input_elapsed = 0.0
	GameState.send_input(direction)
