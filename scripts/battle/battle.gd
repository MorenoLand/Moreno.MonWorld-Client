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
	var stage := PanelContainer.new()
	stage.set_anchors_preset(Control.PRESET_CENTER)
	stage.offset_left = -500.0
	stage.offset_top = -280.0
	stage.offset_right = 500.0
	stage.offset_bottom = 280.0
	stage.mouse_filter = Control.MOUSE_FILTER_STOP
	stage.add_theme_stylebox_override("panel", _panel_style(Color(0.04, 0.07, 0.11, 0.82), Color("7186a2"), 12, 2))
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
	state_label.position = Vector2(28.0, 48.0)
	state_label.size = Vector2(620.0, 28.0)
	state_label.add_theme_font_size_override("font_size", 14)
	state_label.add_theme_color_override("font_color", Color("c8d7e8"))
	stage_root.add_child(state_label)
	var opponent_card := _make_mon_card(true)
	opponent_card.position = Vector2(32.0, 86.0)
	opponent_card.size = Vector2(330.0, 106.0)
	stage_root.add_child(opponent_card)
	var player_card := _make_mon_card(false)
	player_card.position = Vector2(32.0, 350.0)
	player_card.size = Vector2(380.0, 112.0)
	stage_root.add_child(player_card)
	opponent_sprite = _make_sprite()
	opponent_sprite.position = Vector2(600.0, 58.0)
	opponent_sprite.size = Vector2(250.0, 220.0)
	stage_root.add_child(opponent_sprite)
	player_sprite = _make_sprite()
	player_sprite.position = Vector2(125.0, 176.0)
	player_sprite.size = Vector2(260.0, 220.0)
	stage_root.add_child(player_sprite)
	var log_panel := PanelContainer.new()
	log_panel.position = Vector2(420.0, 350.0)
	log_panel.size = Vector2(220.0, 112.0)
	log_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.04, 0.07, 0.72), Color("536a84"), 8, 1))
	stage_root.add_child(log_panel)
	log_view = RichTextLabel.new()
	log_view.bbcode_enabled = false
	log_view.fit_content = false
	log_view.scroll_active = false
	log_view.custom_minimum_size = Vector2(0.0, 110.0)
	log_view.add_theme_font_size_override("normal_font_size", 13)
	log_panel.add_child(log_view)
	var action_panel := PanelContainer.new()
	action_panel.position = Vector2(652.0, 350.0)
	action_panel.size = Vector2(316.0, 112.0)
	action_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.04, 0.07, 0.94), Color("7186a2"), 8, 1))
	stage_root.add_child(action_panel)
	action_box = VBoxContainer.new()
	action_box.add_theme_constant_override("separation", 5)
	action_panel.add_child(action_box)
	close_button = _make_button("Return to world")
	close_button.position = Vector2(818.0, 20.0)
	close_button.size = Vector2(150.0, 34.0)
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
	_update_mon_card(opponent_name_label, opponent_level_label, opponent_hp_bar, opponent_hp_label, opponent)
	_update_mon_card(player_name_label, player_level_label, player_hp_bar, player_hp_label, player)
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

func _update_mon_card(name_label: Label, level_label: Label, hp_bar: ProgressBar, hp_label: Label, mon: Dictionary) -> void:
	var level: int = int(mon.get("level", 0))
	level_label.text = "Lv %d" % level if level > 0 else ""
	var current_hp: int = int(mon.get("current_hp", mon.get("hp", 0)))
	var max_hp: int = int(mon.get("max_hp", mon.get("hp_max", 0)))
	if max_hp <= 0:
		max_hp = maxi(current_hp, 1)
	hp_bar.max_value = max_hp
	hp_bar.value = clampi(current_hp, 0, max_hp)
	hp_label.text = "%d / %d HP" % [clampi(current_hp, 0, max_hp), max_hp] if current_hp > 0 or int(mon.get("max_hp", 0)) > 0 else "HP unavailable"
	name_label.text = _battle_mon_name(mon, name_label == opponent_name_label)

func _update_sprite(sprite: TextureRect, mon: Dictionary, back: bool) -> void:
	var species_id: int = int(mon.get("species", mon.get("dex_id", 0)))
	sprite.texture = null
	if GameState.content == null or species_id <= 0:
		return
	var result: Dictionary = GameState.content.battle_pokemon_sprite(species_id, back)
	if bool(result.get("ok", false)):
		sprite.texture = result.get("texture") as Texture2D

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
	var resolved_name: String = str(mon.get("nickname", mon.get("name", ""))).strip_edges()
	if not resolved_name.is_empty():
		return resolved_name
	var resolved_species: int = int(mon.get("species", mon.get("dex_id", 0)))
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
			button.text = str(entry[0])
			button.custom_minimum_size = Vector2(120, 38)
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
		button.text = GameState.content.battle_move_name(move_id) if GameState.content != null else "MOVE #%d" % move_id
		button.custom_minimum_size = Vector2(140, 38)
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
			button.text = _battle_mon_name(mon, false)
			button.custom_minimum_size = Vector2(140, 38)
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

func _on_battle_event(value: Dictionary) -> void:
	var event_type: String = str(value.get("type", "update"))
	var event_state: Variant = value.get("state", null)
	if event_state is Dictionary:
		state = (event_state as Dictionary).duplicate(true)
	else:
		state = GameState.battle_state.duplicate(true)
	match event_type:
		"field_state":
			input_locked = true
			_append_log("A battle started.")
			_trigger_flash()
		"queued_event":
			input_locked = not bool(value.get("event", {}).get("prompt", false))
			if not input_locked:
				_append_log("Choose your next action.")
		"move_event":
			input_locked = true
			var move_id: int = int(value.get("event", {}).get("source_move", value.get("event", {}).get("move_id", 0)))
			_append_log("A move was resolved: %s." % (GameState.content.battle_move_name(move_id) if move_id > 0 and GameState.content != null else "Move"))
			_trigger_flash(Color(1.0, 0.86, 0.58, 0.5))
		"switch_in":
			input_locked = true
			_trigger_flash(Color(0.72, 0.86, 1.0, 0.42))
		"battle_end":
			input_locked = true
			selection_mode = ""
			_append_log("Battle complete.")
		"start_scene":
			_append_log("Battle scene initialized.")
			_trigger_flash(Color(1.0, 1.0, 1.0, 0.72))
	_render_state()
