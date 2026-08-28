extends Control

signal battle_requested

const MAP_VIEW_SCRIPT = preload("res://scripts/content/map_play_canvas.gd")
const HUD_SCRIPT = preload("res://scripts/world/hud.gd")
const DIALOGUE_SCRIPT = preload("res://scripts/dialogue.gd")
const AUDIO_SCRIPT = preload("res://scripts/world/audio.gd")
const CHAT_SCRIPT = preload("res://scripts/world/chat.gd")

var title_label: Label
var status_label: Label
var chat_box
var snapshot: Dictionary = {}
var entities: Dictionary = {}
var selected_character_id := 0
var map_view
var hud
var dialogue_overlay
var audio
var transition_overlay: ColorRect
var transition_tween: Tween
var transition_reveal_pending: bool = false
var transition_map_ready: bool = false
var animation_tick: int = 0
var animation_elapsed: float = 0.0
var held_input: String = ""
var held_input_elapsed: float = 0.0
var map_has_animation: bool = false
var server_dialogue_active: bool = false
var server_dialogue_sequence: int = 0
var connected_world_generation: int = 0

func _ready() -> void:
	set_process_unhandled_input(true)
	selected_character_id = int(GameState.current_character.get("id", 0))
	GameState.map_load_received.connect(_on_map_load)
	GameState.render_screen_changed.connect(_on_render_screen)
	GameState.world_snapshot_received.connect(_on_world_snapshot)
	GameState.entity_update_received.connect(_on_entity_update)
	GameState.chat_received.connect(_on_chat)
	GameState.connection_error.connect(_on_connection_error)
	GameState.dialog_action_received.connect(_on_dialog_action_received)
	GameState.dialog_state_received.connect(_on_dialog_state_received)
	_build_ui()
	if not GameState.pending_map_load.is_empty():
		call_deferred("_consume_pending_map_load")
	queue_redraw()

func _build_ui() -> void:
	map_view = MAP_VIEW_SCRIPT.new()
	map_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_view.set_content(GameState.content)
	map_view.set_authoritative_state(true)
	map_view.set_input_enabled(true)
	map_view.interaction_requested.connect(_on_interaction_requested)
	map_view.sound_requested.connect(_on_sound_requested)
	add_child(map_view)
	audio = AUDIO_SCRIPT.new()
	add_child(audio)
	hud = HUD_SCRIPT.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(hud)
	chat_box = CHAT_SCRIPT.new()
	chat_box.message_submitted.connect(_send_chat)
	add_child(chat_box)
	dialogue_overlay = DIALOGUE_SCRIPT.new()
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
	transition_overlay = ColorRect.new()
	transition_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	transition_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_overlay.visible = false
	add_child(transition_overlay)
	resized.connect(_layout_ui)
	_layout_ui()

func _layout_ui() -> void:
	map_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chat_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	chat_box.offset_left = 24
	chat_box.offset_top = -214
	chat_box.offset_right = 444
	chat_box.offset_bottom = -24

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
	transition_map_ready = true
	if transition_reveal_pending:
		_reveal_screen_transition()

func _load_map_texture(map_id: String, expected_width: int = 0, expected_height: int = 0) -> bool:
	if GameState.content == null or map_id.is_empty():
		return false
	connected_world_generation += 1
	var generation: int = connected_world_generation
	var connected_world: Dictionary = GameState.content.prepare_connected_world(map_id, 96, 0, GameState.server_maps)
	if not bool(connected_world.get("ok", false)):
		status_label.text = "Map renderer: %s" % str(connected_world.get("error", "map rendering failed"))
		return false
	var regions: Array = connected_world.get("regions", [])
	var result: Dictionary = GameState.content.prepare_map(map_id, false)
	if not bool(result.get("ok", false)):
		status_label.text = "Map renderer: %s" % str(result.get("error", "map rendering failed"))
		return false
	if expected_width > 0 and expected_height > 0 and (int(result.get("width", 0)) != expected_width or int(result.get("height", 0)) != expected_height):
		status_label.text = "The local ROM map dimensions do not match the OpenMMO map"
		return false
	map_has_animation = false
	for region_value in regions:
		if region_value is Dictionary and (not (region_value.get("animated_background_tiles", []) as Array).is_empty() or not (region_value.get("animated_foreground_tiles", []) as Array).is_empty()):
			map_has_animation = true
			break
	map_view.set_world(connected_world, map_id)
	audio.play_map_music(GameState.content, map_id)
	call_deferred("_preload_connected_regions", connected_world, map_id, generation)
	return true

func _preload_connected_regions(world_value: Dictionary, root_map_id: String, generation: int) -> void:
	var regions: Array = world_value.get("regions", [])
	for region_value in regions:
		if generation != connected_world_generation or not region_value is Dictionary:
			return
		var region: Dictionary = region_value
		var region_id: String = str(region.get("map_id", ""))
		if region_id.is_empty() or region_id == root_map_id or bool(region.get("ready", false)):
			continue
		await get_tree().process_frame
		if generation != connected_world_generation:
			return
		var prepared: Dictionary = GameState.content.prepare_map(region_id, false)
		if not bool(prepared.get("ok", false)):
			continue
		region["background_texture"] = prepared.get("background_texture")
		region["foreground_texture"] = prepared.get("foreground_texture")
		region["objects"] = prepared.get("objects", [])
		region["warps"] = prepared.get("warps", [])
		region["animated_background_tiles"] = prepared.get("animated_background_tiles", [])
		region["animated_foreground_tiles"] = prepared.get("animated_foreground_tiles", [])
		region["border_texture"] = GameState.content.server_border_texture(region_id, GameState.content._server_map_for_local_map(region_id, GameState.server_maps))
		region["ready"] = true
		if map_view != null:
			map_view.queue_redraw()

func _on_entity_update(value: Dictionary) -> void:
	var player: Variant = value.get("player")
	if player is Dictionary:
		var entity: Dictionary = player
		var key := str(entity.get("entity_id", entity.get("character_id", entity.get("user_id", 0))))
		var is_local: bool = bool(value.get("local", false)) or int(entity.get("character_id", 0)) == selected_character_id
		var incoming_map_id: String = str(entity.get("map_id", ""))
		if is_local and not incoming_map_id.is_empty() and map_view != null and incoming_map_id != map_view.map_id:
			if map_view.set_active_map(incoming_map_id) or _load_map_texture(incoming_map_id):
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
	if not visible:
		transition_reveal_pending = true
		transition_map_ready = false
		_cover_screen_transition()
		return
	if transition_reveal_pending:
		if transition_map_ready:
			_reveal_screen_transition()
		return
	if transition_overlay != null:
		transition_overlay.visible = false
	if map_view != null:
		map_view.visible = true
	if hud != null:
		hud.visible = true

func _cover_screen_transition() -> void:
	if transition_overlay == null:
		return
	if transition_tween != null:
		transition_tween.kill()
	transition_overlay.visible = true
	transition_tween = create_tween()
	transition_tween.tween_property(transition_overlay, "color", Color(0.0, 0.0, 0.0, 1.0), 0.10)
	transition_tween.tween_callback(func() -> void:
		if map_view != null:
			map_view.visible = false
		if hud != null:
			hud.visible = false
	)

func _reveal_screen_transition() -> void:
	transition_reveal_pending = false
	transition_map_ready = false
	if map_view != null:
		map_view.visible = true
	if hud != null:
		hud.visible = true
	if transition_overlay == null:
		return
	if transition_tween != null:
		transition_tween.kill()
	transition_overlay.visible = true
	transition_overlay.color = Color(0.0, 0.0, 0.0, 1.0)
	transition_tween = create_tween()
	transition_tween.tween_property(transition_overlay, "color", Color(0.0, 0.0, 0.0, 0.0), 0.12)
	transition_tween.tween_callback(func() -> void:
		if transition_overlay != null:
			transition_overlay.visible = false
	)

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
	pass

func _on_chat(value: Dictionary) -> void:
	if chat_box != null:
		chat_box.add_message(value)

func _send_chat(text: String, channel: String = "Normal") -> void:
	var trimmed := text.strip_edges()
	if not trimmed.is_empty() and GameState.send_chat(trimmed, channel):
		chat_box.clear_input()

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

func _on_dialog_action_received(action: Dictionary) -> void:
	if dialogue_overlay == null or map_view == null:
		return
	var action_type: int = int(action.get("action_type", -1))
	if action_type == 0x64:
		server_dialogue_active = false
		dialogue_overlay.close_dialogue()
		map_view.set_dialogue_active(false)
		map_view.restore_interaction_facing()
		return
	var text_id: int = int(action.get("text_id", 0))
	var dialogue: Dictionary = GameState.content.dialogue_for_text_id(text_id) if GameState.content != null else {}
	var pages: Array = dialogue.get("pages", []) if not dialogue.is_empty() else []
	if pages.is_empty():
		pages = ["Dialogue text 0x%08X is unavailable in the selected ROM." % text_id]
	var actor: Dictionary = {}
	var entity_id: int = int(action.get("entity_id", -1))
	var entity_value: Variant = entities.get(str(entity_id), {})
	if entity_value is Dictionary:
		actor = (entity_value as Dictionary).duplicate()
	if actor.is_empty():
		actor = {"map_id": map_view.map_id, "x": map_view.player_position.x, "y": map_view.player_position.y, "elevation": map_view.player_elevation}
	server_dialogue_active = true
	server_dialogue_sequence = int(action.get("flags", 0)) & 0xFF
	map_view.set_dialogue_active(true)
	dialogue_overlay.show_pages(pages, false, map_view.dialogue_anchor_screen({"object": actor}))
	audio.play_effect("dialogue")

func _on_dialog_state_received(open: bool) -> void:
	server_dialogue_active = open
	map_view.set_dialogue_active(open)
	if not open:
		dialogue_overlay.close_dialogue()
		map_view.restore_interaction_facing()

func _on_dialogue_action() -> void:
	audio.play_effect("dialogue")
	if server_dialogue_active:
		if dialogue_overlay != null and not dialogue_overlay.text_complete():
			dialogue_overlay.handle_action()
			return
		GameState.send_dialogue_action_response(server_dialogue_sequence, 0)
		if dialogue_overlay != null:
			dialogue_overlay.close_dialogue()
		map_view.restore_interaction_facing()
		return
	if dialogue_overlay != null and dialogue_overlay.handle_action() and not dialogue_overlay.is_open():
		map_view.set_dialogue_active(false)
		map_view.restore_interaction_facing()

func _on_sound_requested(effect: String) -> void:
	audio.play_effect(effect)

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if key_event.keycode == KEY_F3 and key_event.pressed and not key_event.echo:
		if hud != null:
			hud.toggle_stats()
		get_viewport().set_input_as_handled()
		return
	if key_event.keycode == KEY_F and key_event.pressed and not key_event.echo:
		get_viewport().set_input_as_handled()
		if dialogue_overlay == null or not dialogue_overlay.is_open():
			map_view.interact()
		return
	if key_event.pressed and not key_event.echo and chat_box != null and not chat_box.input_focused() and key_event.keycode in [KEY_ENTER, KEY_T, KEY_SLASH]:
		chat_box.focus_input("/" if key_event.keycode == KEY_SLASH else "")
		get_viewport().set_input_as_handled()
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
	if key_event.echo or (chat_box != null and chat_box.input_focused()):
		return
	held_input = direction
	held_input_elapsed = 0.0
	map_view.request_move(direction)
