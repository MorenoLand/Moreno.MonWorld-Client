extends Node

func _ready() -> void:
	print("OpenMMOGo headless smoke started")
	_run()

func _run() -> void:
	var endpoint: String = OS.get_environment("OPENMMOGO_LOGIN_ENDPOINT")
	var public_key_path: String = OS.get_environment("OPENMMOGO_ROOT_PUBLIC_KEY")
	var username: String = OS.get_environment("OPENMMOGO_USERNAME")
	var password: String = OS.get_environment("OPENMMOGO_PASSWORD")
	var rom_path: String = OS.get_environment("OPENMMOGO_ROM")
	if OS.get_environment("OPENMMOGO_USE_SAVED_CREDENTIALS") == "1" and (username.is_empty() or password.is_empty()):
		var saved: Dictionary = OpenMMOAuthStore.load_saved()
		username = str(saved.get("username", ""))
		password = str(saved.get("password", ""))
	if endpoint.is_empty():
		endpoint = "127.0.0.1:2106"
	if public_key_path.is_empty() or username.is_empty() or password.is_empty() or rom_path.is_empty():
		push_error("Set OPENMMOGO_ROOT_PUBLIC_KEY, OPENMMOGO_USERNAME, OPENMMOGO_PASSWORD, and OPENMMOGO_ROM")
		get_tree().quit(2)
		return
	var local_result: Dictionary = OpenMMOContent.from_rom_path(rom_path)
	if not bool(local_result.get("ok", false)):
		push_error("Local ROM rejected: %s" % str(local_result.get("error", "unknown error")))
		get_tree().quit(2)
		return
	var local_content: OpenMMOContent = local_result.get("content")
	print("Local ROM accepted as %s" % local_content.content_id())
	var configure_result: Dictionary = GameState.configure_server(endpoint, public_key_path)
	if not bool(configure_result.get("ok", false)):
		push_error("OpenMMO endpoint rejected: %s" % str(configure_result.get("error", "unknown error")))
		get_tree().quit(1)
		return
	var use_result: Dictionary = GameState.use_content(local_content)
	if not bool(use_result.get("ok", false)):
		push_error("Local ROM setup failed: %s" % str(use_result.get("error", "unknown error")))
		get_tree().quit(1)
		return
	var login_result: Dictionary = await GameState.login(username, password)
	if not bool(login_result.get("ok", false)):
		push_error("OpenMMO login failed: %s" % str(login_result.get("error", "unknown error")))
		get_tree().quit(1)
		return
	print("OpenMMO login passed")
	var game_result: Dictionary = await GameState.connect_game()
	if not bool(game_result.get("ok", false)):
		push_error("OpenMMO game session failed: %s" % str(game_result.get("error", "unknown error")))
		get_tree().quit(1)
		return
	print("OpenMMO game session and character list passed (%d characters)" % GameState.characters.size())
	GameState.disconnect_game()
	get_tree().quit(0)
