class_name MonWorldContentPack
extends RefCounted

const SCHEMA_VERSION := 1
var manifest: Dictionary = {}

static func development() -> MonWorldContentPack:
	var pack := MonWorldContentPack.new()
	pack.manifest = {"schema_version": SCHEMA_VERSION, "content_id": "development-empty", "source": {"game": "synthetic", "revision": "development", "rom_sha1": ""}, "maps": [{"id": "development_start", "name": "Development Start", "width": 32, "height": 20}]}
	return pack

static func from_manifest(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {"ok": false, "error": "manifest is not an object"}
	var candidate: Dictionary = value
	if int(candidate.get("schema_version", 0)) != SCHEMA_VERSION:
		return {"ok": false, "error": "unsupported content schema"}
	if str(candidate.get("content_id", "")).is_empty():
		return {"ok": false, "error": "manifest has no content_id"}
	var maps: Variant = candidate.get("maps", [])
	if not maps is Array or maps.is_empty():
		return {"ok": false, "error": "manifest has no maps"}
	for map_value in maps:
		if not map_value is Dictionary or str(map_value.get("id", "")).is_empty() or int(map_value.get("width", 0)) < 1 or int(map_value.get("height", 0)) < 1:
			return {"ok": false, "error": "manifest has an invalid map"}
	var pack := MonWorldContentPack.new()
	pack.manifest = candidate
	return {"ok": true, "pack": pack}

static func from_path(path: String) -> Dictionary:
	var reader := ZIPReader.new()
	var error := reader.open(path)
	if error != OK:
		return {"ok": false, "error": "could not open content pack: %s" % error}
	var files := reader.get_files()
	if not files.has("manifest.json"):
		reader.close()
		return {"ok": false, "error": "content pack has no manifest.json"}
	var manifest_data := reader.read_file("manifest.json")
	reader.close()
	var value: Variant = JSON.parse_string(manifest_data.get_string_from_utf8())
	return from_manifest(value)

func content_id() -> String:
	return str(manifest.get("content_id", ""))

func map_data(map_id: String) -> Dictionary:
	for map_value in manifest.get("maps", []):
		if map_value is Dictionary and str(map_value.get("id", "")) == map_id:
			return map_value
	return {}
