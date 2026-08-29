class_name OpenMMODialogue
extends PanelContainer

signal action_requested
signal closed

const TYPE_INTERVAL: float = 1.0 / 30.0
const PANEL_HEIGHT: float = 164.0
const PANEL_WIDTH: float = 430.0
var text_label: Label
var arrow_label: Label
var current_text: String = ""
var pages: Array = []
var page_index: int = 0
var visible_count: int = 0
var type_elapsed: float = 0.0
var open_state: bool = false
var ignore_next_action: bool = false
var screen_anchor: Vector2 = Vector2(-1.0, -1.0)
var actor_anchored: bool = false
var layout_in_progress: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	offset_top = -170.0
	offset_bottom = -28.0
	resized.connect(_layout_panel)
	_layout_panel()
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	margin.add_child(box)
	text_label = Label.new()
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.clip_text = false
	text_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	text_label.add_theme_font_size_override("font_size", 20)
	text_label.custom_minimum_size = Vector2(0, 112)
	box.add_child(text_label)
	var arrow_row: HBoxContainer = HBoxContainer.new()
	arrow_row.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(arrow_row)
	arrow_label = Label.new()
	arrow_label.text = "▼"
	arrow_label.add_theme_font_size_override("font_size", 16)
	arrow_row.add_child(arrow_label)
	visible = false
	set_process(false)

func _layout_panel() -> void:
	if layout_in_progress:
		return
	layout_in_progress = true
	var viewport_size: Vector2 = get_viewport_rect().size
	var viewport_width: float = viewport_size.x
	var viewport_height: float = viewport_size.y
	if actor_anchored and screen_anchor.x >= 0.0:
		var panel_width: float = minf(PANEL_WIDTH, maxf(viewport_width - 24.0, 240.0))
		var left: float = clampf(screen_anchor.x - panel_width * 0.5, 12.0, maxf(viewport_width - panel_width - 12.0, 12.0))
		var top: float = screen_anchor.y - PANEL_HEIGHT - 12.0
		if top < 12.0:
			top = minf(screen_anchor.y + 12.0, maxf(viewport_height - PANEL_HEIGHT - 12.0, 12.0))
		set_anchors_preset(Control.PRESET_TOP_LEFT)
		offset_left = left
		offset_top = top
		offset_right = left + panel_width
		offset_bottom = top + PANEL_HEIGHT
	else:
		var bottom_panel_width: float = minf(PANEL_WIDTH, maxf(viewport_width - 24.0, 240.0))
		set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		offset_left = -bottom_panel_width * 0.5
		offset_right = bottom_panel_width * 0.5
		offset_top = -170.0
		offset_bottom = -28.0
	layout_in_progress = false

func show_text(value: String, suppress_action: bool = false) -> void:
	show_pages([value], suppress_action)

func show_pages(values: Array, suppress_action: bool = false, anchor: Vector2 = Vector2(-1.0, -1.0)) -> void:
	pages = []
	for value in values:
		var page: String = str(value)
		if not page.is_empty():
			pages.append(page)
	page_index = 0
	current_text = str(pages[0]) if not pages.is_empty() else ""
	visible_count = 0
	type_elapsed = 0.0
	open_state = not pages.is_empty()
	ignore_next_action = suppress_action and open_state
	screen_anchor = anchor
	actor_anchored = anchor.x >= 0.0 and anchor.y >= 0.0
	visible = open_state
	set_process(open_state)
	_layout_panel()
	_render()

func is_open() -> bool:
	return open_state

func text_complete() -> bool:
	return open_state and visible_count >= current_text.length()

func handle_action() -> bool:
	if not open_state:
		return false
	if visible_count < current_text.length():
		visible_count = current_text.length()
		_render()
		return true
	if page_index + 1 < pages.size():
		page_index += 1
		current_text = str(pages[page_index])
		visible_count = 0
		type_elapsed = 0.0
		set_process(true)
		_render()
		return true
	close_dialogue()
	return true

func close_dialogue() -> void:
	if not open_state:
		return
	open_state = false
	visible = false
	set_process(false)
	closed.emit()

func _process(delta: float) -> void:
	if visible_count >= current_text.length():
		set_process(false)
		_render()
		return
	type_elapsed += delta
	while type_elapsed >= TYPE_INTERVAL and visible_count < current_text.length():
		type_elapsed -= TYPE_INTERVAL
		visible_count += 1
	_render()

func _input(event: InputEvent) -> void:
	if not open_state or not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo or key_event.keycode not in [KEY_F, KEY_E, KEY_Z, KEY_X, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		return
	get_viewport().set_input_as_handled()
	if ignore_next_action:
		ignore_next_action = false
		return
	action_requested.emit()

func _render() -> void:
	if text_label == null:
		return
	text_label.text = current_text
	text_label.visible_characters = visible_count
	if arrow_label != null:
		arrow_label.visible = open_state and visible_count >= current_text.length()
