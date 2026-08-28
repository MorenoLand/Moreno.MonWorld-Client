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
var action_panel: PanelContainer
var hotbar_panel: PanelContainer
var hotkey_slots: Array = []
var hotkey_selected: int = -1
var bag_panel: PanelContainer
var menu_panel: PanelContainer
var bag_label: Label
var bag_tab_buttons: Array = []
var bag_category: String = "Items"
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
	party_box.offset_left = -88.0
	party_box.offset_top = 100.0
	party_box.offset_right = -16.0
	party_box.custom_minimum_size = Vector2(72.0, 0.0)
	party_box.add_theme_constant_override("separation", 5)
	party_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(party_box)
	var party_title: Label = Label.new()
	party_title.text = "PARTY"
	party_title.add_theme_font_size_override("font_size", 11)
	party_title.add_theme_color_override("font_color", Color("b8cbe0"))
	party_box.add_child(party_title)
	for index in range(PARTY_COUNT):
		var slot: PanelContainer = PanelContainer.new()
		slot.custom_minimum_size = Vector2(72.0, 52.0)
		slot.add_theme_stylebox_override("panel", _panel_style(Color("10151eb8"), Color("5f7185")))
		var label: Label = Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 10)
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
	action_panel = PanelContainer.new()
	action_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	action_panel.offset_left = -286.0
	action_panel.offset_top = -64.0
	action_panel.offset_right = -16.0
	action_panel.offset_bottom = -16.0
	action_panel.z_index = 5
	action_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	action_panel.add_theme_stylebox_override("panel", _panel_style(Color("0b1420e8"), Color("5d7288")))
	add_child(action_panel)
	action_bar = HBoxContainer.new()
	action_bar.add_theme_constant_override("separation", 5)
	action_panel.add_child(action_bar)
	var bag_button: Button = _make_button("Bag")
	bag_button.custom_minimum_size = Vector2(78.0, 42.0)
	bag_button.pressed.connect(toggle_bag)
	action_bar.add_child(bag_button)
	var party_action_button: Button = _make_button("Party")
	party_action_button.custom_minimum_size = Vector2(78.0, 42.0)
	party_action_button.pressed.connect(_on_party_pressed)
	action_bar.add_child(party_action_button)
	var menu_button: Button = _make_button("Menu")
	menu_button.custom_minimum_size = Vector2(78.0, 42.0)
	menu_button.pressed.connect(toggle_menu)
	action_bar.add_child(menu_button)
	hotbar_panel = PanelContainer.new()
	hotbar_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	hotbar_panel.offset_left = -224.0
	hotbar_panel.offset_top = 12.0
	hotbar_panel.offset_right = 224.0
	hotbar_panel.offset_bottom = 64.0
	hotbar_panel.z_index = 5
	hotbar_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	hotbar_panel.add_theme_stylebox_override("panel", _panel_style(Color("0b1420e8"), Color("5d7288")))
	add_child(hotbar_panel)
	var hotbar: HBoxContainer = HBoxContainer.new()
	hotbar.add_theme_constant_override("separation", 4)
	hotbar_panel.add_child(hotbar)
	for index in range(9):
		var hotkey_button: Button = _make_hotkey_button(index)
		hotkey_slots.append(hotkey_button)
		hotbar.add_child(hotkey_button)
	bag_panel = _make_popup_panel("Bag")
	bag_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	bag_panel.offset_left = -300.0
	bag_panel.offset_top = -410.0
	bag_panel.offset_right = -16.0
	bag_panel.offset_bottom = -72.0
	add_child(bag_panel)
	var bag_box: VBoxContainer = bag_panel.get_child(0) as VBoxContainer
	var bag_tabs: HBoxContainer = HBoxContainer.new()
	bag_tabs.add_theme_constant_override("separation", 3)
	bag_box.add_child(bag_tabs)
	for category in ["Items", "Key", "Balls", "TMs", "Berries"]:
		var tab: Button = _make_button(category)
		tab.custom_minimum_size = Vector2(0.0, 30.0)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.add_theme_font_size_override("font_size", 11)
		tab.set_meta("bag_category", category)
		tab.pressed.connect(_select_bag_category.bind(category))
		bag_tab_buttons.append(tab)
		bag_tabs.add_child(tab)
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

func _select_bag_category(category: String) -> void:
	bag_category = category
	_refresh_bag()

func _make_hotkey_button(index: int) -> Button:
	var button: Button = _make_button("%d\n—" % (index + 1))
	button.custom_minimum_size = Vector2(44.0, 42.0)
	button.add_theme_font_size_override("font_size", 11)
	button.pressed.connect(_on_hotkey_pressed.bind(index))
	return button

func _on_hotkey_pressed(index: int) -> void:
	if index < 0 or index >= hotkey_slots.size():
		return
	hotkey_selected = index
	_refresh_hotbar()

func activate_hotkey(index: int) -> void:
	_on_hotkey_pressed(index)

func _refresh_hotbar() -> void:
	if hotkey_slots.is_empty():
		return
	var values: Variant = current_state.get("hotbar", current_state.get("hotkeys", []))
	if not values is Array:
		values = []
	for index in range(hotkey_slots.size()):
		var item_name: String = ""
		if index < (values as Array).size():
			var slot_value: Variant = (values as Array)[index]
			if slot_value is Dictionary:
				var slot: Dictionary = slot_value
				item_name = str(slot.get("name", slot.get("item_name", ""))).strip_edges()
			elif slot_value is String:
				item_name = str(slot_value).strip_edges()
		var display_name: String = item_name.left(5) if not item_name.is_empty() else "—"
		var button: Button = hotkey_slots[index] as Button
		button.text = "%d\n%s" % [index + 1, display_name]
		button.modulate = Color("9fc3ff") if index == hotkey_selected else Color.WHITE

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
	for tab_value in bag_tab_buttons:
		var tab: Button = tab_value as Button
		tab.modulate = Color("9fc3ff") if str(tab.get_meta("bag_category", "")) == bag_category else Color.WHITE
	var items: Variant = current_state.get("bag", current_state.get("inventory", current_state.get("items", [])))
	var category_container: bool = false
	if items is Dictionary:
		var item_groups: Dictionary = items
		for category_key in _bag_category_keys():
			if item_groups.has(category_key):
				items = item_groups[category_key]
				category_container = true
				break
	var lines: Array[String] = []
	if items is Array:
		for item_value in items:
			if not item_value is Dictionary:
				continue
			var item: Dictionary = item_value
			if not _bag_item_matches_category(item, category_container):
				continue
			var item_name: String = str(item.get("name", item.get("item_name", "Item"))).strip_edges()
			var quantity: int = int(item.get("quantity", item.get("count", 1)))
			lines.append("%s  x%d" % [item_name if not item_name.is_empty() else "Item", quantity])
	elif items is Dictionary:
		for item_key in items.keys():
			var item_value: Variant = items[item_key]
			if item_value is Dictionary:
				var item: Dictionary = item_value
				if not _bag_item_matches_category(item, category_container):
					continue
				var item_name: String = str(item.get("name", item.get("item_name", item_key))).strip_edges()
				var quantity: int = int(item.get("quantity", item.get("count", 1)))
				lines.append("%s  x%d" % [item_name if not item_name.is_empty() else str(item_key), quantity])
			elif bag_category == "Items":
				lines.append("%s  x%d" % [str(item_key), int(item_value)])
	bag_label.text = "\n".join(lines) if not lines.is_empty() else "No items available."

func _bag_category_keys() -> Array:
	match bag_category:
		"Key": return ["key", "key_items", "keyitems"]
		"Balls": return ["balls", "pokeballs", "poke_balls"]
		"TMs": return ["tms", "tm_hm", "tmhm"]
		"Berries": return ["berries", "berry"]
	return ["items", "item"]

func _bag_item_matches_category(item: Dictionary, category_container: bool) -> bool:
	if category_container:
		return true
	var raw_category: String = str(item.get("category", item.get("tab", ""))).strip_edges().to_lower()
	if raw_category.is_empty():
		return bag_category == "Items"
	match bag_category:
		"Key": return raw_category in ["key", "key_item", "key_items"]
		"Balls": return raw_category in ["ball", "balls", "pokeball", "pokeballs"]
		"TMs": return raw_category in ["tm", "tms", "hm", "tm_hm"]
		"Berries": return raw_category in ["berry", "berries"]
	return raw_category in ["item", "items", "medicine", "held"]

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
	_refresh_hotbar()

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
