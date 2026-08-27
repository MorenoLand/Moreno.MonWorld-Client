class_name MonWorldAuthStore
extends RefCounted

const PATH: String = "user://monworld-credentials.json"

static func load_saved() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var file: FileAccess = FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return {}
	var username: String = str(parsed.get("username", "")).strip_edges()
	var password: String = str(parsed.get("password", ""))
	if username.is_empty() or password.is_empty():
		return {}
	return {"username": username, "password": password}

static func save(username: String, password: String) -> void:
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"username": username, "password": password}))
	file.close()

static func clear() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
