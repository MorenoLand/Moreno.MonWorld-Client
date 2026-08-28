class_name OpenMMOAuthStore
extends RefCounted

static func load_saved() -> Dictionary:
	var credentials: Dictionary = OpenMMOStorage.read_json(OpenMMOStorage.SETTINGS_FILE).get("credentials", {})
	if not credentials is Dictionary:
		return {}
	var username: String = str(credentials.get("username", "")).strip_edges()
	var password: String = str(credentials.get("password", ""))
	var token: String = str(credentials.get("token", "")).strip_edges()
	if username.is_empty() or (password.is_empty() and token.is_empty()):
		return {}
	return {"username": username, "password": password, "token": token}

static func save(username: String, password: String, token: String = "") -> void:
	var settings: Dictionary = OpenMMOStorage.read_json(OpenMMOStorage.SETTINGS_FILE)
	settings["credentials"] = {"username": username, "password": password, "token": token}
	OpenMMOStorage.write_json(OpenMMOStorage.SETTINGS_FILE, settings)

static func clear() -> void:
	var settings: Dictionary = OpenMMOStorage.read_json(OpenMMOStorage.SETTINGS_FILE)
	settings.erase("credentials")
	OpenMMOStorage.write_json(OpenMMOStorage.SETTINGS_FILE, settings)
