extends Control

signal authenticated

var provider: MonWorldContentProvider
var username_input: LineEdit
var email_input: LineEdit
var password_input: LineEdit
var server_input: LineEdit
var submit_button: Button
var mode_button: Button
var pack_button: Button
var status_label: Label
var mode := "login"
var busy := false

func _ready() -> void:
	provider = MonWorldContentProvider.new()
	add_child(provider)
	provider.pack_loaded.connect(_on_pack_loaded)
	provider.pack_failed.connect(_on_pack_failed)
	_build_ui()
	_refresh_content()

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
	title.text = "Multiplayer world client"
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)
	var description := Label.new()
	description.text = "Use an original client content pack selected from your device."
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(description)
	server_input = LineEdit.new()
	server_input.placeholder_text = "Server URL"
	server_input.text = GameState.api.base_url
	box.add_child(server_input)
	username_input = LineEdit.new()
	username_input.placeholder_text = "Username"
	box.add_child(username_input)
	email_input = LineEdit.new()
	email_input.placeholder_text = "Email (registration only)"
	email_input.visible = false
	box.add_child(email_input)
	password_input = LineEdit.new()
	password_input.placeholder_text = "Password (12+ characters)"
	password_input.secret = true
	box.add_child(password_input)
	submit_button = Button.new()
	submit_button.pressed.connect(_submit)
	box.add_child(submit_button)
	mode_button = Button.new()
	mode_button.flat = true
	mode_button.pressed.connect(_toggle_mode)
	box.add_child(mode_button)
	var pack_row := HBoxContainer.new()
	pack_button = Button.new()
	pack_button.text = "Choose local .monpack"
	pack_button.pressed.connect(_choose_pack)
	pack_row.add_child(pack_button)
	box.add_child(pack_row)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(0, 44)
	box.add_child(status_label)
	_update_mode_ui()

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
	_set_status("Server content: %s. Select a matching local pack when required." % str(manifest.get("content_id", "unknown")))

func _choose_pack() -> void:
	provider.choose(self)

func _on_pack_loaded(pack: MonWorldContentPack) -> void:
	var result := GameState.use_content_pack(pack)
	if result.ok:
		pack_button.text = "Pack: %s" % pack.content_id()
		_set_status("Local pack loaded for this client session.")
	else:
		_set_status(str(result.error), true)

func _on_pack_failed(message: String) -> void:
	_set_status(message, true)

func _submit() -> void:
	if busy:
		return
	busy = true
	_set_status("Connecting…")
	GameState.configure_server(server_input.text)
	var content_result: Dictionary = await GameState.refresh_content()
	if not content_result.ok:
		_set_status(str(content_result.error), true)
		busy = false
		return
	var result: Dictionary
	if mode == "register":
		result = await GameState.register(username_input.text.strip_edges(), email_input.text.strip_edges(), password_input.text)
		if result.ok:
			result = await GameState.login(username_input.text.strip_edges(), password_input.text)
	else:
		result = await GameState.login(username_input.text.strip_edges(), password_input.text)
	if not result.ok:
		_set_status(str(result.error), true)
		busy = false
		return
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
