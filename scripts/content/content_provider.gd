class_name MonWorldContentProvider
extends Node

const REGION_OPTIONS: Array = [
	{"region": "Unova", "title": "Black/White ROM", "enabled": false, "description": "Unavailable until Unova content is implemented."},
	{"region": "Kanto", "title": "FireRed/LeafGreen ROM", "enabled": true, "description": "Accepts a verified FireRed Rev1 or LeafGreen Rev1 ROM for the initial Pallet Town, Route 1, and Viridian City slice."},
	{"region": "Hoenn", "title": "Emerald ROM", "enabled": false, "description": "Unavailable until Hoenn content is implemented."},
	{"region": "Sinnoh", "title": "Platinum ROM", "enabled": false, "description": "Unavailable until Sinnoh content is implemented."},
	{"region": "Johto", "title": "HeartGold/SoulSilver ROM", "enabled": false, "description": "Unavailable until Johto content is implemented."}
]
const ROM_STATE_PATH: String = "user://monworld-roms.json"

signal content_loaded(content: MonWorldContent)
signal content_failed(message: String)

var manager: Window
var _web_callback: Variant
var _native_dialog_open: bool = false

func choose(parent: Node) -> void:
	if is_instance_valid(manager):
		manager.popup_centered()
		return
	manager = Window.new()
	manager.title = "Client Management"
	manager.size = Vector2i(680, 520)
	manager.min_size = Vector2i(560, 420)
	manager.close_requested.connect(_close_manager)
	manager.tree_exiting.connect(_on_manager_exiting)
	parent.add_child(manager)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	manager.add_child(margin)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	var heading: Label = Label.new()
	heading.text = "Local game content"
	heading.add_theme_font_size_override("font_size", 24)
	box.add_child(heading)
	var description: Label = Label.new()
	description.text = "Select a supported region ROM. Other regions will unlock as their content is implemented."
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(description)
	for option_value in REGION_OPTIONS:
		var option: Dictionary = option_value
		var row: HBoxContainer = HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 44)
		var label: Label = Label.new()
		label.text = "%s — %s" % [str(option.get("region", "")), str(option.get("title", ""))]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.tooltip_text = str(option.get("description", ""))
		if not bool(option.get("enabled", false)):
			label.modulate = Color("7f8794")
		row.add_child(label)
		var state: Label = Label.new()
		state.text = "Available" if bool(option.get("enabled", false)) else "Coming later"
		state.custom_minimum_size = Vector2(110, 0)
		state.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		state.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		state.modulate = Color("b8c7d9") if bool(option.get("enabled", false)) else Color("6c7480")
		row.add_child(state)
		var select_button: Button = Button.new()
		select_button.text = "Select File"
		select_button.disabled = not bool(option.get("enabled", false))
		select_button.pressed.connect(_select_region.bind(option))
		row.add_child(select_button)
		var info_button: Button = Button.new()
		info_button.text = "Info"
		info_button.pressed.connect(_show_region_info.bind(option))
		row.add_child(info_button)
		box.add_child(row)
	var note: Label = Label.new()
	note.text = "The Kanto row accepts verified FireRed Rev1 or LeafGreen Rev1 .gba ROMs. The ROM is read locally and never uploaded."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.modulate = Color("b8c7d9")
	box.add_child(note)
	var close_button: Button = Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(_close_manager)
	box.add_child(close_button)
	manager.popup_centered()

func _select_region(option: Dictionary) -> void:
	if not bool(option.get("enabled", false)):
		return
	if is_instance_valid(manager):
		manager.hide()
	if OS.has_feature("web"):
		_choose_web()
		return
	if _native_dialog_open:
		return
	if not DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		content_failed.emit("native file selection is unavailable on this platform")
		return
	_native_dialog_open = true
	var dialog_error: int = DisplayServer.file_dialog_show("Select %s" % str(option.get("title", "ROM")), "", "", false, DisplayServer.FILE_DIALOG_MODE_OPEN_FILE, PackedStringArray(["*.gba;Game Boy Advance ROM;application/octet-stream"]), _on_native_file_selected)
	if dialog_error != OK:
		_native_dialog_open = false
		content_failed.emit("could not open the native file picker")

func _show_region_info(option: Dictionary) -> void:
	if not is_instance_valid(manager):
		return
	var info: AcceptDialog = AcceptDialog.new()
	info.title = "%s — %s" % [str(option.get("region", "")), str(option.get("title", ""))]
	info.dialog_text = str(option.get("description", ""))
	manager.add_child(info)
	info.popup_centered()

func _close_manager() -> void:
	if is_instance_valid(manager):
		manager.queue_free()

func _on_manager_exiting() -> void:
	manager = null

func _on_native_file_selected(status: bool, selected_paths: PackedStringArray, _filter_index: int) -> void:
	_native_dialog_open = false
	if not status or selected_paths.is_empty():
		content_failed.emit("no ROM was selected")
		return
	_on_rom_selected(selected_paths[0])

func _on_rom_selected(path: String) -> void:
	var extension: String = path.get_extension().to_lower()
	if extension != "gba":
		content_failed.emit("unsupported file; select a .gba ROM")
		return
	var result: Dictionary = MonWorldContent.from_rom_path(path)
	if bool(result.get("ok", false)):
		_save_rom_path(path)
		_close_manager()
		content_loaded.emit(result.get("content"))
	else:
		content_failed.emit(str(result.get("error", "could not load content")))

func restore_saved_rom() -> bool:
	if not FileAccess.file_exists(ROM_STATE_PATH):
		return false
	var file: FileAccess = FileAccess.open(ROM_STATE_PATH, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		_clear_saved_rom()
		return false
	var path: String = str(parsed.get("kanto", ""))
	if path.is_empty():
		_clear_saved_rom()
		return false
	var result: Dictionary = MonWorldContent.from_rom_path(path)
	if bool(result.get("ok", false)):
		content_loaded.emit(result.get("content"))
		return true
	_clear_saved_rom()
	content_failed.emit("The saved Kanto ROM could not be loaded; select it again.")
	return false

func _save_rom_path(path: String) -> void:
	var file: FileAccess = FileAccess.open(ROM_STATE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"kanto": path}))
	file.close()

func _clear_saved_rom() -> void:
	if FileAccess.file_exists(ROM_STATE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ROM_STATE_PATH))

func _choose_web() -> void:
	_web_callback = JavaScriptBridge.create_callback(_on_web_file)
	var window := JavaScriptBridge.get_interface("window")
	window.monworld_content_callback = _web_callback
	JavaScriptBridge.eval("""
(function() {
  const input = document.createElement('input');
  input.type = 'file';
	input.accept = '.gba,application/octet-stream';
  input.onchange = function() {
    const file = input.files && input.files[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = function() {
      const bytes = new Uint8Array(reader.result);
      let binary = '';
      const chunk = 0x8000;
      for (let i = 0; i < bytes.length; i += chunk) binary += String.fromCharCode.apply(null, bytes.subarray(i, i + chunk));
      window.monworld_content_callback(file.name, btoa(binary));
    };
    reader.onerror = function() { window.monworld_content_callback('', ''); };
    reader.readAsArrayBuffer(file);
  };
  input.click();
})();
""")

func _on_web_file(args: Array) -> void:
	if args.size() < 2 or str(args[0]).is_empty() or str(args[1]).is_empty():
		content_failed.emit("no ROM was selected")
		return
	var filename: String = str(args[0])
	var extension: String = filename.get_extension().to_lower()
	if extension != "gba":
		content_failed.emit("unsupported file; select a .gba ROM")
		return
	var data: PackedByteArray = Marshalls.base64_to_raw(str(args[1]))
	var path: String = "user://monworld-session.gba"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		content_failed.emit("could not store the selected content locally")
		return
	file.store_buffer(data)
	file.close()
	_on_rom_selected(path)
