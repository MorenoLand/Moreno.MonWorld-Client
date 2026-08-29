extends Control

signal exit_requested

var log_view: RichTextLabel
var state_label: Label
var action_box: VBoxContainer
var player_party_box: VBoxContainer
var opponent_party_box: VBoxContainer
var stage_root: Control
var flash_overlay: ColorRect
var close_button: Button
var opponent_name_label: Label
var opponent_level_label: Label
var opponent_hp_bar: ProgressBar
var opponent_hp_label: Label
var player_name_label: Label
var player_level_label: Label
var player_hp_bar: ProgressBar
var player_hp_label: Label
var opponent_sprite: TextureRect
var player_sprite: TextureRect
var effects_layer: Control
var hp_tweens: Dictionary = {}
var move_tween: Tween
var state: Dictionary = {}
var selection_mode: String = ""
var input_locked: bool = true

func _ready() -> void:
	if not GameState.battle_event_received.is_connected(_on_battle_event):
		GameState.battle_event_received.connect(_on_battle_event)
	_build_ui()
	state = GameState.battle_state.duplicate(true)
	_render_state()
	_trigger_flash()

func _exit_tree() -> void:
	if GameState.battle_event_received.is_connected(_on_battle_event):
		GameState.battle_event_received.disconnect(_on_battle_event)

func _build_ui() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var world_tint := ColorRect.new()
	world_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	world_tint.color = Color(0.02, 0.04, 0.07, 0.18)
	world_tint.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(world_tint)
	var stage := Control.new()
	stage.set_anchors_preset(Control.PRESET_CENTER)
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(stage)
	stage_root = Control.new()
	stage_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(stage_root)
	var title := Label.new()
	title.text = "BATTLE"
	title.position = Vector2(28.0, 18.0)
	title.add_theme_font_size_override("font_size", 22)
	stage_root.add_child(title)
	state_label = Label.new()
	state_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	state_label.offset_left = -300.0
	state_label.offset_top = 18.0
	state_label.offset_right = 300.0
	state_label.offset_bottom = 48.0
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state_label.add_theme_font_size_override("font_size", 14)
	state_label.add_theme_color_override("font_color", Color("c8d7e8"))
	stage_root.add_child(state_label)
	var opponent_card := _make_mon_card(true)
	opponent_card.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	opponent_card.offset_left = -306.0
	opponent_card.offset_top = 70.0
	opponent_card.offset_right = -28.0
	opponent_card.offset_bottom = 176.0
	stage_root.add_child(opponent_card)
	var player_card := _make_mon_card(false)
	player_card.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	player_card.offset_left = 28.0
	player_card.offset_top = -168.0
	player_card.offset_right = 350.0
	player_card.offset_bottom = -42.0
	stage_root.add_child(player_card)
	opponent_sprite = _make_sprite()
	opponent_sprite.set_anchors_preset(Control.PRESET_CENTER)
	opponent_sprite.offset_left = 135.0
	opponent_sprite.offset_top = -195.0
	opponent_sprite.offset_right = 415.0
	opponent_sprite.offset_bottom = 30.0
	opponent_sprite.pivot_offset = Vector2(140.0, 112.0)
	opponent_sprite.z_index = 1
	stage_root.add_child(opponent_sprite)
	player_sprite = _make_sprite()
	player_sprite.set_anchors_preset(Control.PRESET_CENTER)
	player_sprite.offset_left = -415.0
	player_sprite.offset_top = -30.0
	player_sprite.offset_right = -135.0
	player_sprite.offset_bottom = 195.0
	player_sprite.pivot_offset = Vector2(140.0, 112.0)
	player_sprite.z_index = 1
	stage_root.add_child(player_sprite)
	effects_layer = Control.new()
	effects_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	effects_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effects_layer.z_index = 2
	stage_root.add_child(effects_layer)
	var log_panel := PanelContainer.new()
	log_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	log_panel.offset_left = 350.0
	log_panel.offset_top = -112.0
	log_panel.offset_right = 700.0
	log_panel.offset_bottom = -30.0
	log_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.04, 0.07, 0.72), Color("536a84"), 8, 1))
	stage_root.add_child(log_panel)
	log_view = RichTextLabel.new()
	log_view.bbcode_enabled = false
	log_view.fit_content = false
	log_view.scroll_active = false
	log_view.custom_minimum_size = Vector2(0.0, 80.0)
	log_view.add_theme_font_size_override("normal_font_size", 13)
	log_panel.add_child(log_view)
	var action_panel := PanelContainer.new()
	action_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	action_panel.offset_left = -306.0
	action_panel.offset_top = -202.0
	action_panel.offset_right = -28.0
	action_panel.offset_bottom = -30.0
	action_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.04, 0.07, 0.94), Color("7186a2"), 8, 1))
	stage_root.add_child(action_panel)
	action_box = VBoxContainer.new()
	action_box.add_theme_constant_override("separation", 5)
	action_panel.add_child(action_box)
	close_button = _make_button("Return to world")
	close_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	close_button.offset_left = -184.0
	close_button.offset_top = 16.0
	close_button.offset_right = -28.0
	close_button.offset_bottom = 50.0
	close_button.pressed.connect(_return_to_world)
	close_button.disabled = true
	stage_root.add_child(close_button)
	flash_overlay = ColorRect.new()
	flash_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash_overlay.color = Color(1.0, 1.0, 1.0, 0.0)
	flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_overlay.z_index = 20
	add_child(flash_overlay)

func _make_mon_card(opponent: bool) -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.04, 0.07, 0.93), Color("7186a2"), 8, 1))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	margin.add_child(box)
	var name_label := Label.new()
	name_label.add_theme_font_size_override("font_size", 17)
	box.add_child(name_label)
	var level_label := Label.new()
	level_label.add_theme_font_size_override("font_size", 12)
	level_label.add_theme_color_override("font_color", Color("b8cbe0"))
	box.add_child(level_label)
	var hp_bar := ProgressBar.new()
	hp_bar.show_percentage = false
	hp_bar.custom_minimum_size = Vector2(0.0, 13.0)
	hp_bar.add_theme_stylebox_override("background", _panel_style(Color("26303d"), Color("26303d"), 5, 0))
	hp_bar.add_theme_stylebox_override("fill", _panel_style(Color("5ccf77") if not opponent else Color("e6bd5a"), Color("5ccf77") if not opponent else Color("e6bd5a"), 5, 0))
	box.add_child(hp_bar)
	var hp_label := Label.new()
	hp_label.add_theme_font_size_override("font_size", 11)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(hp_label)
	if opponent:
		opponent_name_label = name_label
		opponent_level_label = level_label
		opponent_hp_bar = hp_bar
		opponent_hp_label = hp_label
	else:
		player_name_label = name_label
		player_level_label = level_label
		player_hp_bar = hp_bar
		player_hp_label = hp_label
	return card

func _make_sprite() -> TextureRect:
	var sprite := TextureRect.new()
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return sprite

func _panel_style(background: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style

func _make_button(label: String) -> Button:
	var button := Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_stylebox_override("normal", _panel_style(Color("111b28"), Color("536a84"), 6, 1))
	button.add_theme_stylebox_override("hover", _panel_style(Color("1d3650"), Color("8fb9df"), 6, 1))
	button.add_theme_stylebox_override("pressed", _panel_style(Color("274b68"), Color("b7d9f4"), 6, 1))
	return button

func _return_to_world() -> void:
	if not bool(state.get("battle_complete", false)):
		return
	exit_requested.emit()

func _render_state() -> void:
	if state.is_empty():
		state_label.text = "Waiting for server battle state..."
		_render_actions()
		return
	var opponent_party: Array = state.get("opponent_party", []) if state.get("opponent_party", []) is Array else []
	var player_party: Array = state.get("player_party", []) if state.get("player_party", []) is Array else []
	var opponent: Dictionary = _active_mon(opponent_party, int(state.get("opponent_active_slot", -1)))
	var player: Dictionary = _active_mon(player_party, int(state.get("active_slot", -1)))
	var opponent_name: String = _battle_mon_name(opponent, true)
	var player_name: String = _battle_mon_name(player, false)
	var phase: String = "Complete" if bool(state.get("battle_complete", false)) else "Active"
	var prompt: String = "Choose an action" if bool(state.get("can_act", false)) and not input_locked else "Waiting for server"
	state_label.text = "%s  |  %s vs %s  |  %s" % [phase, opponent_name, player_name, prompt]
	_update_mon_card(opponent_name_label, opponent_level_label, opponent_hp_bar, opponent_hp_label, opponent, "opponent")
	_update_mon_card(player_name_label, player_level_label, player_hp_bar, player_hp_label, player, "player")
	_update_sprite(opponent_sprite, opponent, false)
	_update_sprite(player_sprite, player, true)
	close_button.disabled = not bool(state.get("battle_complete", false))
	_render_actions()

func _active_mon(party: Array, active_slot: int) -> Dictionary:
	for mon_value in party:
		if mon_value is Dictionary and int((mon_value as Dictionary).get("slot", -1)) == active_slot:
			return mon_value as Dictionary
	if active_slot >= 0 and active_slot < party.size() and party[active_slot] is Dictionary:
		return party[active_slot] as Dictionary
	return {}

func _update_mon_card(name_label: Label, level_label: Label, hp_bar: ProgressBar, hp_label: Label, mon: Dictionary, tween_key: String) -> void:
	var level: int = int(mon.get("level", 0))
	level_label.text = "Lv %d" % level if level > 0 else ""
	var current_hp: int = int(mon.get("current_hp", mon.get("hp", 0)))
	var max_hp: int = int(mon.get("max_hp", mon.get("hp_max", 0)))
	if max_hp <= 0:
		max_hp = maxi(current_hp, 1)
	hp_bar.max_value = max_hp
	var target_hp: float = clampf(float(current_hp), 0.0, float(max_hp))
	var fill_color: Color = Color("d94c5a") if target_hp * 5.0 <= max_hp else Color("e6bd5a") if target_hp * 2.0 <= max_hp else Color("5ccf77")
	hp_bar.add_theme_stylebox_override("fill", _panel_style(fill_color, fill_color, 5, 0))
	if not bool(hp_bar.get_meta("initialized", false)):
		hp_bar.value = target_hp
		hp_bar.set_meta("initialized", true)
	else:
		var previous_tween: Tween = hp_tweens.get(tween_key) as Tween
		if previous_tween != null:
			previous_tween.kill()
		if absf(float(hp_bar.value) - target_hp) > 0.1:
			var tween: Tween = create_tween()
			hp_tweens[tween_key] = tween
			tween.tween_method(_set_hp_display.bind(hp_bar, hp_label, max_hp), float(hp_bar.value), target_hp, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		else:
			hp_bar.value = target_hp
	_set_hp_display(hp_bar, hp_label, max_hp, float(hp_bar.value))
	name_label.text = _battle_mon_name(mon, name_label == opponent_name_label)

func _set_hp_display(hp_bar: ProgressBar, hp_label: Label, max_hp: int, value: float) -> void:
	var shown_hp: int = clampi(roundi(value), 0, max_hp)
	hp_bar.value = value
	hp_label.text = "%d / %d HP" % [shown_hp, max_hp]

func _update_sprite(sprite: TextureRect, mon: Dictionary, back: bool) -> void:
	var species_id: int = int(mon.get("species", mon.get("species_id", mon.get("dex_id", 0))))
	var previous_texture: Texture2D = sprite.texture
	sprite.texture = null
	if GameState.content == null or species_id <= 0:
		return
	var result: Dictionary = GameState.content.battle_pokemon_sprite(species_id, back)
	if bool(result.get("ok", false)):
		sprite.texture = result.get("texture") as Texture2D
	if previous_texture != sprite.texture:
		sprite.modulate = Color.WHITE

func _render_party(container: VBoxContainer, party_value: Variant, active_slot: int, opponent: bool) -> void:
	for child in container.get_children():
		child.queue_free()
	var heading := Label.new()
	heading.text = str(state.get("opponent_name", "Opponent") if opponent else state.get("player_name", "Player"))
	heading.add_theme_font_size_override("font_size", 20)
	container.add_child(heading)
	if not party_value is Array or (party_value as Array).is_empty():
		var empty_label := Label.new()
		empty_label.text = "No party data"
		container.add_child(empty_label)
		return
	for mon_value in party_value as Array:
		if not mon_value is Dictionary:
			continue
		var mon: Dictionary = mon_value
		var line := VBoxContainer.new()
		var label := Label.new()
		var slot: int = int(mon.get("slot", -1))
		var marker: String = "ACTIVE " if slot == active_slot else ""
		var fainted: bool = int(mon.get("current_hp", 0)) <= 0 or bool(mon.get("faint", false))
		var status: String = "FAINTED" if fainted else "Lv %d" % int(mon.get("level", 0))
		label.text = "%s%s  %s" % [marker, _battle_mon_name(mon, opponent), status]
		line.add_child(label)
		var hp := ProgressBar.new()
		hp.max_value = maxi(1, int(mon.get("max_hp", 0)))
		hp.value = clampi(int(mon.get("current_hp", 0)), 0, int(hp.max_value))
		hp.show_percentage = false
		hp.custom_minimum_size = Vector2(0, 12)
		line.add_child(hp)
		container.add_child(line)

func _battle_mon_name(mon: Dictionary, opponent: bool) -> String:
	var nickname_value: Variant = mon.get("nickname", "")
	var resolved_name: String = str(nickname_value).strip_edges() if nickname_value != null else ""
	if resolved_name.is_empty():
		resolved_name = str(mon.get("name", "")).strip_edges()
	if not resolved_name.is_empty():
		return resolved_name
	var resolved_species: int = int(mon.get("species", mon.get("species_id", mon.get("dex_id", 0))))
	if resolved_species > 0 and GameState.content != null:
		return GameState.content.battle_pokemon_name(resolved_species)
	if resolved_species > 0:
		return "POKEMON #%d" % resolved_species
	return "Wild Pokemon" if opponent else "Pokemon"

func _render_actions() -> void:
	if action_box == null:
		return
	for child in action_box.get_children():
		child.queue_free()
	var heading := Label.new()
	heading.text = "Actions"
	heading.add_theme_font_size_override("font_size", 18)
	action_box.add_child(heading)
	if bool(state.get("battle_complete", false)):
		var complete := Label.new()
		complete.text = "Battle complete."
		action_box.add_child(complete)
		return
	if input_locked or not bool(state.get("can_act", false)):
		var waiting := Label.new()
		waiting.text = "Waiting for the server..."
		action_box.add_child(waiting)
		return
	if bool(state.get("force_switch", false)):
		selection_mode = "pokemon"
	if selection_mode == "fight":
		_render_move_selection()
	elif selection_mode == "pokemon":
		_render_pokemon_selection()
	else:
		var buttons := GridContainer.new()
		buttons.columns = 2
		for entry in [["Fight", "fight"], ["Bag", "bag"], ["Pokémon", "pokemon"], ["Run", "run"]]:
			var button := Button.new()
			button.text = "Pokemon" if str(entry[1]) == "pokemon" else str(entry[0])
			button.custom_minimum_size = Vector2(120, 42)
			if str(entry[1]) == "fight":
				button.pressed.connect(_choose_fight)
			elif str(entry[1]) == "pokemon":
				button.pressed.connect(_choose_pokemon)
			elif str(entry[1]) == "run":
				button.pressed.connect(_send_run)
			else:
				button.disabled = true
				button.tooltip_text = "The server has not provided an item list."
			buttons.add_child(button)
		action_box.add_child(buttons)

func _choose_fight() -> void:
	selection_mode = "fight"
	_render_actions()

func _choose_pokemon() -> void:
	selection_mode = "pokemon"
	_render_actions()

func _render_move_selection() -> void:
	var moves: Array = _active_move_ids()
	if moves.is_empty():
		var empty := Label.new()
		empty.text = "No revealed moves are available."
		action_box.add_child(empty)
		_add_cancel_button()
		return
	var grid := GridContainer.new()
	grid.columns = 2
	for move_id_value in moves:
		var move_id: int = int(move_id_value)
		if move_id <= 0:
			continue
		var button := Button.new()
		var move_info: Dictionary = GameState.content.battle_move_info(move_id) if GameState.content != null else {}
		var move_name: String = str(move_info.get("name", GameState.content.battle_move_name(move_id) if GameState.content != null else "MOVE %d" % move_id))
		var move_type: String = str(move_info.get("type_name", ""))
		button.text = "%s\n%s" % [move_name, move_type] if not move_type.is_empty() and move_type != "Unknown" else move_name
		button.tooltip_text = "Type: %s | Power: %d" % [move_type, int(move_info.get("power", 0))] if not move_type.is_empty() and move_type != "Unknown" else ""
		button.custom_minimum_size = Vector2(140, 44)
		button.pressed.connect(_send_move.bind(move_id))
		grid.add_child(button)
	action_box.add_child(grid)
	_add_cancel_button()

func _render_pokemon_selection() -> void:
	var party_value: Variant = state.get("player_party", [])
	var grid := GridContainer.new()
	grid.columns = 2
	if party_value is Array:
		for mon_value in party_value as Array:
			if not mon_value is Dictionary:
				continue
			var mon: Dictionary = mon_value
			var slot: int = int(mon.get("slot", -1))
			if slot < 0 or slot == int(state.get("active_slot", -1)) or int(mon.get("current_hp", 0)) <= 0:
				continue
			var button := Button.new()
			var current_hp: int = int(mon.get("current_hp", mon.get("hp", 0)))
			var max_hp: int = int(mon.get("max_hp", mon.get("hp_max", 0)))
			if max_hp <= 0:
				max_hp = maxi(current_hp, 1)
			button.text = "%s\nLv %d  %d / %d HP" % [_battle_mon_name(mon, false), int(mon.get("level", 0)), current_hp, max_hp]
			var species_id: int = int(mon.get("species", mon.get("species_id", mon.get("dex_id", 0))))
			if GameState.content != null and species_id > 0:
				var sprite: Dictionary = GameState.content.battle_pokemon_sprite(species_id, false)
				button.icon = sprite.get("texture") as Texture2D
			button.custom_minimum_size = Vector2(140, 50)
			button.pressed.connect(_send_switch.bind(slot))
			grid.add_child(button)
	if grid.get_child_count() == 0:
		var empty := Label.new()
		empty.text = "No available Pokémon to switch to."
		action_box.add_child(empty)
	else:
		action_box.add_child(grid)
	if not bool(state.get("force_switch", false)):
		_add_cancel_button()

func _add_cancel_button() -> void:
	var cancel := Button.new()
	cancel.text = "Back"
	cancel.pressed.connect(_cancel_selection)
	action_box.add_child(cancel)

func _cancel_selection() -> void:
	selection_mode = ""
	_render_actions()

func _active_move_ids() -> Array:
	var party_value: Variant = state.get("player_party", [])
	if not party_value is Array:
		return []
	var active_slot: int = int(state.get("active_slot", -1))
	for mon_value in party_value as Array:
		if mon_value is Dictionary and int((mon_value as Dictionary).get("slot", -1)) == active_slot:
			var move_value: Variant = (mon_value as Dictionary).get("move_ids", [])
			return move_value as Array if move_value is Array else []
	return []

func _send_move(move_id: int) -> void:
	_send_battle_action(0, move_id, GameState.content.battle_move_name(move_id) if GameState.content != null else "MOVE #%d" % move_id)

func _send_switch(slot: int) -> void:
	_send_battle_action(2, slot, "Switch to slot %d" % slot)

func _send_run() -> void:
	_send_battle_action(3, 0, "Run")

func _send_battle_action(action: int, value: int, label: String) -> void:
	if input_locked or not bool(state.get("can_act", false)):
		return
	if GameState.send_battle_action(action, value):
		input_locked = true
		selection_mode = ""
		_append_log("Sent: %s" % label)
		_render_actions()
	else:
		_append_log("Could not send: %s" % label)

func _append_log(message: String) -> void:
	if log_view != null:
		log_view.append_text(message + "\n")

func _trigger_flash(color: Color = Color(1.0, 1.0, 1.0, 0.82)) -> void:
	if flash_overlay == null:
		return
	flash_overlay.visible = true
	flash_overlay.color = color
	var tween := create_tween()
	tween.tween_property(flash_overlay, "color", Color(color.r, color.g, color.b, 0.0), 0.22)
	tween.tween_callback(func() -> void:
		if flash_overlay != null:
			flash_overlay.visible = false
	)

func _sprite_for_entity(entity_id: int) -> TextureRect:
	if entity_id <= 0:
		return null
	for party_key in ["player_party", "opponent_party"]:
		var party_value: Variant = state.get(party_key, [])
		if not party_value is Array:
			continue
		for mon_value in party_value as Array:
			if mon_value is Dictionary and int((mon_value as Dictionary).get("entity_id", 0)) == entity_id:
				return player_sprite if party_key == "player_party" else opponent_sprite
	return null

func _entity_in_party(entity_id: int, party_key: String) -> bool:
	if entity_id <= 0:
		return false
	var party_value: Variant = state.get(party_key, [])
	if not party_value is Array:
		return false
	for mon_value in party_value as Array:
		if mon_value is Dictionary and int((mon_value as Dictionary).get("entity_id", 0)) == entity_id:
			return true
	return false

func _battle_entity_name(entity_id: int) -> String:
	for party_key in ["player_party", "opponent_party"]:
		var party_value: Variant = state.get(party_key, [])
		if not party_value is Array:
			continue
		for mon_value in party_value as Array:
			if mon_value is Dictionary and int((mon_value as Dictionary).get("entity_id", 0)) == entity_id:
				return _battle_mon_name(mon_value as Dictionary, party_key == "opponent_party")
	return "Pokemon"

func _animate_move(event: Dictionary) -> void:
	var source_entity: int = int(event.get("source_entity", 0))
	var attacker: TextureRect = _sprite_for_entity(source_entity)
	if attacker == null:
		attacker = player_sprite if _entity_in_party(source_entity, "player_party") else opponent_sprite
	var target_entity: int = 0
	var targets: Variant = event.get("targets", [])
	if targets is Array:
		for target_value in targets as Array:
			if target_value is Dictionary:
				target_entity = int((target_value as Dictionary).get("entity_id", 0))
				if target_entity > 0:
					break
	var defender: TextureRect = _sprite_for_entity(target_entity)
	if defender == null or defender == attacker:
		defender = opponent_sprite if attacker == player_sprite else player_sprite
	if attacker == null or defender == null:
		return
	if move_tween != null:
		move_tween.kill()
	attacker.modulate = Color.WHITE
	defender.modulate = Color.WHITE
	var base_position: Vector2 = attacker.position
	var direction: float = signf(defender.position.x - attacker.position.x)
	if is_zero_approx(direction):
		direction = 1.0 if attacker == player_sprite else -1.0
	var move_id: int = int(event.get("source_move", event.get("move_id", 0)))
	move_tween = create_tween()
	move_tween.tween_property(attacker, "position", base_position + Vector2(72.0 * direction, -4.0), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	move_tween.tween_callback(_spawn_move_effect.bind(defender, move_id))
	move_tween.tween_callback(_blink_sprite.bind(defender))
	move_tween.tween_interval(0.12)
	move_tween.tween_property(attacker, "position", base_position, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	move_tween.tween_callback(_finish_move_animation.bind(attacker, base_position, defender, event))

func _blink_sprite(sprite: TextureRect) -> void:
	if sprite == null:
		return
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1.0, 0.45, 0.45, 1.0), 0.05)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.08)

func _finish_move_animation(attacker: TextureRect, base_position: Vector2, defender: TextureRect, event: Dictionary) -> void:
	if attacker != null:
		attacker.position = base_position
	var targets: Variant = event.get("targets", [])
	if not targets is Array or defender == null:
		return
	for target_value in targets as Array:
		if not target_value is Dictionary:
			continue
		for event_value in (target_value as Dictionary).get("events", []):
			if event_value is Dictionary and bool((event_value as Dictionary).get("faint", false)):
				var fade: Tween = create_tween()
				fade.tween_property(defender, "modulate", Color(1.0, 1.0, 1.0, 0.25), 0.28)
				fade.parallel().tween_property(defender, "position", defender.position + Vector2(0.0, 18.0), 0.28)
				return

func _spawn_move_effect(target: TextureRect, move_id: int) -> void:
	if target == null or effects_layer == null:
		return
	var info: Dictionary = GameState.content.battle_move_info(move_id) if GameState.content != null else {}
	var color: Color = _move_type_color(int(info.get("type", -1)))
	var center: Vector2 = target.position + target.size * 0.5
	var burst: ColorRect = ColorRect.new()
	burst.color = Color(color.r, color.g, color.b, 0.9)
	burst.size = Vector2(18.0, 18.0)
	burst.position = center - burst.size * 0.5
	burst.pivot_offset = burst.size * 0.5
	burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effects_layer.add_child(burst)
	var burst_tween: Tween = create_tween()
	burst_tween.tween_property(burst, "scale", Vector2(2.5, 2.5), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	burst_tween.parallel().tween_property(burst, "modulate", Color(color.r, color.g, color.b, 0.0), 0.28)
	burst_tween.tween_callback(burst.queue_free)
	var particle_count: int = 8 if int(info.get("power", 0)) > 0 else 5
	for index in range(particle_count):
		var particle: ColorRect = ColorRect.new()
		particle.color = Color(color.r, color.g, color.b, 0.95)
		particle.size = Vector2(5.0, 5.0)
		particle.position = center - particle.size * 0.5
		particle.pivot_offset = particle.size * 0.5
		particle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		effects_layer.add_child(particle)
		var angle: float = TAU * float(index) / float(particle_count)
		var distance: float = 24.0 + float(index % 3) * 9.0
		var particle_tween: Tween = create_tween()
		particle_tween.tween_property(particle, "position", center + Vector2(cos(angle), sin(angle)) * distance - particle.size * 0.5, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		particle_tween.parallel().tween_property(particle, "modulate", Color(color.r, color.g, color.b, 0.0), 0.3)
		particle_tween.tween_callback(particle.queue_free)

func _move_type_color(move_type: int) -> Color:
	match move_type:
		1: return Color("c878e8")
		2: return Color("a8c8f8")
		3: return Color("b878d8")
		4: return Color("d8b060")
		5: return Color("b8a078")
		6: return Color("a8c858")
		7: return Color("8878c8")
		8: return Color("a8b8c8")
		10: return Color("f07838")
		11: return Color("58a8e8")
		12: return Color("68c878")
		13: return Color("f0d050")
		14: return Color("e878a8")
		15: return Color("78d8e8")
		16: return Color("7888e8")
		17: return Color("786078")
	return Color("f0f0f0")

func _reset_battle_sprite_visuals() -> void:
	if move_tween != null:
		move_tween.kill()
	if player_sprite != null:
		player_sprite.modulate = Color.WHITE
	if opponent_sprite != null:
		opponent_sprite.modulate = Color.WHITE

func _on_battle_event(value: Dictionary) -> void:
	var event_type: String = str(value.get("type", "update"))
	var event_state: Variant = value.get("state", null)
	var move_event: Dictionary = {}
	if event_state is Dictionary:
		state = (event_state as Dictionary).duplicate(true)
	else:
		state = GameState.battle_state.duplicate(true)
	match event_type:
		"field_state":
			input_locked = true
			_reset_battle_sprite_visuals()
			_append_log("A battle started.")
			_trigger_flash()
		"queued_event":
			input_locked = not bool(value.get("event", {}).get("prompt", false))
			if not input_locked:
				_append_log("Choose your next action.")
		"move_event":
			input_locked = true
			var event_value: Variant = value.get("event", {})
			move_event = event_value as Dictionary if event_value is Dictionary else {}
			var move_id: int = int(move_event.get("source_move", move_event.get("move_id", 0)))
			var move_name: String = GameState.content.battle_move_name(move_id) if move_id > 0 and GameState.content != null else "Move"
			_append_log("%s used %s!" % [_battle_entity_name(int(move_event.get("source_entity", 0))), move_name])
			_trigger_flash(Color(1.0, 0.86, 0.58, 0.32))
		"switch_in":
			input_locked = true
			_reset_battle_sprite_visuals()
			_trigger_flash(Color(0.72, 0.86, 1.0, 0.42))
		"battle_end":
			input_locked = true
			selection_mode = ""
			_append_log("Battle complete.")
		"start_scene":
			_reset_battle_sprite_visuals()
			_append_log("Battle scene initialized.")
			_trigger_flash(Color(1.0, 1.0, 1.0, 0.72))
	_render_state()
	if not move_event.is_empty():
		_animate_move(move_event)
