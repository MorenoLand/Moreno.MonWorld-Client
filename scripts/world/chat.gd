class_name OpenMMOChat
extends PanelContainer

signal message_submitted(text: String, channel: String)

const CHANNELS: Array[String] = ["Local", "Global", "Trade", "Whispers", "Battle"]
const CHAT_WIDTH: float = 420.0
const CHAT_HEIGHT: float = 190.0
const MAX_MESSAGES: int = 250

var chat_log: RichTextLabel
var chat_input: LineEdit
var channel_select: OptionButton
var tabs: Dictionary = {}
var messages: Array[Dictionary] = []
var selected_tab: String = "Local"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(CHAT_WIDTH, CHAT_HEIGHT)
	add_theme_stylebox_override("panel", _panel_style())
	_build_ui()

func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	add_child(root)
	var tab_bar := HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 2)
	root.add_child(tab_bar)
	var button_group := ButtonGroup.new()
	for channel in CHANNELS:
		var tab := Button.new()
		tab.text = channel
		tab.flat = true
		tab.toggle_mode = true
		tab.button_group = button_group
		tab.focus_mode = Control.FOCUS_NONE
		tab.pressed.connect(_select_tab.bind(channel))
		tab_bar.add_child(tab)
		tabs[channel] = tab
	var separator := HSeparator.new()
	root.add_child(separator)
	chat_log = RichTextLabel.new()
	chat_log.bbcode_enabled = false
	chat_log.fit_content = false
	chat_log.scroll_active = true
	chat_log.scroll_following = true
	chat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chat_log.add_theme_font_size_override("normal_font_size", 14)
	root.add_child(chat_log)
	var composer := HBoxContainer.new()
	composer.add_theme_constant_override("separation", 4)
	root.add_child(composer)
	channel_select = OptionButton.new()
	channel_select.custom_minimum_size = Vector2(78, 30)
	channel_select.focus_mode = Control.FOCUS_NONE
	channel_select.add_item("Normal")
	composer.add_child(channel_select)
	chat_input = LineEdit.new()
	chat_input.placeholder_text = "Type a message..."
	chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_input.custom_minimum_size.y = 30
	chat_input.text_submitted.connect(_submit)
	composer.add_child(chat_input)
	var send_button := Button.new()
	send_button.text = "Send"
	send_button.custom_minimum_size = Vector2(54, 30)
	send_button.pressed.connect(_submit_button)
	composer.add_child(send_button)
	_select_tab("Local")

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.04, 0.06, 0.90)
	style.border_color = Color(0.28, 0.40, 0.54, 0.85)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _select_tab(channel: String) -> void:
	if not CHANNELS.has(channel):
		return
	selected_tab = channel
	for name in tabs:
		var tab: Button = tabs[name]
		tab.modulate = Color(0.76, 0.86, 1.0) if name == selected_tab else Color(0.58, 0.65, 0.75)
	var selected: Button = tabs.get(selected_tab)
	if selected != null and not selected.button_pressed:
		selected.button_pressed = true
	_refresh_log()

func add_message(value: Dictionary) -> void:
	var message := value.duplicate(true)
	message["channel"] = _normalize_channel(str(message.get("channel", message.get("type", "Local"))))
	if not message.has("text"):
		message["text"] = message.get("message", "")
	messages.append(message)
	while messages.size() > MAX_MESSAGES:
		messages.pop_front()
	_refresh_log()

func _normalize_channel(value: String) -> String:
	match value.to_lower():
		"global":
			return "Global"
		"trade":
			return "Trade"
		"whisper", "whispers", "private":
			return "Whispers"
		"battle":
			return "Battle"
	return "Local"

func _refresh_log() -> void:
	if chat_log == null:
		return
	chat_log.clear()
	for message in messages:
		if str(message.get("channel", "Local")) != selected_tab:
			continue
		var name := str(message.get("name", message.get("sender", "Player")))
		var text := str(message.get("text", ""))
		if bool(message.get("system", false)):
			chat_log.append_text("[System] %s\n" % text)
		else:
			chat_log.append_text("%s: %s\n" % [name, text])
	if chat_log.get_line_count() > 0:
		chat_log.scroll_to_line(chat_log.get_line_count() - 1)

func _submit(value: String) -> void:
	var text := value.strip_edges()
	if text.is_empty():
		return
	var channel := str(channel_select.get_item_text(channel_select.selected))
	message_submitted.emit(text, channel)

func clear_input() -> void:
	if chat_input != null:
		chat_input.clear()

func focus_input(prefix: String = "") -> void:
	if chat_input != null:
		chat_input.grab_focus()
		if not prefix.is_empty() and chat_input.text.is_empty():
			chat_input.text = prefix
			chat_input.caret_column = chat_input.text.length()

func _submit_button() -> void:
	if chat_input != null:
		_submit(chat_input.text)

func input_focused() -> bool:
	return chat_input != null and get_viewport().gui_get_focus_owner() == chat_input
