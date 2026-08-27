class_name MonWorldDialogue
extends PanelContainer

signal action_requested
signal closed

const TYPE_INTERVAL: float = 1.0 / 30.0
var text_label: Label
var arrow_label: Label
var current_text: String = ""
var pages: Array = []
var page_index: int = 0
var visible_count: int = 0
var type_elapsed: float = 0.0
var open_state: bool = false
var ignore_next_action: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	offset_left = 28.0
	offset_top = -170.0
	offset_right = -28.0
	offset_bottom = -28.0
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
	text_label.add_theme_font_size_override("font_size", 22)
	text_label.custom_minimum_size = Vector2(0, 88)
	box.add_child(text_label)
	var arrow_row: HBoxContainer = HBoxContainer.new()
	arrow_row.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(arrow_row)
	arrow_label = Label.new()
	arrow_label.text = "▼"
	arrow_label.add_theme_font_size_override("font_size", 18)
	arrow_row.add_child(arrow_label)
	visible = false
	set_process(false)

func show_text(value: String, suppress_action: bool = false) -> void:
	show_pages([value], suppress_action)

func show_pages(values: Array, suppress_action: bool = false) -> void:
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
	visible = open_state
	set_process(open_state)
	_render()

func is_open() -> bool:
	return open_state

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
	if not key_event.pressed or key_event.echo or key_event.keycode not in [KEY_F, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
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
