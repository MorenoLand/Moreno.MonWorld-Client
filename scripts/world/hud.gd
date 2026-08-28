class_name MonWorldHud
extends Control

const PARTY_COUNT: int = 6
const STATS_UPDATE_INTERVAL: float = 0.25
var location_label: Label
var money_label: Label
var time_label: Label
var stats_panel: PanelContainer
var stats_label: Label
var party_labels: Array = []
var current_content: MonWorldContent
var current_map_id: String = ""
var current_state: Dictionary = {}
var current_party: Array = []
var clock_elapsed: float = 0.0
var stats_elapsed: float = 0.0
var stats_open: bool = true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    _build_ui()
    _refresh()
    _refresh_stats()

func set_state(content: MonWorldContent, map_id: String, state: Dictionary = {}, party: Array = []) -> void:
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
	var party_box: VBoxContainer = VBoxContainer.new()
	party_box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	party_box.offset_left = 16.0
	party_box.offset_top = 114.0
	party_box.offset_right = 64.0
	party_box.add_theme_constant_override("separation", 5)
	add_child(party_box)
    for index in range(PARTY_COUNT):
        var slot: PanelContainer = PanelContainer.new()
		slot.custom_minimum_size = Vector2(48.0, 48.0)
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
