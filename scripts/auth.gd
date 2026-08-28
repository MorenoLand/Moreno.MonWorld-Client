extends Control

signal authenticated
signal local_preview_requested

var provider: MonWorldContentProvider
var username_input: LineEdit
var password_input: LineEdit
var remember_input: CheckButton
var server_input: LineEdit
var key_path_input: LineEdit
var key_dialog: FileDialog
var submit_button: Button
var rom_button: Button
var preview_button: Button
var status_label: Label
var busy := false

func _ready() -> void:
	provider = MonWorldContentProvider.new()
	add_child(provider)
	provider.content_loaded.connect(_on_content_loaded)
	provider.content_failed.connect(_on_content_failed)
	_build_ui()
	_load_saved_credentials()
	call_deferred("_initialize_content")

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("101721")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	move_child(background, 0)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var title := Label.new()
	title.text = "OpenMMOGo"
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)
	server_input = LineEdit.new()
	server_input.placeholder_text = "Login server (host:port)"
	server_input.text = GameState.endpoint_text()
	server_input.text_submitted.connect(_on_text_submitted)
	box.add_child(server_input)
	var key_row := HBoxContainer.new()
	key_path_input = LineEdit.new()
	key_path_input.placeholder_text = "Server public key (.pem)"
	key_path_input.text = GameState.root_public_key_path
	key_path_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	key_row.add_child(key_path_input)
	var key_button := Button.new()
	key_button.text = "Browse"
	key_button.pressed.connect(_choose_key)
	key_row.add_child(key_button)
	box.add_child(key_row)
	username_input = LineEdit.new()
	username_input.placeholder_text = "Username"
	username_input.text_submitted.connect(_on_text_submitted)
	box.add_child(username_input)
	password_input = LineEdit.new()
	password_input.placeholder_text = "Password"
	password_input.secret = true
	password_input.text_submitted.connect(_on_text_submitted)
	box.add_child(password_input)
	remember_input = CheckButton.new()
	remember_input.text = "Remember me"
	remember_input.tooltip_text = "Remember this username and password on this device."
	box.add_child(remember_input)
	submit_button = Button.new()
	submit_button.text = "Sign in"
	submit_button.pressed.connect(_submit)
	box.add_child(submit_button)
	rom_button = Button.new()
	rom_button.text = "Choose local Kanto ROM"
	rom_button.pressed.connect(_choose_rom)
	box.add_child(rom_button)
	preview_button = Button.new()
	preview_button.text = "Test ROM locally"
	preview_button.disabled = true
	preview_button.pressed.connect(_test_rom_locally)
	box.add_child(preview_button)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(0, 44)
	box.add_child(status_label)
	key_dialog = FileDialog.new()
	key_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	key_dialog.access = FileDialog.ACCESS_FILESYSTEM
	key_dialog.use_native_dialog = true
	key_dialog.filters = PackedStringArray(["*.pem ; PEM public keys"])
	key_dialog.file_selected.connect(_on_key_selected)
	add_child(key_dialog)

func _load_saved_credentials() -> void:
	var saved: Dictionary = MonWorldAuthStore.load_saved()
	if saved.is_empty():
		return
	username_input.text = str(saved.get("username", ""))
	password_input.text = str(saved.get("password", ""))
	remember_input.button_pressed = true

func _initialize_content() -> void:
	if GameState.content == null and not provider.restore_saved_rom():
		provider.choose(self)

func _choose_key() -> void:
	key_dialog.popup_centered_ratio(0.75)

func _on_key_selected(path: String) -> void:
	key_path_input.text = path

func _choose_rom() -> void:
	provider.choose(self)

func _on_content_loaded(content: MonWorldContent) -> void:
	var result: Dictionary = GameState.use_content(content)
	if result.ok:
		rom_button.text = "ROM: %s" % content.content_id()
		preview_button.disabled = false
		_set_status("")
	else:
		_set_status(str(result.error), true)

func _on_content_failed(message: String) -> void:
	_set_status(message, true)

func _test_rom_locally() -> void:
	if GameState.content == null:
		_set_status("Select a compatible Kanto ROM first.", true)
		provider.choose(self)
		return
	local_preview_requested.emit()

func _on_text_submitted(_text: String) -> void:
	_submit()

func _submit() -> void:
	if busy:
		return
	var username: String = username_input.text.strip_edges()
	var password: String = password_input.text
	if username.is_empty() or password.is_empty():
		_set_status("Username and password are required.", true)
		return
	if GameState.content == null:
		_set_status("Select a compatible Kanto ROM before signing in.", true)
		provider.choose(self)
		return
	var configured: Dictionary = GameState.configure_server(server_input.text, key_path_input.text)
	if not configured.ok:
		_set_status(str(configured.error), true)
		return
	var settings: Dictionary = MonWorldStorage.read_json(MonWorldStorage.SETTINGS_FILE)
	settings["login_host"] = GameState.login_host
	settings["login_port"] = GameState.login_port
	settings["root_public_key_path"] = GameState.root_public_key_path
	MonWorldStorage.write_json(MonWorldStorage.SETTINGS_FILE, settings)
	busy = true
	submit_button.disabled = true
	_set_status("Authenticating…")
	var result: Dictionary = await GameState.login(username, password, remember_input.button_pressed)
	if not result.ok:
		_finish_submit(str(result.error), true)
		return
	if remember_input.button_pressed:
		MonWorldAuthStore.save(username, password)
	else:
		MonWorldAuthStore.clear()
	_set_status("Opening game connection…")
	result = await GameState.connect_game()
	if not result.ok:
		_finish_submit(str(result.error), true)
		return
	busy = false
	submit_button.disabled = false
	authenticated.emit()

func _finish_submit(message: String, is_error: bool) -> void:
	busy = false
	submit_button.disabled = false
	_set_status(message, is_error)

func _set_status(value: String, is_error := false) -> void:
	if status_label == null:
		return
	status_label.text = value
	status_label.modulate = Color("ff9a9a") if is_error else Color("b8c7d9")
