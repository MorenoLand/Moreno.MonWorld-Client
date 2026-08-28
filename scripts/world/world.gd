extends Control

signal battle_requested

var title_label: Label
var status_label: Label
var chat_log: RichTextLabel
var chat_input: LineEdit
var snapshot: Dictionary = {}
var entities: Dictionary = {}
var selected_character_id := 0
var map_view: MonWorldMapPlayCanvas
var hud: MonWorldHud
var dialogue_overlay: MonWorldDialogue
var audio: MonWorldAudio
var animation_tick: int = 0
var animation_elapsed: float = 0.0
var held_input: String = ""
var held_input_elapsed: float = 0.0
var map_has_animation: bool = false

func _ready() -> void:
	set_process_unhandled_input(true)
	selected_character_id = int(GameState.current_character.get("id", 0))
	GameState.map_load_received.connect(_on_map_load)
	GameState.render_screen_changed.connect(_on_render_screen)
	GameState.world_snapshot_received.connect(_on_world_snapshot)
	GameState.entity_update_received.connect(_on_entity_update)
	GameState.chat_received.connect(_on_chat)
	GameState.connection_error.connect(_on_connection_error)
	_build_ui()
	if not GameState.pending_map_load.is_empty():
		call_deferred("_consume_pending_map_load")
	queue_redraw()

func _build_ui() -> void:
	map_view = MonWorldMapPlayCanvas.new()
	map_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_view.set_content(GameState.content)
	map_view.set_authoritative_state(true)
	map_view.set_input_enabled(true)
	map_view.interaction_requested.connect(_on_interaction_requested)
	map_view.sound_requested.connect(_on_sound_requested)
	add_child(map_view)
	audio = MonWorldAudio.new()
	add_child(audio)
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

func _consume_pending_map_load() -> void:
	if not GameState.pending_map_load.is_empty():
		_on_map_load(GameState.pending_map_load)

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
		var party: Array = []
		var snapshot_party: Variant = snapshot.get("party", [])
		if snapshot_party is Array:
			party = snapshot_party
		if party.is_empty():
			var selected_party: Variant = GameState.current_character.get("party", [])
			if selected_party is Array:
				party = selected_party
		snapshot["party"] = party
		hud.set_state(GameState.content, str(snapshot.get("map_id", "")), snapshot, party)
	_load_map_texture(str(snapshot.get("map_id", "")))
	_sync_map_entities()

func _on_map_load(value: Dictionary) -> void:
	var map_id: String = str(value.get("local_map_id", ""))
	if map_id.is_empty():
		status_label.text = "OpenMMO did not provide a renderable map"
		return
	snapshot = {"map_id": map_id, "server_map": value, "party": GameState.current_character.get("party", []), "players": []}
	entities.clear()
	if hud != null:
		hud.set_state(GameState.content, map_id, snapshot, snapshot.party)
	if not _load_map_texture(map_id, int(value.get("width", 0)), int(value.get("height", 0))):
		return
	_sync_map_entities()
	GameState.call_deferred("complete_map_load", str(value.get("key", "")))

func _load_map_texture(map_id: String, expected_width: int = 0, expected_height: int = 0) -> bool:
	if GameState.content == null or map_id.is_empty():
		return false
	var result: Dictionary = GameState.content.prepare_map(map_id)
	if not bool(result.get("ok", false)):
		status_label.text = "Map renderer: %s" % str(result.get("error", "map rendering failed"))
		return false
	if expected_width > 0 and expected_height > 0 and (int(result.get("width", 0)) != expected_width or int(result.get("height", 0)) != expected_height):
		status_label.text = "The local ROM map dimensions do not match the OpenMMO map"
		return false
	var background_texture: Texture2D = result.get("background_texture") as Texture2D
	var foreground_texture: Texture2D = result.get("foreground_texture") as Texture2D
	map_has_animation = GameState.content.has_animated_tiles(map_id)
	map_view.set_map(background_texture, int(result.get("width", 0)), int(result.get("height", 0)), result.get("objects", []), map_id, foreground_texture)
	audio.play_map_music(GameState.content, map_id)
	return true

func _on_entity_update(value: Dictionary) -> void:
	var player: Variant = value.get("player")
	if player is Dictionary:
		var entity: Dictionary = player
		var key := str(entity.get("entity_id", entity.get("character_id", entity.get("user_id", 0))))
		var is_local: bool = bool(value.get("local", false)) or int(entity.get("character_id", 0)) == selected_character_id
		var incoming_map_id: String = str(entity.get("map_id", ""))
		if is_local and not incoming_map_id.is_empty() and map_view != null and incoming_map_id != map_view.map_id:
			if _load_map_texture(incoming_map_id):
				snapshot["map_id"] = incoming_map_id
				title_label.text = "Map: %s" % incoming_map_id
		var merged: Dictionary = {}
		var existing: Variant = entities.get(key, {})
		if existing is Dictionary:
			merged = (existing as Dictionary).duplicate(true)
		merged.merge(entity, true)
		entities[key] = merged
		_sync_map_entities()

func _on_render_screen(visible: bool) -> void:
	if map_view != null:
		map_view.visible = visible
	if hud != null:
		hud.visible = visible

func _sync_map_entities() -> void:
	if map_view == null:
		return
	var players: Array = []
	for key in entities:
		var entity: Dictionary = entities[key]
		players.append(entity)
		if int(entity.get("character_id", 0)) == selected_character_id:
			map_view.set_player_state(int(entity.get("x", 0)), int(entity.get("y", 0)), int(entity.get("elevation", 3)), int(entity.get("facing", 1)))
	map_view.set_world_entities(players, selected_character_id)

func _process(delta: float) -> void:
	if map_view == null or snapshot.is_empty():
		return
	if not map_has_animation:
		return
	if map_view.movement_active:
		return
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
	dialogue_overlay.show_pages(pages, false, map_view.dialogue_anchor_screen(dialogue))
	map_view.set_dialogue_active(true)
	audio.play_effect("dialogue")

func _on_dialogue_action() -> void:
	audio.play_effect("dialogue")
	if dialogue_overlay != null and dialogue_overlay.handle_action() and not dialogue_overlay.is_open():
		map_view.set_dialogue_active(false)

func _on_sound_requested(effect: String) -> void:
	audio.play_effect(effect)

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
	if key_event.echo or get_viewport().gui_get_focus_owner() == chat_input:
		return
	held_input = direction
	held_input_elapsed = 0.0
	map_view.request_move(direction)
