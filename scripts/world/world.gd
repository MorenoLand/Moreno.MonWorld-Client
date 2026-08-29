extends Control

signal battle_requested

const MAP_VIEW_SCRIPT = preload("res://scripts/content/map_play_canvas.gd")
const HUD_SCRIPT = preload("res://scripts/world/hud.gd")
const DIALOGUE_SCRIPT = preload("res://scripts/dialogue.gd")
const AUDIO_SCRIPT = preload("res://scripts/world/audio.gd")
const CHAT_SCRIPT = preload("res://scripts/world/chat.gd")
const CONNECTED_WORLD_PRELOAD_DEPTH: int = 2

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
var debug_panel: PanelContainer
var debug_label: Label
var debug_dragging: bool = false
var debug_drag_offset: Vector2 = Vector2.ZERO
var transition_reveal_pending: bool = false
var transition_map_ready: bool = false
var transition_screen_ready: bool = false
var animation_tick: int = 0
var animation_elapsed: float = 0.0
var held_input: String = ""
var held_input_elapsed: float = 0.0
var map_has_animation: bool = false
var server_dialogue_active: bool = false
var server_dialogue_sequence: int = 0
var connected_world_generation: int = 0

func _ready() -> void:
	set_process_input(true)
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
	map_view.interaction_requested.connect(_on_interaction_requested)
	map_view.sound_requested.connect(_on_sound_requested)
	map_view.location_changed.connect(_on_local_location_changed)
	add_child(map_view)
	map_view.set_input_enabled(true)
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
	_build_debug_panel()
	resized.connect(_layout_ui)
	_layout_ui()

func _layout_ui() -> void:
	map_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chat_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	chat_box.offset_left = 24
	chat_box.offset_top = -214
	chat_box.offset_right = 444
	chat_box.offset_bottom = -24
	_clamp_debug_panel_position()

func _build_debug_panel() -> void:
	debug_panel = PanelContainer.new()
	debug_panel.name = "DebugPanel"
	debug_panel.position = Vector2(24.0, 120.0)
	debug_panel.custom_minimum_size = Vector2(340.0, 0.0)
	debug_panel.z_index = 1000
	debug_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color("10151ef2")
	panel_style.border_color = Color("5f7185")
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(3)
	panel_style.content_margin_left = 10.0
	panel_style.content_margin_top = 8.0
	panel_style.content_margin_right = 10.0
	panel_style.content_margin_bottom = 8.0
	debug_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(debug_panel)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	debug_panel.add_child(content)
	var title_bar: HBoxContainer = HBoxContainer.new()
	title_bar.custom_minimum_size = Vector2(0.0, 28.0)
	title_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	title_bar.gui_input.connect(_on_debug_title_input)
	content.add_child(title_bar)
	var title: Label = Label.new()
	title.text = "DEBUG  Ctrl+Shift+;"
	title.add_theme_font_size_override("font_size", 15)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_bar.add_child(title)
	var close_button: Button = Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(28.0, 28.0)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(_toggle_debug_panel)
	title_bar.add_child(close_button)
	debug_label = Label.new()
	debug_label.add_theme_font_size_override("font_size", 13)
	debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(debug_label)
	debug_panel.visible = false

func _clamp_debug_panel_position() -> void:
	if debug_panel == null:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	var max_position := Vector2(maxf(viewport_size.x - debug_panel.size.x, 0.0), maxf(viewport_size.y - debug_panel.size.y, 0.0))
	debug_panel.position = Vector2(clampf(debug_panel.position.x, 0.0, max_position.x), clampf(debug_panel.position.y, 0.0, max_position.y))

func _toggle_debug_panel() -> void:
	if debug_panel == null:
		return
	debug_panel.visible = not debug_panel.visible
	if debug_panel.visible:
		_update_debug_panel(0.0)

func _update_debug_panel(delta: float) -> void:
	if debug_label == null:
		return
	var map_id: String = "-"
	var position_text: String = "-"
	var elevation: int = -1
	var facing: int = -1
	var movement_status: String = "idle"
	var target_text: String = "-"
	var transition_status: String = "no"
	var spawn_status: String = "no"
	var input_status: String = "off"
	if map_view != null:
		map_id = str(map_view.map_id)
		position_text = "%d, %d" % [map_view.player_position.x, map_view.player_position.y]
		elevation = int(map_view.player_elevation)
		facing = int(map_view.player_facing)
		if bool(map_view.movement_active):
			movement_status = "active"
			target_text = "%d, %d" % [map_view.movement_target.x, map_view.movement_target.y]
		transition_status = "yes" if bool(map_view.transition_active) or transition_reveal_pending else "no"
		spawn_status = "yes" if bool(map_view.has_spawn) else "no"
		input_status = "on" if bool(map_view.input_enabled) else "off"
	var server_location: String = "%s/%s" % [str(GameState.current_character.get("bank_id", "-")), str(GameState.current_character.get("map_id", "-"))]
	var viewport_size: Vector2 = get_viewport_rect().size
	debug_label.text = "FPS: %d\nFrame: %.1f ms\nMap: %s\nServer bank/map: %s\nPosition: %s\nElevation: %d  Facing: %d\nMovement: %s\nTarget: %s\nTransition: %s\nSpawn ready: %s\nInput: %s\nHeld: %s\nEntities: %d\nViewport: %d x %d" % [Engine.get_frames_per_second(), delta * 1000.0, map_id, server_location, position_text, elevation, facing, movement_status, target_text, transition_status, spawn_status, input_status, held_input if not held_input.is_empty() else "-", entities.size(), int(viewport_size.x), int(viewport_size.y)]

func _on_debug_title_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button_event: InputEventMouseButton = event as InputEventMouseButton
		if button_event.button_index == MOUSE_BUTTON_LEFT:
			debug_dragging = button_event.pressed
			if debug_dragging:
				debug_drag_offset = debug_panel.position - get_global_mouse_position()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and debug_dragging:
		var pointer_position: Vector2 = get_global_mouse_position() + debug_drag_offset
		var viewport_size: Vector2 = get_viewport_rect().size
		var max_position := Vector2(maxf(viewport_size.x - debug_panel.size.x, 0.0), maxf(viewport_size.y - debug_panel.size.y, 0.0))
		debug_panel.position = Vector2(clampf(pointer_position.x, 0.0, max_position.x), clampf(pointer_position.y, 0.0, max_position.y))
		get_viewport().set_input_as_handled()

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
	_retain_server_entities_for_map(map_id)
	if hud != null:
		hud.set_state(GameState.content, map_id, snapshot, snapshot.party)
	if not _load_map_texture(map_id, int(value.get("width", 0)), int(value.get("height", 0))):
		return
	map_view.set_input_enabled(true)
	_sync_map_entities()
	GameState.call_deferred("complete_map_load", str(value.get("key", "")))
	transition_map_ready = true
	_try_reveal_screen_transition()

func _load_map_texture(map_id: String, expected_width: int = 0, expected_height: int = 0) -> bool:
	if GameState.content == null or map_id.is_empty():
		return false
	if map_view != null and map_view.map_id == map_id and map_view.is_map_rendered(map_id):
		return true
	connected_world_generation += 1
	var generation: int = connected_world_generation
	var server_map: Dictionary = GameState.content._server_map_for_local_map(map_id, GameState.server_maps)
	var result: Dictionary = GameState.content.prepare_server_map(map_id, server_map, GameState.server_maps, false) if GameState.content._is_server_custom_map(server_map) else GameState.content.prepare_map(map_id, false)
	if not bool(result.get("ok", false)):
		status_label.text = "Map renderer: %s" % str(result.get("error", "map rendering failed"))
		return false
	if expected_width > 0 and expected_height > 0 and (int(result.get("width", 0)) != expected_width or int(result.get("height", 0)) != expected_height):
		status_label.text = "The local ROM map dimensions do not match the OpenMMO map"
		return false
	map_has_animation = false
	map_has_animation = not (result.get("animated_background_tiles", []) as Array).is_empty() or not (result.get("animated_foreground_tiles", []) as Array).is_empty()
	var root_region: Dictionary = {"map_id": map_id, "origin": Vector2i.ZERO, "width": int(result.get("width", 0)), "height": int(result.get("height", 0)), "background_texture": result.get("background_texture"), "foreground_texture": result.get("foreground_texture"), "objects": map_view.objects_for_mode(result.get("objects", [])), "warps": result.get("warps", []), "connections": result.get("connections", []), "animated_background_tiles": result.get("animated_background_tiles", []), "animated_foreground_tiles": result.get("animated_foreground_tiles", []), "music_id": int(result.get("music_id", 0)), "map_type": int(result.get("map_type", 0)), "ready": true}
	var root_world: Dictionary = {"ok": true, "root_map_id": map_id, "regions": [root_region], "map_origins": {map_id: Vector2i.ZERO}}
	map_view.set_world(root_world, map_id)
	audio.play_map_music(GameState.content, map_id)
	call_deferred("_expand_connected_world", map_id, generation)
	return true

func _expand_connected_world(root_map_id: String, generation: int) -> void:
	await get_tree().process_frame
	while transition_overlay != null and transition_overlay.visible:
		await get_tree().process_frame
	if generation != connected_world_generation or map_view == null or map_view.map_id != root_map_id:
		return
	var connected_world: Dictionary = GameState.content.prepare_connected_world(root_map_id, 96, CONNECTED_WORLD_PRELOAD_DEPTH, GameState.server_maps)
	if not bool(connected_world.get("ok", false)) or generation != connected_world_generation:
		return
	map_view.set_world(connected_world, root_map_id)
	call_deferred("_preload_connected_regions", connected_world, root_map_id, generation)

func _preload_connected_regions(world_value: Dictionary, root_map_id: String, generation: int) -> void:
	var regions: Array = world_value.get("regions", [])
	for region_value in regions:
		if generation != connected_world_generation or not region_value is Dictionary:
			return
		var region: Dictionary = region_value
		var region_id: String = str(region.get("map_id", ""))
		if region_id.is_empty() or region_id == root_map_id or bool(region.get("ready", false)) or int(region.get("depth", 1)) > CONNECTED_WORLD_PRELOAD_DEPTH:
			continue
		await get_tree().process_frame
		if generation != connected_world_generation:
			return
		var server_map: Dictionary = GameState.content._server_map_for_local_map(region_id, GameState.server_maps)
		var prepared: Dictionary = GameState.content.prepare_server_map(region_id, server_map, GameState.server_maps, false) if GameState.content._is_server_custom_map(server_map) else GameState.content.prepare_map(region_id, false)
		if not bool(prepared.get("ok", false)):
			continue
		region["background_texture"] = prepared.get("background_texture")
		region["foreground_texture"] = prepared.get("foreground_texture")
		region["objects"] = map_view.objects_for_mode(prepared.get("objects", []))
		region["warps"] = prepared.get("warps", [])
		region["animated_background_tiles"] = prepared.get("animated_background_tiles", [])
		region["animated_foreground_tiles"] = prepared.get("animated_foreground_tiles", [])
		region["ready"] = true
		if map_view != null:
			map_view.refresh_world_bounds()
		_sync_map_entities()

func _on_entity_update(value: Dictionary) -> void:
	if value.has("remove_entity_id"):
		var removed_entity_id: int = int(value.get("remove_entity_id", 0))
		var remove_keys: Array = []
		for key in entities:
			var stored_value: Variant = entities[key]
			if stored_value is Dictionary and int((stored_value as Dictionary).get("entity_id", (stored_value as Dictionary).get("character_id", 0))) == removed_entity_id:
				remove_keys.append(key)
		for key in remove_keys:
			entities.erase(key)
		_sync_map_entities()
		return
	var player: Variant = value.get("player")
	if player is Dictionary:
		var entity: Dictionary = player
		var key := str(entity.get("entity_id", entity.get("character_id", entity.get("user_id", 0))))
		var is_local: bool = bool(value.get("local", false)) or int(entity.get("character_id", 0)) == selected_character_id
		var merged: Dictionary = {}
		var existing: Variant = entities.get(key, {})
		if existing is Dictionary:
			merged = (existing as Dictionary).duplicate(true)
		merged.merge(entity, true)
		entities[key] = merged
		if is_local and map_view != null:
			var entity_map_id: String = str(entity.get("map_id", ""))
			if not entity_map_id.is_empty() and entity_map_id != map_view.map_id:
				if not map_view.set_active_map(entity_map_id):
					_load_map_texture(entity_map_id)
				snapshot["map_id"] = entity_map_id
				if title_label != null:
					title_label.text = "Map: %s" % entity_map_id
			if entity.has("x") and entity.has("y"):
				var local_elevation: int = map_view.player_elevation
				map_view.apply_server_position(int(entity.get("x", map_view.player_position.x)), int(entity.get("y", map_view.player_position.y)), int(entity.get("elevation", local_elevation)), int(entity.get("facing", map_view.player_facing)))
			elif entity.has("facing"):
				map_view.apply_server_facing(int(entity.get("facing", map_view.player_facing)))
		_sync_map_entities()

func _on_local_location_changed(next_map_id: String, x: int, y: int) -> void:
	var facing: int = map_view.player_facing if map_view != null else int(GameState.current_character.get("facing", 1))
	var elevation: int = map_view.player_elevation if map_view != null else int(GameState.current_character.get("elevation", 3))
	var updated: bool = false
	for key in entities:
		var value: Variant = entities[key]
		if not value is Dictionary:
			continue
		var entity: Dictionary = value
		if int(entity.get("character_id", 0)) != selected_character_id:
			continue
		entity = entity.duplicate(true)
		entity["x"] = x
		entity["y"] = y
		entity["map_id"] = next_map_id
		entity["elevation"] = elevation
		entity["facing"] = facing
		entities[key] = entity
		updated = true
	if not updated:
		entities[str(selected_character_id)] = {"entity_id": selected_character_id, "character_id": selected_character_id, "map_id": next_map_id, "x": x, "y": y, "elevation": elevation, "facing": facing}
	GameState.current_character["x"] = x
	GameState.current_character["y"] = y
	GameState.current_character["facing"] = facing
	if map_view != null:
		map_view.set_player_state(x, y, elevation, facing)

func _on_render_screen(visible: bool) -> void:
	if not visible:
		if map_view != null:
			map_view.set_transition_active(true)
			map_view.set_input_enabled(false)
		transition_reveal_pending = true
		transition_map_ready = false
		transition_screen_ready = false
		_cover_screen_transition()
		return
	if transition_reveal_pending:
		transition_screen_ready = true
		_try_reveal_screen_transition()
		return
	if transition_overlay != null:
		transition_overlay.visible = false
	if map_view != null:
		map_view.visible = true
		map_view.set_transition_active(false)
		map_view.set_input_enabled(true)
	if hud != null:
		hud.visible = true

func _try_reveal_screen_transition() -> void:
	if not transition_reveal_pending or not transition_map_ready or not transition_screen_ready:
		return
	_reveal_screen_transition()
	if map_view != null:
		map_view.set_transition_active(false)
		map_view.set_input_enabled(true)

func _cover_screen_transition() -> void:
	if transition_overlay == null:
		return
	if transition_tween != null:
		transition_tween.kill()
	transition_overlay.visible = true
	transition_overlay.color = Color(0.0, 0.0, 0.0, 1.0)
	if map_view != null:
		map_view.visible = false
	if hud != null:
		hud.visible = false

func _reveal_screen_transition() -> void:
	transition_reveal_pending = false
	transition_map_ready = false
	transition_screen_ready = false
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
	map_view.set_world_entities(players, selected_character_id)

func _retain_server_entities_for_map(target_map_id: String) -> void:
	var retained: Dictionary = {}
	for key in entities:
		var value: Variant = entities[key]
		if not value is Dictionary:
			continue
		var entity: Dictionary = value
		if str(entity.get("map_id", "")) == target_map_id:
			retained[key] = entity
	entities = retained

func _process(delta: float) -> void:
	if debug_panel != null and debug_panel.visible:
		_update_debug_panel(delta)

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
	pages = _resolve_dialogue_pages(pages)
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
	var pages: Array = _streamed_dialogue_pages(action.get("detail", PackedByteArray()))
	if pages.is_empty():
		var dialogue: Dictionary = GameState.content.dialogue_for_text_id(text_id) if GameState.content != null else {}
		pages = dialogue.get("pages", []) if not dialogue.is_empty() else []
	if pages.is_empty():
		pages = ["Dialogue text 0x%08X is unavailable in the selected ROM." % text_id]
	pages = _resolve_dialogue_pages(pages)
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

func _resolve_dialogue_pages(pages: Array) -> Array:
	var character_name: String = str(GameState.current_character.get("name", ""))
	var resolved: Array = []
	for page_value in pages:
		var page: String = str(page_value)
		page = page.replace("{01}", character_name).replace("{PLAYER}", character_name)
		resolved.append(page)
	return resolved

func _streamed_dialogue_pages(detail_value: Variant) -> Array:
	if not detail_value is PackedByteArray:
		return []
	var detail: PackedByteArray = detail_value
	var marker: PackedByteArray = PackedByteArray([0x4F, 0x4D, 0x54, 0x58, 0x54, 0x00])
	if detail.size() <= marker.size():
		return []
	for index in marker.size():
		if detail[index] != marker[index]:
			return []
	var pages: Array = []
	for page in detail.slice(marker.size()).get_string_from_utf8().split("\f"):
		if not str(page).is_empty():
			pages.append(page)
	return pages

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
		_toggle_debug_panel()
		get_viewport().set_input_as_handled()
		return
	if key_event.keycode == KEY_B and key_event.pressed and not key_event.echo:
		if hud != null:
			hud.toggle_bag()
		get_viewport().set_input_as_handled()
		return
	if key_event.keycode == KEY_M and key_event.pressed and not key_event.echo:
		if hud != null:
			hud.toggle_menu()
		get_viewport().set_input_as_handled()
		return
	var hotkey_slot: int = _hotkey_slot_for_key(key_event.keycode)
	if hotkey_slot >= 0 and key_event.pressed and not key_event.echo:
		if hud != null:
			hud.activate_hotkey(hotkey_slot)
		get_viewport().set_input_as_handled()
		return
	if key_event.keycode in [KEY_F, KEY_E, KEY_Z, KEY_X] and key_event.pressed and not key_event.echo:
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
	return

func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	var is_semicolon: bool = key_event.keycode == KEY_SEMICOLON or key_event.physical_keycode == KEY_SEMICOLON
	if is_semicolon and key_event.ctrl_pressed and key_event.shift_pressed and key_event.pressed and not key_event.echo:
		_toggle_debug_panel()
		get_viewport().set_input_as_handled()

func _hotkey_slot_for_key(keycode: int) -> int:
	match keycode:
		KEY_1: return 0
		KEY_2: return 1
		KEY_3: return 2
		KEY_4: return 3
		KEY_5: return 4
		KEY_6: return 5
		KEY_7: return 6
		KEY_8: return 7
		KEY_9: return 8
	return -1
