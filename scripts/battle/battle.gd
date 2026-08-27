extends Control

signal exit_requested

var log_view: RichTextLabel
var state_label: Label
var battle_id := "foundation-1v1"

func _ready() -> void:
	GameState.battle_event_received.connect(_on_battle_event)
	_build_ui()

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("171522")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	move_child(background, 0)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(720, 420)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var title := Label.new()
	title.text = "Battle foundation"
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)
	state_label = Label.new()
	state_label.text = "Server-authoritative 1v1 session model; participants are represented as sides and slots."
	state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(state_label)
	log_view = RichTextLabel.new()
	log_view.custom_minimum_size = Vector2(0, 180)
	box.add_child(log_view)
	var actions := HBoxContainer.new()
	for action in ["primary", "secondary", "pass"]:
		var button := Button.new()
		button.text = action.capitalize()
		button.pressed.connect(_send_action.bind(action))
		actions.add_child(button)
	box.add_child(actions)
	var back := Button.new()
	back.text = "Return to world"
	back.pressed.connect(func(): exit_requested.emit())
	box.add_child(back)

func _send_action(action: String) -> void:
	if GameState.send_battle_action(battle_id, action):
		log_view.append_text("sent: %s\n" % action)

func _on_battle_event(value: Dictionary) -> void:
	if str(value.get("battle_id", "")) != battle_id:
		return
	state_label.text = "Turn %s · active side %s" % [value.get("turn", "?"), value.get("active_side", "?")]
	log_view.append_text("event: %s\n" % str(value.get("event", "update")))
