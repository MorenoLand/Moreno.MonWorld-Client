extends Control

signal authenticated
signal local_preview_requested

var provider: MonWorldContentProvider
var username_input: LineEdit
var email_input: LineEdit
var password_input: LineEdit
var remember_input: CheckButton
var server_input: LineEdit
var submit_button: Button
var mode_button: Button
var rom_button: Button
var preview_button: Button
var status_label: Label
var mode := "login"
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
	panel.custom_minimum_size = Vector2(460, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.add_theme_constant_override("margin_left", 28)
	box.add_theme_constant_override("margin_right", 28)
	box.add_theme_constant_override("margin_top", 24)
	box.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(box)
	var title := Label.new()
	title.text = "OpenMMOGo"
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)
	server_input = LineEdit.new()
	server_input.placeholder_text = "Server URL"
	var settings: Dictionary = MonWorldStorage.read_json(MonWorldStorage.SETTINGS_FILE)
	server_input.text = str(settings.get("server_url", GameState.api.base_url))
	server_input.text_submitted.connect(_on_text_submitted)
	box.add_child(server_input)
	username_input = LineEdit.new()
	username_input.placeholder_text = "Username"
	username_input.text_submitted.connect(_on_text_submitted)
	box.add_child(username_input)
	email_input = LineEdit.new()
	email_input.placeholder_text = "Email (registration only)"
	email_input.visible = false
	box.add_child(email_input)
	password_input = LineEdit.new()
	password_input.placeholder_text = "Password (8+ characters)"
	password_input.secret = true
	password_input.text_submitted.connect(_on_text_submitted)
	box.add_child(password_input)
	remember_input = CheckButton.new()
	remember_input.text = "Remember me"
	remember_input.tooltip_text = "Remember this username and password on this device."
	box.add_child(remember_input)
	submit_button = Button.new()
	submit_button.pressed.connect(_submit)
	box.add_child(submit_button)
	mode_button = Button.new()
	mode_button.flat = true
	mode_button.pressed.connect(_toggle_mode)
	box.add_child(mode_button)
	var rom_row := HBoxContainer.new()
	rom_button = Button.new()
	rom_button.text = "Choose local Kanto ROM"
	rom_button.pressed.connect(_choose_rom)
	rom_row.add_child(rom_button)
	box.add_child(rom_row)
	preview_button = Button.new()
	preview_button.text = "Test ROM locally"
	preview_button.disabled = true
	preview_button.pressed.connect(_test_rom_locally)
	box.add_child(preview_button)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(0, 44)
	box.add_child(status_label)
	_update_mode_ui()

func _load_saved_credentials() -> void:
	var saved: Dictionary = MonWorldAuthStore.load_saved()
	if saved.is_empty():
		return
	username_input.text = str(saved.get("username", ""))
	password_input.text = str(saved.get("password", ""))
	remember_input.button_pressed = true

func _update_mode_ui() -> void:
	var registration := mode == "register"
	email_input.visible = registration
	submit_button.text = "Create account" if registration else "Sign in"
	mode_button.text = "Already have an account? Sign in" if registration else "Need an account? Register"

func _toggle_mode() -> void:
	if busy:
		return
	mode = "register" if mode == "login" else "login"
	_update_mode_ui()
	_set_status("")

func _refresh_content() -> void:
	var result: Dictionary = await GameState.refresh_content()
	if not result.ok:
		_set_status("Could not read server content metadata: %s" % result.error, true)
		return
	var manifest: Dictionary = result.data if result.data is Dictionary else {}
	_set_status("")

func _initialize_content() -> void:
	await _refresh_content()
	if GameState.content == null and not provider.restore_saved_rom():
		provider.choose(self)

func _choose_rom() -> void:
	provider.choose(self)

func _on_content_loaded(content: MonWorldContent) -> void:
	var result := GameState.use_content(content)
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
		_set_status("Select a verified Kanto ROM first.", true)
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
		_set_status("Select a verified Kanto ROM before signing in.", true)
		provider.choose(self)
		return
	if mode == "register":
		if username.length() < 3 or username.length() > 32:
			_set_status("Username must be between 3 and 32 characters.", true)
			return
		if password.length() < 8:
			_set_status("Password must be at least 8 characters.", true)
			return
	busy = true
	_set_status("Checking server…")
	GameState.configure_server(server_input.text)
	var settings: Dictionary = MonWorldStorage.read_json(MonWorldStorage.SETTINGS_FILE)
	settings["server_url"] = server_input.text.strip_edges()
	MonWorldStorage.write_json(MonWorldStorage.SETTINGS_FILE, settings)
	var content_result: Dictionary = await GameState.refresh_content()
	if not content_result.ok:
		_set_status(str(content_result.error), true)
		busy = false
		return
	_set_status("Authenticating…")
	var result: Dictionary
	if mode == "register":
		result = await GameState.register(username, email_input.text.strip_edges(), password)
		if result.ok:
			result = await GameState.login(username, password)
	else:
		result = await GameState.login(username, password)
	if not result.ok:
		_set_status(str(result.error), true)
		busy = false
		return
	if remember_input.button_pressed:
		MonWorldAuthStore.save(username, password)
	else:
		MonWorldAuthStore.clear()
	_set_status("Opening game connection…")
	var game_result: Dictionary = await GameState.connect_game()
	if not game_result.ok:
		_set_status(str(game_result.error), true)
		busy = false
		return
	busy = false
	authenticated.emit()

func _set_status(value: String, is_error := false) -> void:
	if status_label == null:
		return
	status_label.text = value
	status_label.modulate = Color("ff9a9a") if is_error else Color("b8c7d9")
