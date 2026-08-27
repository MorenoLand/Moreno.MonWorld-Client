extends Node

func _ready() -> void:
	print("headless: runner started")
	_run()

func _run() -> void:
	var server_url: String = OS.get_environment("MONWORLD_SERVER_URL")
	var username: String = OS.get_environment("MONWORLD_USERNAME")
	var password: String = OS.get_environment("MONWORLD_PASSWORD")
	var rom_path: String = OS.get_environment("MONWORLD_ROM")
	if OS.get_environment("MONWORLD_USE_SAVED_CREDENTIALS") == "1" and (username.is_empty() or password.is_empty()):
		var saved: Dictionary = MonWorldAuthStore.load_saved()
		username = str(saved.get("username", ""))
		password = str(saved.get("password", ""))
	if server_url.is_empty() or username.is_empty() or password.is_empty() or rom_path.is_empty():
		push_error("headless: set MONWORLD_SERVER_URL, MONWORLD_USERNAME, MONWORLD_PASSWORD, and MONWORLD_ROM")
		get_tree().quit(2)
		return
	var local_result: Dictionary = MonWorldContent.from_rom_path(rom_path)
	if not bool(local_result.get("ok", false)):
		push_error("headless: local ROM rejected: %s" % str(local_result.get("error", "unknown error")))
		get_tree().quit(2)
		return
	var local_content: MonWorldContent = local_result.get("content")
	print("headless: local ROM accepted as %s" % local_content.content_id())
	GameState.configure_server(server_url)
	var content_result: Dictionary = await GameState.refresh_content()
	if not bool(content_result.get("ok", false)):
		push_error("headless: content request failed: %s" % str(content_result.get("error", "unknown error")))
		get_tree().quit(1)
		return
	var use_result: Dictionary = GameState.use_content(local_content)
	if not bool(use_result.get("ok", false)):
		push_error("headless: content negotiation failed: %s" % str(use_result.get("error", "unknown error")))
		get_tree().quit(1)
		return
	var login_result: Dictionary = await GameState.login(username, password)
	if not bool(login_result.get("ok", false)):
		push_error("headless: login failed: %s" % str(login_result.get("error", "unknown error")))
		get_tree().quit(1)
		return
	print("headless: API login passed")
	var game_result: Dictionary = await GameState.connect_game()
	if not bool(game_result.get("ok", false)):
		push_error("headless: game handshake failed: %s" % str(game_result.get("error", "unknown error")))
		get_tree().quit(1)
		return
	print("headless: game handshake passed")
	GameState.disconnect_game()
	get_tree().quit(0)
