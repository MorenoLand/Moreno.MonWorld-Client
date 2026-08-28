class_name OpenMMOHud
extends Control

const PARTY_COUNT: int = 6
const STATS_UPDATE_INTERVAL: float = 0.25
var location_label: Label
var money_label: Label
var time_label: Label
var stats_panel: PanelContainer
var stats_label: Label
var party_box: VBoxContainer
var party_labels: Array = []
var action_bar: HBoxContainer
var bag_panel: PanelContainer
var menu_panel: PanelContainer
var bag_label: Label
var current_content
var current_map_id: String = ""
var current_state: Dictionary = {}
var current_party: Array = []
var clock_elapsed: float = 0.0
var stats_elapsed: float = 0.0
var stats_open: bool = true
var bag_open: bool = false
var menu_open: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_ui()
	_refresh()
	_refresh_stats()

func set_state(content, map_id: String, state: Dictionary = {}, party: Array = []) -> void:
	current_content = content
	current_map_id = map_id
	current_state = state
	current_party = party
	_refresh()

func _build_ui() -> void:
	var info_panel: PanelContainer = PanelContainer.new()
	info_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	info_panel.offset_left = 16.0
	info_panel.offset_top = 16.0
	info_panel.offset_right = 266.0
	info_panel.offset_bottom = 104.0
	info_panel.add_theme_stylebox_override("panel", _panel_style(Color("10151ed9"), Color("5f7185")))
	add_child(info_panel)
	var info_box: VBoxContainer = VBoxContainer.new()
	info_box.add_theme_constant_override("separation", 1)
	info_panel.add_child(info_box)
	location_label = Label.new()
	location_label.add_theme_font_size_override("font_size", 16)
	info_box.add_child(location_label)
	money_label = Label.new()
	money_label.add_theme_font_size_override("font_size", 14)
	info_box.add_child(money_label)
	time_label = Label.new()
	time_label.add_theme_font_size_override("font_size", 14)
	info_box.add_child(time_label)
	party_box = VBoxContainer.new()
	party_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	party_box.offset_left = -136.0
	party_box.offset_top = 100.0
	party_box.offset_right = -16.0
	party_box.add_theme_constant_override("separation", 5)
	party_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(party_box)
	for index in range(PARTY_COUNT):
		var slot: PanelContainer = PanelContainer.new()
		slot.custom_minimum_size = Vector2(120.0, 44.0)
		slot.add_theme_stylebox_override("panel", _panel_style(Color("10151eb8"), Color("5f7185")))
		var label: Label = Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 12)
		slot.add_child(label)
		party_labels.append(label)
		party_box.add_child(slot)
	stats_panel = PanelContainer.new()
	stats_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	stats_panel.offset_left = -196.0
	stats_panel.offset_top = 16.0
	stats_panel.offset_right = -16.0
	stats_panel.offset_bottom = 88.0
	stats_panel.add_theme_stylebox_override("panel", _panel_style(Color("10151ed9"), Color("5f7185")))
	add_child(stats_panel)
	stats_label = Label.new()
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stats_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stats_label.add_theme_font_size_override("font_size", 13)
	stats_panel.add_child(stats_label)
	action_bar = HBoxContainer.new()
	action_bar.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	action_bar.offset_left = -176.0
	action_bar.offset_top = -58.0
	action_bar.offset_right = -16.0
	action_bar.offset_bottom = -16.0
	action_bar.add_theme_constant_override("separation", 6)
	action_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(action_bar)
	var bag_button: Button = _make_button("Bag")
	bag_button.pressed.connect(toggle_bag)
	action_bar.add_child(bag_button)
	var menu_button: Button = _make_button("Menu")
	menu_button.pressed.connect(toggle_menu)
	action_bar.add_child(menu_button)
	bag_panel = _make_popup_panel("Bag")
	bag_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	bag_panel.offset_left = -300.0
	bag_panel.offset_top = -360.0
	bag_panel.offset_right = -16.0
	bag_panel.offset_bottom = -72.0
	add_child(bag_panel)
	var bag_box: VBoxContainer = bag_panel.get_child(0) as VBoxContainer
	bag_label = Label.new()
	bag_label.custom_minimum_size = Vector2(260.0, 190.0)
	bag_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	bag_label.add_theme_font_size_override("font_size", 14)
	bag_label.text = "No items available."
	bag_box.add_child(bag_label)
	var bag_close: Button = _make_button("Close")
	bag_close.pressed.connect(toggle_bag)
	bag_box.add_child(bag_close)
	menu_panel = _make_popup_panel("Menu")
	menu_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	menu_panel.offset_left = -220.0
	menu_panel.offset_top = -250.0
	menu_panel.offset_right = -16.0
	menu_panel.offset_bottom = -72.0
	add_child(menu_panel)
	var menu_box: VBoxContainer = menu_panel.get_child(0) as VBoxContainer
	var party_button: Button = _make_button("Party")
	party_button.pressed.connect(_on_party_pressed)
	menu_box.add_child(party_button)
	var menu_bag_button: Button = _make_button("Bag")
	menu_bag_button.pressed.connect(toggle_bag)
	menu_box.add_child(menu_bag_button)
	var menu_close: Button = _make_button("Close")
	menu_close.pressed.connect(toggle_menu)
	menu_box.add_child(menu_close)
	_refresh_panels()

func _make_button(text_value: String) -> Button:
	var button: Button = Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(85.0, 38.0)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_stylebox_override("normal", _panel_style(Color("182231e8"), Color("5f7185")))
	button.add_theme_stylebox_override("hover", _panel_style(Color("26364ce8"), Color("82a8d3")))
	button.add_theme_stylebox_override("pressed", _panel_style(Color("314b6be8"), Color("a7c8ed")))
	return button

func _make_popup_panel(title_value: String) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.z_index = 10
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _panel_style(Color("10151ef2"), Color("5f7185")))
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var title: Label = Label.new()
	title.text = title_value
	title.add_theme_font_size_override("font_size", 17)
	box.add_child(title)
	return panel

func _panel_style(background: Color, border: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 8.0
	style.content_margin_top = 6.0
	style.content_margin_right = 8.0
	style.content_margin_bottom = 6.0
	return style

func _process(delta: float) -> void:
	clock_elapsed += delta
	stats_elapsed += delta
	if clock_elapsed >= 1.0:
		clock_elapsed = 0.0
		_refresh_time()
	if stats_elapsed >= STATS_UPDATE_INTERVAL:
		stats_elapsed = 0.0
		_refresh_stats()

func toggle_stats() -> void:
	stats_open = not stats_open
	if stats_panel != null:
		stats_panel.visible = stats_open

func toggle_bag() -> void:
	bag_open = not bag_open
	if bag_open:
		menu_open = false
	_refresh_panels()

func toggle_menu() -> void:
	menu_open = not menu_open
	if menu_open:
		bag_open = false
	_refresh_panels()

func _on_party_pressed() -> void:
	menu_open = false
	if party_box != null:
		party_box.visible = true
	_refresh_panels()

func _refresh_panels() -> void:
	if bag_panel != null:
		bag_panel.visible = bag_open
	if menu_panel != null:
		menu_panel.visible = menu_open

func _refresh_bag() -> void:
	if bag_label == null:
		return
	var items: Variant = current_state.get("bag", current_state.get("inventory", current_state.get("items", [])))
	var lines: Array[String] = []
	if items is Array:
		for item_value in items:
			if not item_value is Dictionary:
				continue
			var item: Dictionary = item_value
			var item_name: String = str(item.get("name", item.get("item_name", "Item"))).strip_edges()
			var quantity: int = int(item.get("quantity", item.get("count", 1)))
			lines.append("%s  x%d" % [item_name if not item_name.is_empty() else "Item", quantity])
	elif items is Dictionary:
		for item_key in items.keys():
			var item_value: Variant = items[item_key]
			if item_value is Dictionary:
				var item: Dictionary = item_value
				var item_name: String = str(item.get("name", item.get("item_name", item_key))).strip_edges()
				var quantity: int = int(item.get("quantity", item.get("count", 1)))
				lines.append("%s  x%d" % [item_name if not item_name.is_empty() else str(item_key), quantity])
			else:
				lines.append("%s  x%d" % [str(item_key), int(item_value)])
	bag_label.text = "\n".join(lines) if not lines.is_empty() else "No items available."

func _refresh_stats() -> void:
	if stats_label == null:
		return
	var fps: int = Engine.get_frames_per_second()
	var process_ms: float = float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0
	stats_label.text = "FPS %d\nFrame %.1f ms" % [fps, process_ms]

func _refresh() -> void:
	if location_label == null:
		return
	var map_name: String = current_map_id
	if current_content != null and not current_map_id.is_empty():
		var map_value: Dictionary = current_content.map_data(current_map_id)
		map_name = str(map_value.get("name", current_map_id))
	var channel: String = str(current_state.get("channel", current_state.get("channel_id", 1)))
	location_label.text = "%s  Ch. %s" % [map_name.to_upper(), channel]
	var money_value: int = int(current_state.get("money", current_state.get("currency", 0)))
	money_label.text = "$%s" % _format_money(money_value)
	_refresh_time()
	for index in range(party_labels.size()):
		var party_label: Label = party_labels[index] as Label
		var member: Variant = current_party[index] if index < current_party.size() else {}
		party_label.text = _party_slot_text(member as Dictionary) if member is Dictionary else ""
	_refresh_bag()

func _refresh_time() -> void:
	if time_label == null:
		return
	var now: Dictionary = Time.get_datetime_dict_from_system()
	var weekdays: Array = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
	var weekday: String = str(weekdays[clampi(int(now.get("weekday", 0)), 0, weekdays.size() - 1)])
	time_label.text = "%s, %02d:%02d" % [weekday, int(now.get("hour", 0)), int(now.get("minute", 0))]

func _format_money(value: int) -> String:
	var negative: bool = value < 0
	var digits: String = str(absi(value))
	var formatted: String = ""
	while digits.length() > 3:
		formatted = "," + digits.substr(digits.length() - 3) + formatted
		digits = digits.substr(0, digits.length() - 3)
	formatted = digits + formatted
	return "-" + formatted if negative else formatted

func _party_slot_text(member: Dictionary) -> String:
	var dex_id: int = int(member.get("dex_id", 0))
	if dex_id <= 0:
		return ""
	var nickname: String = str(member.get("nickname", "")).strip_edges()
	if nickname.is_empty():
		nickname = "#%03d" % dex_id
	return "%s\nLv %d" % [nickname.left(7), int(member.get("level", 0))]
