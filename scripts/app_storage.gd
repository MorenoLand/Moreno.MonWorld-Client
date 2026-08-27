class_name MonWorldStorage
extends RefCounted

const APP_DIRECTORY: String = "MonWorld"
const SETTINGS_FILE: String = "settings.json"
const STRINGS_DIRECTORY: String = "Strings"

static func root_path() -> String:
	if OS.has_feature("web"):
		return "user://monworld"
	var appdata: String = OS.get_environment("APPDATA")
	if not appdata.is_empty():
		return appdata.path_join(APP_DIRECTORY)
	var config_home: String = OS.get_environment("XDG_CONFIG_HOME")
	if not config_home.is_empty():
		return config_home.path_join(APP_DIRECTORY)
	return OS.get_user_data_dir().path_join(APP_DIRECTORY)

static func strings_path() -> String:
	return root_path().path_join(STRINGS_DIRECTORY)

static func strings_file_path(content_id: String, language: String = "en") -> String:
	return strings_path().path_join(content_id).path_join("%s.json" % language)

static func settings_path() -> String:
	return root_path().path_join(SETTINGS_FILE)

static func ensure_layout() -> bool:
	var root: String = root_path()
	var strings: String = strings_path()
	var root_result: int = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root) if root.begins_with("user://") else root)
	var strings_result: int = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(strings) if strings.begins_with("user://") else strings)
	return root_result == OK or root_result == ERR_ALREADY_EXISTS and (strings_result == OK or strings_result == ERR_ALREADY_EXISTS)

static func read_json(relative_path: String) -> Dictionary:
	if not ensure_layout():
		return {}
	var path: String = root_path().path_join(relative_path)
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}

static func write_json(relative_path: String, value: Dictionary) -> bool:
	if not ensure_layout():
		return false
	var file: FileAccess = FileAccess.open(root_path().path_join(relative_path), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(value, "\t"))
	file.close()
	return true

static func write_strings(content_id: String, values: Dictionary) -> bool:
	if not ensure_layout():
		return false
	var directory: String = strings_path().path_join(content_id)
	var directory_result: int = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory) if directory.begins_with("user://") else directory)
	if directory_result != OK and directory_result != ERR_ALREADY_EXISTS:
		return false
	var file: FileAccess = FileAccess.open(strings_file_path(content_id), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(values, "\t"))
	file.close()
	return true

static func read_strings(content_id: String, language: String = "en") -> Dictionary:
	var path: String = strings_file_path(content_id, language)
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}

static func session_rom_path() -> String:
	return "user://monworld-session.gba" if OS.has_feature("web") else root_path().path_join("session.gba")
