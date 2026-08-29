extends Control

signal exit_requested

var log_view: RichTextLabel
var state_label: Label
var action_box: VBoxContainer
var player_party_box: VBoxContainer
var opponent_party_box: VBoxContainer
var state: Dictionary = {}
var selection_mode: String = ""
var input_locked: bool = true

func _ready() -> void:
	if not GameState.battle_event_received.is_connected(_on_battle_event):
		GameState.battle_event_received.connect(_on_battle_event)
	_build_ui()
	state = GameState.battle_state.duplicate(true)
	_render_state()

func _exit_tree() -> void:
	if GameState.battle_event_received.is_connected(_on_battle_event):
		GameState.battle_event_received.disconnect(_on_battle_event)

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("0b1018")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	move_child(background, 0)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	var title := Label.new()
	title.text = "BATTLE"
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)
	state_label = Label.new()
	state_label.text = "Waiting for battle state..."
	state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(state_label)
	var parties := HBoxContainer.new()
	parties.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parties.add_theme_constant_override("separation", 24)
	box.add_child(parties)
	var opponent_panel := PanelContainer.new()
	opponent_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opponent_party_box = VBoxContainer.new()
	opponent_party_box.add_theme_constant_override("separation", 6)
	opponent_panel.add_child(opponent_party_box)
	parties.add_child(opponent_panel)
	var player_panel := PanelContainer.new()
	player_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_party_box = VBoxContainer.new()
	player_party_box.add_theme_constant_override("separation", 6)
	player_panel.add_child(player_party_box)
	parties.add_child(player_panel)
	log_view = RichTextLabel.new()
	log_view.custom_minimum_size = Vector2(0, 120)
	log_view.scroll_active = true
	box.add_child(log_view)
	var action_panel := PanelContainer.new()
	box.add_child(action_panel)
	action_box = VBoxContainer.new()
	action_box.add_theme_constant_override("separation", 8)
	action_panel.add_child(action_box)
	var back := Button.new()
	back.text = "Return to world"
	back.pressed.connect(_return_to_world)
	box.add_child(back)

func _return_to_world() -> void:
	if not bool(state.get("battle_complete", false)):
		return
	exit_requested.emit()

func _render_state() -> void:
	if state.is_empty():
		state_label.text = "Waiting for server battle state..."
		_render_actions()
		return
	var opponent_name: String = str(state.get("opponent_name", "Opponent"))
	if opponent_name.is_empty():
		opponent_name = "Opponent"
	var player_name: String = str(state.get("player_name", "Player"))
	if player_name.is_empty():
		player_name = "Player"
	var phase: String = "complete" if bool(state.get("battle_complete", false)) else "active"
	state_label.text = "%s  |  %s vs %s  |  %s" % [phase.capitalize(), opponent_name, player_name, "Choose an action" if bool(state.get("can_act", false)) else "Waiting for server"]
	_render_party(opponent_party_box, state.get("opponent_party", []), int(state.get("opponent_active_slot", -1)), true)
	_render_party(player_party_box, state.get("player_party", []), int(state.get("active_slot", -1)), false)
	_render_actions()

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
	var name: String = str(mon.get("nickname", mon.get("name", "")))
	if not name.is_empty():
		return name
	if not bool(mon.get("revealed", true)):
		return "Unknown Pokémon"
	var species: int = int(mon.get("species", 0))
	return "Pokémon #%d" % species if species > 0 else ("Opponent Pokémon" if opponent else "Pokémon")

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
		var buttons := HBoxContainer.new()
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
		button.text = "Move #%d" % move_id
		button.custom_minimum_size = Vector2(180, 38)
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
			button.custom_minimum_size = Vector2(180, 38)
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
	_send_battle_action(0, move_id, "Move #%d" % move_id)

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
		"queued_event":
			input_locked = not bool(value.get("event", {}).get("prompt", false))
			if not input_locked:
				_append_log("Choose your next action.")
		"move_event":
			input_locked = true
			_append_log("A move was resolved.")
		"switch_in":
			input_locked = true
		"battle_end":
			input_locked = true
			selection_mode = ""
			_append_log("Battle complete.")
		"start_scene":
			_append_log("Battle scene initialized.")
	_render_state()

func _on_battle_event(value: Dictionary) -> void:
	if str(value.get("battle_id", "")) != battle_id:
		return
	state_label.text = "Turn %s · active side %s" % [value.get("turn", "?"), value.get("active_side", "?")]
	log_view.append_text("event: %s\n" % str(value.get("event", "update")))
