class_name OpenMMOContent
extends RefCounted

const ANIMATION_PHASE_COUNT: int = 40

const SCHEMA_VERSION: int = 1
const KANTO_GBA_CONTENT_ID: String = "kanto-gba-slice-v1"
const GBA_TITLE_OFFSET: int = 0xA0
const GBA_TITLE_LENGTH: int = 12
const GBA_GAME_CODE_OFFSET: int = 0xAC
const GBA_GAME_CODE_LENGTH: int = 4
const GBA_MAKER_CODE_OFFSET: int = 0xB0
const GBA_MAKER_CODE_LENGTH: int = 2
const MAP_HEADER_SIZE: int = 0x1C
const MAPGRID_METATILE_ID_MASK: int = 0x03FF
const MAPGRID_COLLISION_MASK: int = 0x0C00
const MAPGRID_ELEVATION_MASK: int = 0xF000
const MAPGRID_COLLISION_SHIFT: int = 10
const MAPGRID_ELEVATION_SHIFT: int = 12
const MAPGRID_UNDEFINED: int = 0x03FF
const METATILE_BEHAVIOR_MASK: int = 0x000001FF
const PRIMARY_METATILE_COUNT: int = 640
const PRIMARY_TILE_COUNT: int = 640
const PRIMARY_PALETTE_COUNT: int = 7
const SECONDARY_PALETTE_COUNT: int = 6
const SECONDARY_ROM_PALETTE_COUNT: int = 16
const TILE_BYTES: int = 32
const TILES_PER_METATILE: int = 8
const MAPGRID_LAYER_TYPE_SHIFT: int = 29
const MAPGRID_LAYER_TYPE_MASK: int = 0x60000000
const MAP_EVENTS_HEADER_SIZE: int = 0x14
const MAP_OBJECT_EVENT_SIZE: int = 0x18
const MAP_WARP_EVENT_SIZE: int = 0x08
const MAP_BG_EVENT_SIZE: int = 0x0C
const MAP_CONNECTIONS_HEADER_SIZE: int = 0x08
const MAP_CONNECTION_SIZE: int = 0x0C
const CONNECTION_SOUTH: int = 1
const CONNECTION_NORTH: int = 2
const CONNECTION_WEST: int = 3
const CONNECTION_EAST: int = 4
const MAP_TYPE_INSIDE: int = 8
const MAP_TYPE_SECRET_BASE: int = 9
const MAX_CORNER_FILLER_SIZE: int = 128
const ROCK_STAIRS_BEHAVIOR: int = 0x2A
const FLOOR_ROOFTOP: int = 127
const MAP_GROUP_DUNGEONS: int = 1
const MAP_GROUP_TOWNS_AND_ROUTES: int = 3
const MAP_GROUP_INDOOR_PALLET: int = 4
const MAP_GROUP_INDOOR_VIRIDIAN: int = 5
var manifest: Dictionary = {}
var rom_data: PackedByteArray = PackedByteArray()
var rom_sha1: String = ""
var rom_header: Dictionary = {}
var source_profile: Dictionary = {}
var map_cache: Dictionary = {}
var map_topology_cache: Dictionary = {}
var sprite_cache: Dictionary = {}
var string_catalog: Dictionary = {}

static func from_rom_path(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "could not open ROM"}
	var length: int = int(file.get_length())
	var data: PackedByteArray = file.get_buffer(length)
	file.close()
	return from_rom_bytes(data)

static func from_rom_bytes(data: PackedByteArray) -> Dictionary:
	var header: Dictionary = _read_gba_header(data)
	if header.is_empty():
		return {"ok": false, "error": "ROM is too small to contain a valid GBA header"}
	var source_profile: Dictionary = OpenMMORomProfile.from_header(header)
	if source_profile.is_empty():
		return {"ok": false, "error": "unsupported GBA game code %s" % str(header.get("game_code", ""))}
	if bool(source_profile.get("supports_map_rendering", false)) and not _has_map_layout(data, source_profile):
		return {"ok": false, "error": "%s header found, but no compatible map layout was discovered" % str(source_profile.get("game", "GBA"))}
	var context: HashingContext = HashingContext.new()
	var rom_sha1: String = ""
	if context.start(HashingContext.HASH_SHA1) == OK:
		context.update(data)
		rom_sha1 = context.finish().hex_encode()
	var content: OpenMMOContent = OpenMMOContent.new()
	content.rom_data = data
	content.rom_sha1 = rom_sha1
	content.rom_header = header
	content.source_profile = source_profile
	content.manifest = _manifest_for_profile(source_profile, rom_sha1)
	content.string_catalog = OpenMMOStorage.read_strings(str(content.manifest.get("content_id", "")))
	content._hydrate_manifest()
	return {"ok": true, "content": content}

static func _read_gba_header(data: PackedByteArray) -> Dictionary:
	if data.size() < GBA_MAKER_CODE_OFFSET + GBA_MAKER_CODE_LENGTH:
		return {}
	return {"title": data.slice(GBA_TITLE_OFFSET, GBA_TITLE_OFFSET + GBA_TITLE_LENGTH).get_string_from_ascii().strip_edges(), "game_code": data.slice(GBA_GAME_CODE_OFFSET, GBA_GAME_CODE_OFFSET + GBA_GAME_CODE_LENGTH).get_string_from_ascii(), "maker_code": data.slice(GBA_MAKER_CODE_OFFSET, GBA_MAKER_CODE_OFFSET + GBA_MAKER_CODE_LENGTH).get_string_from_ascii()}

static func _has_map_layout(data: PackedByteArray, profile: Dictionary) -> bool:
	var map_groups_offset: int = int(profile.get("map_groups_offset", -1))
	if map_groups_offset < 0:
		return false
	var map_groups: Dictionary = profile.get("map_groups", {})
	var towns_group: int = int(map_groups.get("towns_and_routes", MAP_GROUP_TOWNS_AND_ROUTES))
	var format: Dictionary = profile.get("format", {})
	var map_header_size: int = int(format.get("map_header_size", MAP_HEADER_SIZE))
	var towns_table_offset: int = _read_gba_pointer(data, map_groups_offset + towns_group * 4)
	if towns_table_offset < 0:
		return false
	for map_index in profile.get("map_group_probe_indices", [0, 1, 19]):
		var header_offset: int = _read_gba_pointer(data, towns_table_offset + int(map_index) * 4)
		if header_offset < 0 or not _valid_data_range(data, header_offset, map_header_size):
			return false
		var layout_offset: int = _read_gba_pointer(data, header_offset)
		if layout_offset < 0 or not _valid_data_range(data, layout_offset, map_header_size):
			return false
		var width: int = _read_data_u32(data, layout_offset)
		var height: int = _read_data_u32(data, layout_offset + 4)
		if width <= 0 or height <= 0 or width > 512 or height > 512:
			return false
	return true

static func _read_gba_pointer(data: PackedByteArray, offset: int) -> int:
	if not _valid_data_range(data, offset, 4):
		return -1
	var value: int = _read_data_u32(data, offset)
	var region: int = value & 0xFF000000
	if region != 0x08000000 and region != 0x09000000 and region != 0x0A000000:
		return -1
	var file_offset: int = value & 0x01FFFFFF
	return file_offset if _valid_data_range(data, file_offset, 1) else -1

static func _read_data_u32(data: PackedByteArray, offset: int) -> int:
	return int(data[offset]) | (int(data[offset + 1]) << 8) | (int(data[offset + 2]) << 16) | (int(data[offset + 3]) << 24)

static func _valid_data_range(data: PackedByteArray, offset: int, length: int) -> bool:
	return offset >= 0 and length >= 0 and offset <= data.size() and length <= data.size() - offset

static func _manifest_for_profile(profile: Dictionary, rom_sha1: String) -> Dictionary:
	var source_game: String = str(profile.get("game", "Unknown"))
	var maps: Array = []
	var map_names: Array = profile.get("map_names", [])
	var map_groups: Dictionary = profile.get("map_groups", {})
	var towns_group: int = int(map_groups.get("towns_and_routes", MAP_GROUP_TOWNS_AND_ROUTES))
	for map_index in range(map_names.size()):
		var raw_name: String = map_names[map_index]
		var map_id: String = "rom-map-%d-%d" % [towns_group, map_index]
		if map_index == 0:
			map_id = "pallet-town"
		elif map_index == 1:
			map_id = "viridian-city"
		elif map_index == 19:
			map_id = "route-1"
		maps.append({"id": map_id, "name": _pretty_map_name(raw_name), "map_group": towns_group, "map_index": map_index, "width": 0, "height": 0})
	var extra_maps: Array = profile.get("extra_maps", [])
	for extra_map in extra_maps:
		maps.append({"id": str(extra_map.get("id", "")), "name": str(extra_map.get("name", "ROM map")), "map_group": int(extra_map.get("group", -1)), "map_index": int(extra_map.get("index", -1)), "width": 0, "height": 0})
	return {"schema_version": SCHEMA_VERSION, "content_id": str(profile.get("content_id", "")), "source": {"profile_id": str(profile.get("id", "")), "game": source_game, "region": str(profile.get("region", "")), "revision": str(profile.get("revision", "")), "rom_sha1": rom_sha1}, "maps": maps}

static func _pretty_map_name(raw_name: String) -> String:
	var value: String = raw_name.replace("_", " ")
	value = value.replace("PalletTown", "Pallet Town").replace("ViridianCity", "Viridian City").replace("PewterCity", "Pewter City").replace("CeruleanCity", "Cerulean City").replace("LavenderTown", "Lavender Town").replace("VermilionCity", "Vermilion City").replace("CeladonCity", "Celadon City").replace("FuchsiaCity", "Fuchsia City").replace("CinnabarIsland", "Cinnabar Island").replace("SaffronCity", "Saffron City").replace("IndigoPlateau", "Indigo Plateau")
	if value.begins_with("Route"):
		var route_value: String = value.trim_prefix("Route")
		value = "Route " + route_value
	return value

func _map_name_from_descriptor(descriptor: Dictionary) -> String:
	var section_id: int = int(descriptor.get("region_map_section_id", -1))
	var section_start: int = int(source_profile.get("region_map_section_start", -1))
	var section_names: Array = source_profile.get("region_map_section_names", [])
	if section_start < 0 or section_id < section_start or section_id - section_start >= section_names.size():
		return ""
	var name: String = str(section_names[section_id - section_start])
	if name.is_empty():
		return ""
	var floor_num: int = int(descriptor.get("floor_num", 0))
	if floor_num == 0:
		return name
	if floor_num == FLOOR_ROOFTOP:
		return "%s Rooftop" % name
	return "%s %s%dF" % [name, "B" if floor_num < 0 else "", absi(floor_num)]

func _format_int(key: String, fallback: int) -> int:
	var format: Dictionary = source_profile.get("format", {})
	return int(format.get(key, fallback))

func _animation_offsets(kind: String) -> Array:
	var animations: Dictionary = source_profile.get("animations", {})
	return animations.get(kind, [])

func _object_sprite_specs() -> Dictionary:
	return source_profile.get("object_sprites", {})

func _hydrate_manifest() -> void:
	var maps: Array = manifest.get("maps", [])
	for map_index in range(maps.size()):
		if not maps[map_index] is Dictionary:
			continue
		var map_value: Dictionary = maps[map_index]
		var descriptor: Dictionary = _read_map_descriptor(map_value)
		if bool(descriptor.get("ok", false)):
			map_value["width"] = int(descriptor.get("width", 0))
			map_value["height"] = int(descriptor.get("height", 0))
			map_value["music_id"] = int(descriptor.get("music_id", 0))
			map_value["map_type"] = int(descriptor.get("map_type", 0))
			var source_name: String = _map_name_from_descriptor(descriptor)
			if not source_name.is_empty() and str(map_value.get("name", "")).begins_with("ROM map "):
				map_value["name"] = source_name
		maps[map_index] = map_value
	manifest["maps"] = maps

func _map_reference_from_id(map_id: String) -> Dictionary:
	var parts: PackedStringArray = map_id.split("-")
	if parts.size() != 4 or parts[0] != "rom" or parts[1] != "map":
		return {}
	if not parts[2].is_valid_int() or not parts[3].is_valid_int():
		return {}
	return {"id": map_id, "map_group": int(parts[2]), "map_index": int(parts[3])}

func _read_map_descriptor(map_value: Dictionary) -> Dictionary:
	var map_group: int = int(map_value.get("map_group", -1))
	var map_index: int = int(map_value.get("map_index", -1))
	if map_group < 0 or map_index < 0:
		return {"ok": false, "error": "map has no verified ROM group identity"}
	var map_groups_offset: int = int(source_profile.get("map_groups_offset", -1))
	if map_groups_offset < 0:
		return {"ok": false, "error": "the selected ROM profile has no map group table"}
	var group_table_offset: int = _read_rom_pointer(map_groups_offset + map_group * 4)
	if group_table_offset < 0:
		return {"ok": false, "error": "could not resolve the FireRed map group"}
	var header_offset: int = _read_rom_pointer(group_table_offset + map_index * 4)
	if header_offset < 0 or not _valid_range(header_offset, _format_int("map_header_size", MAP_HEADER_SIZE)):
		return {"ok": false, "error": "could not resolve the FireRed map header"}
	var layout_offset: int = _read_rom_pointer(header_offset)
	if layout_offset < 0 or not _valid_range(layout_offset, 0x1C):
		return {"ok": false, "error": "could not resolve the FireRed map layout"}
	var width: int = _read_u32(layout_offset)
	var height: int = _read_u32(layout_offset + 4)
	var map_offset: int = _read_rom_pointer(layout_offset + 12)
	var primary_offset: int = _read_rom_pointer(layout_offset + 16)
	var secondary_offset: int = _read_rom_pointer(layout_offset + 20)
	var border_offset: int = _read_rom_pointer(layout_offset + 8)
	var border_width: int = int(rom_data[layout_offset + 24])
	var border_height: int = int(rom_data[layout_offset + 25])
	if width <= 0 or height <= 0 or width > 512 or height > 512:
		return {"ok": false, "error": "FireRed map dimensions are invalid"}
	var floor_num: int = int(rom_data[header_offset + 0x1A])
	if floor_num >= 0x80:
		floor_num -= 0x100
	return {"ok": true, "map_group": map_group, "map_index": map_index, "header_offset": header_offset, "layout_offset": layout_offset, "width": width, "height": height, "map_offset": map_offset, "primary_offset": primary_offset, "secondary_offset": secondary_offset, "border_offset": border_offset, "border_width": border_width, "border_height": border_height, "music_id": _read_u16(header_offset + 0x10), "region_map_section_id": int(rom_data[header_offset + 0x14]), "map_type": int(rom_data[header_offset + 0x17]), "floor_num": floor_num}

func _map_id_for_location(map_group: int, map_index: int) -> String:
	for map_value in manifest.get("maps", []):
		if map_value is Dictionary and int(map_value.get("map_group", -1)) == map_group and int(map_value.get("map_index", -1)) == map_index:
			return str(map_value.get("id", ""))
	return "rom-map-%d-%d" % [map_group, map_index]

func map_id_for_location(map_group: int, map_index: int) -> String:
	return _map_id_for_location(map_group, map_index)

func content_id() -> String:
	return str(manifest.get("content_id", ""))

func map_data(map_id: String) -> Dictionary:
	for map_value in manifest.get("maps", []):
		if map_value is Dictionary and str(map_value.get("id", "")) == map_id:
			return map_value
	var reference: Dictionary = _map_reference_from_id(map_id)
	if not reference.is_empty():
		var descriptor: Dictionary = _read_map_descriptor(reference)
		if bool(descriptor.get("ok", false)):
			var name: String = _map_name_from_descriptor(descriptor)
			if name.is_empty():
				name = "Unlisted area"
			return {"id": map_id, "name": name, "map_group": int(reference.get("map_group", -1)), "map_index": int(reference.get("map_index", -1)), "width": int(descriptor.get("width", 0)), "height": int(descriptor.get("height", 0)), "music_id": int(descriptor.get("music_id", 0)), "map_type": int(descriptor.get("map_type", 0)), "region_map_section_id": int(descriptor.get("region_map_section_id", -1)), "floor_num": int(descriptor.get("floor_num", 0))}
	return {}

func _get_or_build_map_topology(map_id: String) -> Dictionary:
	var cached_topology: Dictionary = map_topology_cache.get(map_id, {})
	if not cached_topology.is_empty():
		return cached_topology
	var map_value: Dictionary = map_data(map_id)
	if map_value.is_empty():
		return {"ok": false, "error": "unknown map"}
	var descriptor: Dictionary = _read_map_descriptor(map_value)
	if not bool(descriptor.get("ok", false)):
		return descriptor
	var topology: Dictionary = {"ok": true, "map_id": map_id, "width": int(descriptor.get("width", 0)), "height": int(descriptor.get("height", 0)), "header_offset": int(descriptor.get("header_offset", -1)), "music_id": int(descriptor.get("music_id", 0)), "map_type": int(descriptor.get("map_type", 0)), "connections": _read_map_connections(int(descriptor.get("header_offset", -1)))}
	map_topology_cache[map_id] = topology
	return topology

func render_map(map_id: String, animation_tick: int = 0) -> Dictionary:
	var map_value: Dictionary = map_data(map_id)
	var cached_map: Dictionary = map_cache.get(map_id, {})
	if map_value.is_empty() and cached_map.is_empty():
		return {"ok": false, "error": "unknown map"}
	var source: Dictionary = manifest.get("source", {})
	if not bool(source_profile.get("supports_map_rendering", false)):
		return {"ok": false, "error": "%s map reader is not enabled yet" % str(source.get("game", "GBA"))}
	if cached_map.is_empty():
		cached_map = _get_or_build_map_cache(map_id, map_value)
	if not bool(cached_map.get("ok", false)):
		return cached_map
	var animation_phase: int = posmod(animation_tick, 40)
	var texture_cache: Dictionary = cached_map.get("textures", {})
	var image_cache: Dictionary = cached_map.get("images", {})
	var background_texture_cache: Dictionary = cached_map.get("background_textures", {})
	var foreground_texture_cache: Dictionary = cached_map.get("foreground_textures", {})
	var animated_tiles: Array = cached_map.get("animated_tiles", [])
	if animated_tiles.is_empty() or animation_phase == 0:
		var prepared: Dictionary = prepare_map(map_id)
		if not bool(prepared.get("ok", false)):
			return prepared
		prepared["image"] = cached_map.get("base_image") as Image
		prepared["animation_phase"] = animation_phase
		return prepared
	var cache_key: String = str(animation_phase)
	var texture: Texture2D = texture_cache.get(cache_key) as Texture2D
	var image: Image = image_cache.get(cache_key) as Image
	if texture == null or image == null:
		image = _render_cached_map(cached_map, animation_phase)
		texture = ImageTexture.create_from_image(image)
		texture_cache.clear()
		texture_cache[cache_key] = texture
		image_cache.clear()
		image_cache[cache_key] = image
		map_cache[map_id] = cached_map
	var background_texture: Texture2D = background_texture_cache.get(cache_key) as Texture2D
	if background_texture == null:
		var background_image: Image = _render_cached_layer(cached_map, animation_phase, false)
		background_texture = ImageTexture.create_from_image(background_image)
		background_texture_cache.clear()
		background_texture_cache[cache_key] = background_texture
	var foreground_texture: Texture2D = foreground_texture_cache.get(cache_key) as Texture2D
	if foreground_texture == null:
		var foreground_image: Image = _render_cached_layer(cached_map, animation_phase, true)
		foreground_texture = ImageTexture.create_from_image(foreground_image)
		foreground_texture_cache.clear()
		foreground_texture_cache[cache_key] = foreground_texture
	map_cache[map_id] = cached_map
	return {"ok": true, "texture": texture, "image": image, "background_texture": background_texture, "foreground_texture": foreground_texture, "width": int(cached_map.get("width", 0)), "height": int(cached_map.get("height", 0)), "header_offset": int(cached_map.get("header_offset", -1)), "layout_offset": int(cached_map.get("layout_offset", -1)), "objects": cached_map.get("objects", []), "warps": cached_map.get("warps", []), "connections": cached_map.get("connections", []), "map_cells": cached_map.get("map_cells", PackedInt32Array()), "music_id": int(cached_map.get("music_id", 0)), "map_type": int(cached_map.get("map_type", 0)), "animation_phase": animation_phase}

func prepare_map(map_id: String, include_composite_texture: bool = true) -> Dictionary:
	var cached_map: Dictionary = _get_or_build_map_cache(map_id)
	if not bool(cached_map.get("ok", false)):
		return cached_map
	var world_texture: Texture2D = cached_map.get("world_texture") as Texture2D
	var background_texture: Texture2D = cached_map.get("world_background_texture") as Texture2D
	var foreground_texture: Texture2D = cached_map.get("world_foreground_texture") as Texture2D
	if background_texture == null or foreground_texture == null:
		var background_image: Image = (cached_map.get("base_background_image") as Image).duplicate()
		var foreground_image: Image = (cached_map.get("base_foreground_image") as Image).duplicate()
		background_texture = ImageTexture.create_from_image(background_image)
		foreground_texture = ImageTexture.create_from_image(foreground_image)
		cached_map["world_texture"] = world_texture
		cached_map["world_background_texture"] = background_texture
		cached_map["world_foreground_texture"] = foreground_texture
	if include_composite_texture and world_texture == null:
		world_texture = ImageTexture.create_from_image((cached_map.get("base_background_image") as Image).duplicate())
		cached_map["world_texture"] = world_texture
	return {"ok": true, "texture": world_texture if world_texture != null else background_texture, "background_texture": background_texture, "foreground_texture": foreground_texture, "world_texture": world_texture, "width": int(cached_map.get("width", 0)), "height": int(cached_map.get("height", 0)), "header_offset": int(cached_map.get("header_offset", -1)), "layout_offset": int(cached_map.get("layout_offset", -1)), "objects": cached_map.get("objects", []), "warps": cached_map.get("warps", []), "connections": cached_map.get("connections", []), "animated_background_tiles": cached_map.get("animated_background_tiles", []), "animated_foreground_tiles": cached_map.get("animated_foreground_tiles", []), "map_cells": cached_map.get("map_cells", PackedInt32Array()), "music_id": int(cached_map.get("music_id", 0)), "map_type": int(cached_map.get("map_type", 0)), "animation_phase": 0}

func prepare_server_map(map_id: String, server_map: Dictionary, server_maps: Dictionary, include_composite_texture: bool = true) -> Dictionary:
	var cached_map: Dictionary = map_cache.get(map_id, {})
	if cached_map.is_empty():
		cached_map = _build_server_map_cache(map_id, server_map, server_maps)
		if bool(cached_map.get("ok", false)):
			map_cache[map_id] = cached_map
	if not bool(cached_map.get("ok", false)):
		return cached_map
	var world_texture: Texture2D = cached_map.get("world_texture") as Texture2D
	var background_texture: Texture2D = cached_map.get("world_background_texture") as Texture2D
	var foreground_texture: Texture2D = cached_map.get("world_foreground_texture") as Texture2D
	if background_texture == null or foreground_texture == null:
		background_texture = ImageTexture.create_from_image((cached_map.get("base_background_image") as Image).duplicate())
		foreground_texture = ImageTexture.create_from_image((cached_map.get("base_foreground_image") as Image).duplicate())
		cached_map["world_background_texture"] = background_texture
		cached_map["world_foreground_texture"] = foreground_texture
	if include_composite_texture and world_texture == null:
		world_texture = ImageTexture.create_from_image((cached_map.get("base_background_image") as Image).duplicate())
		cached_map["world_texture"] = world_texture
	return {"ok": true, "texture": world_texture if world_texture != null else background_texture, "background_texture": background_texture, "foreground_texture": foreground_texture, "world_texture": world_texture, "width": int(cached_map.get("width", 0)), "height": int(cached_map.get("height", 0)), "header_offset": -1, "layout_offset": -1, "objects": [], "warps": [], "connections": cached_map.get("connections", []), "animated_background_tiles": cached_map.get("animated_background_tiles", []), "animated_foreground_tiles": cached_map.get("animated_foreground_tiles", []), "map_cells": cached_map.get("map_cells", PackedInt32Array()), "music_id": int(cached_map.get("music_id", 0)), "map_type": int(cached_map.get("map_type", 0)), "animation_phase": 0}

func prepare_connected_world(root_map_id: String, max_maps: int = 96, preload_depth: int = 1, server_maps: Dictionary = {}) -> Dictionary:
	if root_map_id.is_empty() or max_maps <= 0 or preload_depth < 0:
		return {"ok": false, "error": "invalid connected-world root"}
	var regions: Array = []
	var placed: Dictionary = {}
	var queued: Dictionary = {root_map_id: true}
	var pending: Array = [{"map_id": root_map_id, "origin": Vector2i.ZERO, "depth": 0}]
	while not pending.is_empty() and regions.size() < max_maps:
		var pending_value: Variant = pending.pop_front()
		if not pending_value is Dictionary:
			continue
		var pending_map: Dictionary = pending_value
		var map_id: String = str(pending_map.get("map_id", ""))
		if map_id.is_empty() or placed.has(map_id):
			continue
		var topology: Dictionary = _connected_world_topology(map_id, server_maps)
		if not bool(topology.get("ok", false)):
			continue
		var origin: Vector2i = pending_map.get("origin", Vector2i.ZERO)
		var depth: int = int(pending_map.get("depth", 0))
		var width: int = int(topology.get("width", 0))
		var height: int = int(topology.get("height", 0))
		if width <= 0 or height <= 0:
			continue
		var server_map: Dictionary = _server_map_for_local_map(map_id, server_maps)
		var prepared: Dictionary = {}
		if depth <= preload_depth or _is_server_custom_map(server_map):
			prepared = prepare_server_map(map_id, server_map, server_maps, false) if _is_server_custom_map(server_map) else prepare_map(map_id, false)
		if map_id == root_map_id and not bool(prepared.get("ok", false)):
			return prepared
		var region: Dictionary = {"map_id": map_id, "origin": origin, "width": width, "height": height, "background_texture": prepared.get("background_texture"), "foreground_texture": prepared.get("foreground_texture"), "objects": prepared.get("objects", []), "warps": prepared.get("warps", []), "connections": topology.get("connections", []), "animated_background_tiles": prepared.get("animated_background_tiles", []), "animated_foreground_tiles": prepared.get("animated_foreground_tiles", []), "music_id": int(topology.get("music_id", 0)), "map_type": int(topology.get("map_type", 0)), "depth": depth, "ready": bool(prepared.get("ok", false))}
		regions.append(region)
		placed[map_id] = origin
		for connection_value in topology.get("connections", []):
			if not connection_value is Dictionary:
				continue
			var connection: Dictionary = connection_value
			var direction: int = int(connection.get("direction", 0))
			if direction < CONNECTION_SOUTH or direction > CONNECTION_EAST:
				continue
			var target_map_id: String = str(connection.get("map_id", ""))
			if target_map_id.is_empty() or placed.has(target_map_id) or queued.has(target_map_id):
				continue
			var target_topology: Dictionary = _connected_world_topology(target_map_id, server_maps)
			if not bool(target_topology.get("ok", false)):
				continue
			var target_width: int = int(target_topology.get("width", 0))
			var target_height: int = int(target_topology.get("height", 0))
			var target_origin: Vector2i = _connected_map_origin(origin, width, height, target_width, target_height, direction, int(connection.get("offset", 0)))
			queued[target_map_id] = true
			pending.append({"map_id": target_map_id, "origin": target_origin, "depth": depth + 1})
	if regions.is_empty():
		return {"ok": false, "error": "connected-world root map is not renderable"}
	var corner_regions: Array = _build_corner_filler_regions(regions, root_map_id)
	for corner_value in corner_regions:
		if not corner_value is Dictionary:
			continue
		var corner_region: Dictionary = corner_value
		regions.append(corner_region)
		placed[str(corner_region.get("map_id", ""))] = corner_region.get("origin", Vector2i.ZERO)
	return {"ok": true, "root_map_id": root_map_id, "regions": regions, "map_origins": placed}

func _build_corner_filler_regions(source_regions: Array, root_map_id: String) -> Array:
	var placed_regions: Array = []
	for region_value in source_regions:
		if not region_value is Dictionary:
			continue
		var region: Dictionary = region_value
		if bool(region.get("corner_filler", false)):
			continue
		if int(region.get("map_type", -1)) == MAP_TYPE_INSIDE or int(region.get("map_type", -1)) == MAP_TYPE_SECRET_BASE:
			continue
		if str(region.get("map_id", "")).is_empty():
			continue
		if int(region.get("width", 0)) <= 0 or int(region.get("height", 0)) <= 0:
			continue
		placed_regions.append(region)
	var gaps: Array = []
	var gap_keys: Dictionary = {}
	for center_value in placed_regions:
		var center: Dictionary = center_value
		var center_rect: Rect2i = _corner_region_rect(center)
		var top_regions: Array = _corner_touching_regions(center_rect, placed_regions, CONNECTION_NORTH)
		var bottom_regions: Array = _corner_touching_regions(center_rect, placed_regions, CONNECTION_SOUTH)
		var left_regions: Array = _corner_touching_regions(center_rect, placed_regions, CONNECTION_WEST)
		var right_regions: Array = _corner_touching_regions(center_rect, placed_regions, CONNECTION_EAST)
		for top_value in top_regions:
			var top: Dictionary = top_value
			var top_rect: Rect2i = _corner_region_rect(top)
			for side_value in left_regions:
				var side: Dictionary = side_value
				var side_rect: Rect2i = _corner_region_rect(side)
				_add_corner_gap(gaps, gap_keys, Rect2i(Vector2i(side_rect.position.x, top_rect.position.y), Vector2i(mini(center_rect.position.x, top_rect.position.x) - side_rect.position.x, mini(center_rect.position.y, side_rect.position.y) - top_rect.position.y)), placed_regions)
			for side_value in right_regions:
				var side: Dictionary = side_value
				var side_rect: Rect2i = _corner_region_rect(side)
				_add_corner_gap(gaps, gap_keys, Rect2i(Vector2i(maxi(center_rect.end.x, top_rect.end.x), top_rect.position.y), Vector2i(side_rect.end.x - maxi(center_rect.end.x, top_rect.end.x), mini(center_rect.position.y, side_rect.position.y) - top_rect.position.y)), placed_regions)
		for bottom_value in bottom_regions:
			var bottom: Dictionary = bottom_value
			var bottom_rect: Rect2i = _corner_region_rect(bottom)
			for side_value in left_regions:
				var side: Dictionary = side_value
				var side_rect: Rect2i = _corner_region_rect(side)
				_add_corner_gap(gaps, gap_keys, Rect2i(Vector2i(side_rect.position.x, maxi(center_rect.end.y, bottom_rect.end.y)), Vector2i(mini(center_rect.position.x, bottom_rect.position.x) - side_rect.position.x, bottom_rect.end.y - maxi(center_rect.end.y, side_rect.end.y))), placed_regions)
			for side_value in right_regions:
				var side: Dictionary = side_value
				var side_rect: Rect2i = _corner_region_rect(side)
				_add_corner_gap(gaps, gap_keys, Rect2i(Vector2i(maxi(center_rect.end.x, bottom_rect.end.x), maxi(center_rect.end.y, side_rect.end.y)), Vector2i(side_rect.end.x - maxi(center_rect.end.x, bottom_rect.end.x), bottom_rect.end.y - maxi(center_rect.end.y, side_rect.end.y))), placed_regions)
		for left_value in left_regions:
			var left_neighbor: Dictionary = left_value
			var left_neighbor_rect: Rect2i = _corner_region_rect(left_neighbor)
			for right_value in right_regions:
				var right_neighbor: Dictionary = right_value
				var right_neighbor_rect: Rect2i = _corner_region_rect(right_neighbor)
				var horizontal_gap_x: int = right_neighbor_rect.position.x - left_neighbor_rect.end.x
				var upper_gap_y: int = maxi(left_neighbor_rect.position.y, right_neighbor_rect.position.y)
				_add_corner_gap(gaps, gap_keys, Rect2i(Vector2i(left_neighbor_rect.end.x, upper_gap_y), Vector2i(horizontal_gap_x, center_rect.position.y - upper_gap_y)), placed_regions)
				var lower_gap_y: int = center_rect.end.y
				_add_corner_gap(gaps, gap_keys, Rect2i(Vector2i(left_neighbor_rect.end.x, lower_gap_y), Vector2i(horizontal_gap_x, mini(left_neighbor_rect.end.y, right_neighbor_rect.end.y) - lower_gap_y)), placed_regions)
		for top_value in top_regions:
			var top_neighbor: Dictionary = top_value
			var top_neighbor_rect: Rect2i = _corner_region_rect(top_neighbor)
			for bottom_value in bottom_regions:
				var bottom_neighbor: Dictionary = bottom_value
				var bottom_neighbor_rect: Rect2i = _corner_region_rect(bottom_neighbor)
				var vertical_gap_y: int = bottom_neighbor_rect.position.y - top_neighbor_rect.end.y
				var left_gap_x: int = maxi(top_neighbor_rect.position.x, bottom_neighbor_rect.position.x)
				_add_corner_gap(gaps, gap_keys, Rect2i(Vector2i(left_gap_x, top_neighbor_rect.end.y), Vector2i(center_rect.position.x - left_gap_x, vertical_gap_y)), placed_regions)
				_add_corner_gap(gaps, gap_keys, Rect2i(Vector2i(center_rect.end.x, top_neighbor_rect.end.y), Vector2i(mini(top_neighbor_rect.end.x, bottom_neighbor_rect.end.x) - center_rect.end.x, vertical_gap_y)), placed_regions)
	var filler_regions: Array = []
	var filler_index: int = 0
	for gap_value in gaps:
		if not gap_value is Rect2i:
			continue
		var gap: Rect2i = gap_value
		var links: Array = _corner_adjacent_links(gap, placed_regions)
		if links.is_empty():
			continue
		var donor_link: Dictionary = links[0]
		for link_value in links:
			var link: Dictionary = link_value
			if int(link.get("overlap", 0)) > int(donor_link.get("overlap", 0)):
				donor_link = link
		var donor: Dictionary = donor_link.get("region", {})
		var filler_id: String = "corner-filler:%s:%d:%d:%d:%d" % [root_map_id, gap.position.x, gap.position.y, gap.end.x, gap.end.y]
		var filler: Dictionary = _create_corner_filler_region(filler_id, gap, donor, filler_index)
		if filler.is_empty():
			continue
		filler_regions.append(filler)
		filler_index += 1
	return filler_regions

func _corner_region_rect(region: Dictionary) -> Rect2i:
	var origin: Vector2i = region.get("origin", Vector2i.ZERO)
	return Rect2i(origin, Vector2i(int(region.get("width", 0)), int(region.get("height", 0))))

func _corner_touching_regions(center: Rect2i, regions: Array, direction: int) -> Array:
	var result: Array = []
	for region_value in regions:
		if not region_value is Dictionary:
			continue
		var region: Dictionary = region_value
		var candidate: Rect2i = _corner_region_rect(region)
		var overlap: int = 0
		match direction:
			CONNECTION_NORTH, CONNECTION_SOUTH:
				overlap = _corner_x_overlap(center, candidate)
			CONNECTION_WEST, CONNECTION_EAST:
				overlap = _corner_y_overlap(center, candidate)
		if overlap <= 0:
			continue
		var touches: bool = false
		match direction:
			CONNECTION_NORTH:
				touches = candidate.end.y == center.position.y
			CONNECTION_SOUTH:
				touches = candidate.position.y == center.end.y
			CONNECTION_WEST:
				touches = candidate.end.x == center.position.x
			CONNECTION_EAST:
				touches = candidate.position.x == center.end.x
		if touches:
			result.append(region)
	return result

func _corner_x_overlap(first: Rect2i, second: Rect2i) -> int:
	return maxi(0, mini(first.end.x, second.end.x) - maxi(first.position.x, second.position.x))

func _corner_y_overlap(first: Rect2i, second: Rect2i) -> int:
	return maxi(0, mini(first.end.y, second.end.y) - maxi(first.position.y, second.position.y))

func _corner_rect_intersects(first: Rect2i, second: Rect2i) -> bool:
	return _corner_x_overlap(first, second) > 0 and _corner_y_overlap(first, second) > 0

func _add_corner_gap(gaps: Array, gap_keys: Dictionary, gap: Rect2i, regions: Array) -> void:
	if gap.size.x <= 0 or gap.size.y <= 0 or gap.size.x > MAX_CORNER_FILLER_SIZE or gap.size.y > MAX_CORNER_FILLER_SIZE:
		return
	for region_value in regions:
		if not region_value is Dictionary:
			continue
		if _corner_rect_intersects(gap, _corner_region_rect(region_value)):
			return
	if _corner_adjacent_links(gap, regions).is_empty():
		return
	var key: String = "%d:%d:%d:%d" % [gap.position.x, gap.position.y, gap.end.x, gap.end.y]
	if gap_keys.has(key):
		return
	gap_keys[key] = true
	gaps.append(gap)

func _corner_adjacent_links(gap: Rect2i, regions: Array) -> Array:
	var result: Array = []
	for region_value in regions:
		if not region_value is Dictionary:
			continue
		var region: Dictionary = region_value
		var host: Rect2i = _corner_region_rect(region)
		if host.end.y == gap.position.y:
			var overlap: int = _corner_x_overlap(host, gap)
			if overlap > 0:
				result.append({"region": region, "direction": CONNECTION_SOUTH, "offset": gap.position.x - host.position.x, "overlap": overlap})
		elif host.position.y == gap.end.y:
			var overlap: int = _corner_x_overlap(host, gap)
			if overlap > 0:
				result.append({"region": region, "direction": CONNECTION_NORTH, "offset": gap.position.x - host.position.x, "overlap": overlap})
		elif host.end.x == gap.position.x:
			var overlap: int = _corner_y_overlap(host, gap)
			if overlap > 0:
				result.append({"region": region, "direction": CONNECTION_EAST, "offset": gap.position.y - host.position.y, "overlap": overlap})
		elif host.position.x == gap.end.x:
			var overlap: int = _corner_y_overlap(host, gap)
			if overlap > 0:
				result.append({"region": region, "direction": CONNECTION_WEST, "offset": gap.position.y - host.position.y, "overlap": overlap})
	return result

func _create_corner_filler_region(filler_id: String, gap: Rect2i, donor: Dictionary, filler_index: int) -> Dictionary:
	var donor_id: String = str(donor.get("map_id", ""))
	var donor_cache: Dictionary = _get_or_build_map_cache(donor_id)
	if not bool(donor_cache.get("ok", false)):
		return {}
	var border_tiles: PackedInt32Array = donor_cache.get("border_tiles", PackedInt32Array())
	var border_width: int = int(donor_cache.get("border_width", 0))
	var border_height: int = int(donor_cache.get("border_height", 0))
	if border_width <= 0 or border_height <= 0 or border_tiles.size() < border_width * border_height:
		return {}
	var width: int = gap.size.x
	var height: int = gap.size.y
	var background_image: Image = Image.create(width * 16, height * 16, false, Image.FORMAT_RGBA8)
	background_image.fill(Color.BLACK)
	var foreground_image: Image = Image.create(width * 16, height * 16, false, Image.FORMAT_RGBA8)
	foreground_image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var animated_background_tiles: Array = []
	var animated_foreground_tiles: Array = []
	var primary: Dictionary = donor_cache.get("primary", {})
	var secondary: Dictionary = donor_cache.get("secondary", {})
	var primary_metatile_count: int = _format_int("primary_metatile_count", PRIMARY_METATILE_COUNT)
	var metatile_id_mask: int = _format_int("map_grid_metatile_id_mask", MAPGRID_METATILE_ID_MASK)
	for map_y in range(height):
		for map_x in range(width):
			var border_index: int = (map_y % border_height) * border_width + (map_x % border_width)
			var metatile_id: int = int(border_tiles[border_index]) & metatile_id_mask
			if metatile_id == _format_int("map_grid_undefined", MAPGRID_UNDEFINED):
				continue
			var tileset: Dictionary = primary
			var metatile_index: int = metatile_id
			if metatile_id >= primary_metatile_count:
				tileset = secondary
				metatile_index = metatile_id - primary_metatile_count
			_draw_metatile_layers(background_image, foreground_image, map_x * 16, map_y * 16, tileset, metatile_index, primary, secondary, animated_background_tiles, animated_foreground_tiles)
	var background_texture: ImageTexture = ImageTexture.create_from_image(background_image)
	var foreground_texture: ImageTexture = ImageTexture.create_from_image(foreground_image)
	var filler_cache: Dictionary = {"ok": true, "base_image": background_image, "base_background_image": background_image, "base_foreground_image": foreground_image, "primary": primary, "secondary": secondary, "primary_tiles": donor_cache.get("primary_tiles", PackedByteArray()), "primary_animation_enabled": bool(donor_cache.get("primary_animation_enabled", false)), "animated_tiles": [], "animated_background_tiles": animated_background_tiles, "animated_foreground_tiles": animated_foreground_tiles, "animated_primary_tiles": PackedByteArray(), "animated_tile_phase": -1, "animated_tile_textures": {}, "map_cells": PackedInt32Array(), "objects": [], "warps": [], "connections": [], "textures": {}, "images": {}, "background_textures": {}, "foreground_textures": {}, "width": width, "height": height, "header_offset": -1, "layout_offset": -1, "border_offset": -1, "border_width": border_width, "border_height": border_height, "border_tiles": border_tiles, "map_group": -1, "map_index": filler_index, "music_id": 0, "map_type": int(donor_cache.get("map_type", 0))}
	map_cache[filler_id] = filler_cache
	return {"map_id": filler_id, "origin": gap.position, "width": width, "height": height, "background_texture": background_texture, "foreground_texture": foreground_texture, "objects": [], "warps": [], "connections": [], "animated_background_tiles": animated_background_tiles, "animated_foreground_tiles": animated_foreground_tiles, "music_id": 0, "map_type": int(donor_cache.get("map_type", 0)), "ready": true, "corner_filler": true}

func _is_server_custom_map(server_map: Dictionary) -> bool:
	var custom_value: Variant = server_map.get("custom_map_gzip", PackedByteArray())
	return custom_value is PackedByteArray and not (custom_value as PackedByteArray).is_empty()

func _connected_world_topology(map_id: String, server_maps: Dictionary) -> Dictionary:
	var server_map: Dictionary = _server_map_for_local_map(map_id, server_maps)
	if not server_map.is_empty():
		var width: int = int(server_map.get("width", 0))
		var height: int = int(server_map.get("height", 0))
		if width > 0 and height > 0:
			var local_topology: Dictionary = _get_or_build_map_topology(map_id) if not _is_server_custom_map(server_map) else {}
			return {"ok": true, "map_id": map_id, "width": width, "height": height, "header_offset": int(local_topology.get("header_offset", -1)), "music_id": int(local_topology.get("music_id", 0)), "map_type": int(server_map.get("map_type", local_topology.get("map_type", 0))), "connections": _server_connections(server_map, server_maps)}
	return _get_or_build_map_topology(map_id)

func _server_connections(server_map: Dictionary, server_maps: Dictionary) -> Array:
	var connections: Array = []
	for connection_value in server_map.get("connections", []):
		if not connection_value is Dictionary:
			continue
		var connection: Dictionary = connection_value
		var target_map_id: String = _client_map_id_for_server_location(int(connection.get("bank_id", -1)), int(connection.get("map_id", -1)), server_maps)
		if target_map_id.is_empty():
			continue
		var direction: int = int(connection.get("direction", 0))
		if direction < CONNECTION_SOUTH or direction > CONNECTION_EAST:
			continue
		connections.append({"direction": direction, "offset": int(connection.get("offset", 0)), "map_id": target_map_id})
	return connections

func _client_map_id_for_server_location(bank_id: int, map_index: int, server_maps: Dictionary) -> String:
	for value in server_maps.values():
		if not value is Dictionary:
			continue
		var candidate: Dictionary = value
		if int(candidate.get("bank_id", -1)) != bank_id or int(candidate.get("map_id", -1)) != map_index:
			continue
		var candidate_map_id: String = str(candidate.get("local_map_id", ""))
		if not candidate_map_id.is_empty():
			return candidate_map_id
	return map_id_for_location(bank_id, map_index)

func _build_server_map_cache(map_id: String, server_map: Dictionary, server_maps: Dictionary) -> Dictionary:
	var width: int = int(server_map.get("width", 0))
	var height: int = int(server_map.get("height", 0))
	if width <= 0 or height <= 0 or width > 512 or height > 512:
		return {"ok": false, "error": "OpenMMO custom map dimensions are invalid"}
	var custom_value: Variant = server_map.get("custom_map_gzip", PackedByteArray())
	if not custom_value is PackedByteArray:
		return {"ok": false, "error": "OpenMMO custom map data is invalid"}
	var expected_bytes: int = width * height * 2
	var map_bytes: PackedByteArray = _gzip_decompress(custom_value as PackedByteArray, expected_bytes)
	if map_bytes.size() != expected_bytes:
		return {"ok": false, "error": "OpenMMO custom map data could not be decompressed"}
	var donor_cache: Dictionary = _server_map_donor_cache(server_map, server_maps)
	if not bool(donor_cache.get("ok", false)):
		return {"ok": false, "error": "OpenMMO custom map has no local tileset donor"}
	var primary: Dictionary = donor_cache.get("primary", {})
	var secondary: Dictionary = donor_cache.get("secondary", {})
	if primary.is_empty() or secondary.is_empty():
		return {"ok": false, "error": "OpenMMO custom map donor tileset is unavailable"}
	var map_cells: PackedInt32Array = PackedInt32Array()
	for cell_index in range(width * height):
		map_cells.append(int(map_bytes[cell_index * 2]) | int(map_bytes[cell_index * 2 + 1]) << 8)
	var background_image: Image = Image.create(width * 16, height * 16, false, Image.FORMAT_RGBA8)
	background_image.fill(Color.BLACK)
	var foreground_image: Image = Image.create(width * 16, height * 16, false, Image.FORMAT_RGBA8)
	foreground_image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var animated_background_tiles: Array = []
	var animated_foreground_tiles: Array = []
	var metatile_id_mask: int = _format_int("map_grid_metatile_id_mask", MAPGRID_METATILE_ID_MASK)
	var primary_metatile_count: int = _format_int("primary_metatile_count", PRIMARY_METATILE_COUNT)
	for map_y in range(height):
		for map_x in range(width):
			var metatile_id: int = int(map_cells[map_y * width + map_x]) & metatile_id_mask
			var tileset: Dictionary = primary if metatile_id < primary_metatile_count else secondary
			var metatile_index: int = metatile_id if metatile_id < primary_metatile_count else metatile_id - primary_metatile_count
			_draw_metatile_layers(background_image, foreground_image, map_x * 16, map_y * 16, tileset, metatile_index, primary, secondary, animated_background_tiles, animated_foreground_tiles)
	return {"ok": true, "base_image": background_image, "base_background_image": background_image, "base_foreground_image": foreground_image, "primary": primary, "secondary": secondary, "primary_tiles": primary.get("tiles", PackedByteArray()), "primary_animation_enabled": bool(primary.get("animation_enabled", false)), "animated_tiles": [], "animated_background_tiles": animated_background_tiles, "animated_foreground_tiles": animated_foreground_tiles, "map_cells": map_cells, "objects": [], "warps": [], "connections": _server_connections(server_map, server_maps), "textures": {}, "images": {}, "background_textures": {}, "foreground_textures": {}, "width": width, "height": height, "header_offset": -1, "layout_offset": -1, "border_offset": -1, "border_width": int(server_map.get("border_width", 0)), "border_height": int(server_map.get("border_height", 0)), "map_group": int(server_map.get("bank_id", -1)), "map_index": int(server_map.get("map_id", -1)), "music_id": 0, "map_type": int(server_map.get("map_type", 0))}

func _gzip_decompress(data: PackedByteArray, expected_bytes: int) -> PackedByteArray:
	if data.is_empty() or expected_bytes <= 0:
		return PackedByteArray()
	var stream: StreamPeerGZIP = StreamPeerGZIP.new()
	if stream.start_decompression(false, expected_bytes) != OK:
		return PackedByteArray()
	if stream.put_data(data) != OK:
		return PackedByteArray()
	var available_bytes: int = stream.get_available_bytes()
	if available_bytes != expected_bytes:
		return PackedByteArray()
	var result: Array = stream.get_data(expected_bytes)
	if result.size() != 2 or int(result[0]) != OK or not result[1] is PackedByteArray:
		return PackedByteArray()
	return result[1] as PackedByteArray

func _server_map_donor_cache(server_map: Dictionary, server_maps: Dictionary) -> Dictionary:
	for connection_value in server_map.get("connections", []):
		if not connection_value is Dictionary:
			continue
		var connection: Dictionary = connection_value
		var donor_map_id: String = _client_map_id_for_server_location(int(connection.get("bank_id", -1)), int(connection.get("map_id", -1)), server_maps)
		if donor_map_id.is_empty() or donor_map_id.begins_with("server-map-"):
			continue
		var donor_cache: Dictionary = _get_or_build_map_cache(donor_map_id)
		if bool(donor_cache.get("ok", false)):
			return donor_cache
	return {}

func _server_map_for_local_map(map_id: String, server_maps: Dictionary) -> Dictionary:
	var direct: Variant = server_maps.get(map_id, {})
	if direct is Dictionary and not (direct as Dictionary).is_empty():
		return direct
	var local_map: Dictionary = map_data(map_id)
	var local_bank: int = int(local_map.get("map_group", -1))
	var local_wire_map: int = int(local_map.get("map_index", -1))
	for value in server_maps.values():
		if not value is Dictionary:
			continue
		var candidate: Dictionary = value
		if str(candidate.get("local_map_id", "")) == map_id:
			return candidate
		if int(candidate.get("bank_id", -1)) == local_bank and int(candidate.get("map_id", -1)) == local_wire_map:
			return candidate
	return {}

func animated_tile_texture(map_id: String, tile_entry: int, animation_tick_value: int) -> Texture2D:
	var cached_map: Dictionary = _get_or_build_map_cache(map_id)
	if not bool(cached_map.get("ok", false)) or not bool(cached_map.get("primary_animation_enabled", false)):
		return null
	var phase: int = posmod(animation_tick_value, ANIMATION_PHASE_COUNT)
	if phase == 0:
		return null
	var tile_cache: Dictionary = cached_map.get("animated_tile_textures", {})
	var cached_phase: int = int(cached_map.get("animated_tile_phase", -1))
	if cached_phase != phase:
		tile_cache.clear()
		cached_map["animated_primary_tiles"] = _animated_primary_tiles(cached_map.get("primary_tiles", PackedByteArray()), phase, true)
		cached_map["animated_tile_phase"] = phase
	var cache_key: String = "%d:%d" % [phase, tile_entry]
	var cached_texture: Texture2D = tile_cache.get(cache_key) as Texture2D
	if cached_texture != null:
		return cached_texture
	var image: Image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var ignored_animated_tiles: Array = []
	_draw_tile(image, 0, 0, tile_entry, cached_map.get("primary", {}), cached_map.get("secondary", {}), ignored_animated_tiles, cached_map.get("animated_primary_tiles", PackedByteArray()))
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	tile_cache[cache_key] = texture
	cached_map["animated_tile_textures"] = tile_cache
	map_cache[map_id] = cached_map
	return texture

func _connected_map_origin(origin: Vector2i, width: int, height: int, target_width: int, target_height: int, direction: int, offset: int) -> Vector2i:
	match direction:
		CONNECTION_SOUTH:
			return Vector2i(origin.x + offset, origin.y + height)
		CONNECTION_NORTH:
			return Vector2i(origin.x + offset, origin.y - target_height)
		CONNECTION_WEST:
			return Vector2i(origin.x - target_width, origin.y + offset)
		CONNECTION_EAST:
			return Vector2i(origin.x + width, origin.y + offset)
	return origin

func has_animated_tiles(map_id: String) -> bool:
	var cached_map: Dictionary = _get_or_build_map_cache(map_id)
	return bool(cached_map.get("ok", false)) and not (cached_map.get("animated_tiles", []) as Array).is_empty()

func _get_or_build_map_cache(map_id: String, map_value: Dictionary = {}) -> Dictionary:
	var cached_map: Dictionary = map_cache.get(map_id, {})
	if not cached_map.is_empty():
		return cached_map
	var selected_map: Dictionary = map_value if not map_value.is_empty() else map_data(map_id)
	if selected_map.is_empty():
		return {"ok": false, "error": "unknown map"}
	var built_map: Dictionary = _build_map_cache(map_id, selected_map)
	if bool(built_map.get("ok", false)):
		map_cache[map_id] = built_map
	return built_map

func _build_map_cache(map_id: String, map_value: Dictionary) -> Dictionary:
	var descriptor: Dictionary = _read_map_descriptor(map_value)
	if not bool(descriptor.get("ok", false)):
		return descriptor
	var header_offset: int = int(descriptor.get("header_offset", -1))
	var layout_offset: int = int(descriptor.get("layout_offset", -1))
	var width: int = int(descriptor.get("width", 0))
	var height: int = int(descriptor.get("height", 0))
	var expected_width: int = int(map_value.get("width", 0))
	var expected_height: int = int(map_value.get("height", 0))
	if expected_width > 0 and expected_height > 0 and (width != expected_width or height != expected_height):
		return {"ok": false, "error": "FireRed map layout dimensions do not match the selected map"}
	var map_offset: int = int(descriptor.get("map_offset", -1))
	var primary_offset: int = int(descriptor.get("primary_offset", -1))
	var secondary_offset: int = int(descriptor.get("secondary_offset", -1))
	var map_bytes: int = width * height * 2
	if map_offset < 0 or not _valid_range(map_offset, map_bytes):
		return {"ok": false, "error": "could not read the FireRed map cells"}
	var map_cells: PackedInt32Array = PackedInt32Array()
	var metatile_id_mask: int = _format_int("map_grid_metatile_id_mask", MAPGRID_METATILE_ID_MASK)
	var undefined_metatile: int = _format_int("map_grid_undefined", MAPGRID_UNDEFINED)
	var primary_metatile_count: int = _format_int("primary_metatile_count", PRIMARY_METATILE_COUNT)
	var max_secondary_metatile: int = -1
	for cell_index in range(width * height):
		var map_word: int = _read_u16(map_offset + cell_index * 2)
		map_cells.append(map_word)
		var metatile_id: int = map_word & metatile_id_mask
		if metatile_id != undefined_metatile and metatile_id >= primary_metatile_count:
			max_secondary_metatile = maxi(max_secondary_metatile, metatile_id - primary_metatile_count)
	var primary: Dictionary = _read_tileset(primary_offset, _format_int("primary_tile_count", PRIMARY_TILE_COUNT), primary_metatile_count, _format_int("primary_palette_count", PRIMARY_PALETTE_COUNT))
	var secondary: Dictionary = _read_tileset(secondary_offset, 0, maxi(max_secondary_metatile + 1, 1), _format_int("secondary_rom_palette_count", SECONDARY_ROM_PALETTE_COUNT))
	if primary.is_empty() or secondary.is_empty():
		return {"ok": false, "error": "could not read the FireRed map tilesets"}
	primary["is_secondary"] = false
	secondary["is_secondary"] = true
	primary["animation_enabled"] = _tileset_animation_enabled(primary)
	secondary["animation_enabled"] = false
	var image: Image = Image.create(width * 16, height * 16, false, Image.FORMAT_RGBA8)
	image.fill(Color.BLACK)
	var background_image: Image = Image.create(width * 16, height * 16, false, Image.FORMAT_RGBA8)
	background_image.fill(Color.BLACK)
	var foreground_image: Image = Image.create(width * 16, height * 16, false, Image.FORMAT_RGBA8)
	foreground_image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var animated_tiles: Array = []
	var animated_background_tiles: Array = []
	var animated_foreground_tiles: Array = []
	for map_y in range(height):
		for map_x in range(width):
			var map_word: int = map_cells[map_y * width + map_x]
			var metatile_id: int = map_word & metatile_id_mask
			var tileset: Dictionary = primary
			var metatile_index: int = metatile_id
			if metatile_id >= primary_metatile_count:
				tileset = secondary
				metatile_index = metatile_id - primary_metatile_count
			_draw_metatile(image, map_x * 16, map_y * 16, tileset, metatile_index, primary, secondary, animated_tiles)
			_draw_metatile_layers(background_image, foreground_image, map_x * 16, map_y * 16, tileset, metatile_index, primary, secondary, animated_background_tiles, animated_foreground_tiles)
	var objects: Array = _read_map_objects(header_offset, map_id)
	objects.append_array(_read_map_background_events(header_offset, map_id))
	var border_offset: int = int(descriptor.get("border_offset", -1))
	var border_width: int = int(descriptor.get("border_width", 0))
	var border_height: int = int(descriptor.get("border_height", 0))
	var border_tiles: PackedInt32Array = PackedInt32Array()
	var border_bytes: int = border_width * border_height * 2
	if border_width > 0 and border_height > 0 and border_offset >= 0 and _valid_range(border_offset, border_bytes):
		for border_index in range(border_width * border_height):
			border_tiles.append(_read_u16(border_offset + border_index * 2))
	return {"ok": true, "base_image": image, "base_background_image": background_image, "base_foreground_image": foreground_image, "primary": primary, "secondary": secondary, "primary_tiles": primary.get("tiles", PackedByteArray()), "primary_animation_enabled": bool(primary.get("animation_enabled", false)), "animated_tiles": animated_tiles, "animated_background_tiles": animated_background_tiles, "animated_foreground_tiles": animated_foreground_tiles, "map_cells": map_cells, "objects": objects, "warps": _read_map_warps(header_offset), "connections": _read_map_connections(header_offset), "textures": {}, "images": {}, "background_textures": {}, "foreground_textures": {}, "width": width, "height": height, "header_offset": header_offset, "layout_offset": layout_offset, "border_offset": border_offset, "border_width": border_width, "border_height": border_height, "border_tiles": border_tiles, "map_group": int(map_value.get("map_group", -1)), "map_index": int(map_value.get("map_index", -1)), "music_id": int(map_value.get("music_id", 0))}

func map_cell(map_id: String, x: int, y: int) -> Dictionary:
	var cached_map: Dictionary = _get_or_build_map_cache(map_id)
	if not bool(cached_map.get("ok", false)):
		return cached_map
	return _map_cell_from_cache(cached_map, x, y)

func _map_cell_from_cache(cached_map: Dictionary, x: int, y: int) -> Dictionary:
	var width: int = int(cached_map.get("width", 0))
	var height: int = int(cached_map.get("height", 0))
	if x < 0 or y < 0 or x >= width or y >= height:
		return {"ok": false, "undefined": true, "collision": 1, "elevation": 0, "behavior": 0}
	var map_cells: PackedInt32Array = cached_map.get("map_cells", PackedInt32Array())
	var map_word: int = int(map_cells[y * width + x])
	var metatile_id_mask: int = _format_int("map_grid_metatile_id_mask", MAPGRID_METATILE_ID_MASK)
	var collision_mask: int = _format_int("map_grid_collision_mask", MAPGRID_COLLISION_MASK)
	var collision_shift: int = _format_int("map_grid_collision_shift", MAPGRID_COLLISION_SHIFT)
	var elevation_mask: int = _format_int("map_grid_elevation_mask", MAPGRID_ELEVATION_MASK)
	var elevation_shift: int = _format_int("map_grid_elevation_shift", MAPGRID_ELEVATION_SHIFT)
	var undefined_metatile: int = _format_int("map_grid_undefined", MAPGRID_UNDEFINED)
	var metatile_id: int = map_word & metatile_id_mask
	var undefined: bool = metatile_id == undefined_metatile
	var attributes: int = _metatile_attributes(cached_map, metatile_id)
	return {"ok": true, "undefined": undefined, "map_word": map_word, "metatile_id": metatile_id, "collision": 1 if undefined else ((map_word & collision_mask) >> collision_shift), "elevation": (map_word & elevation_mask) >> elevation_shift, "behavior": attributes & _format_int("metatile_behavior_mask", METATILE_BEHAVIOR_MASK), "attributes": attributes, "layer_type": (attributes & _format_int("map_grid_layer_type_mask", MAPGRID_LAYER_TYPE_MASK)) >> _format_int("map_grid_layer_type_shift", MAPGRID_LAYER_TYPE_SHIFT)}

func _metatile_attributes(cached_map: Dictionary, metatile_id: int) -> int:
	if metatile_id == _format_int("map_grid_undefined", MAPGRID_UNDEFINED):
		return 0
	var primary_metatile_count: int = _format_int("primary_metatile_count", PRIMARY_METATILE_COUNT)
	var tileset: Dictionary = cached_map.get("primary", {}) if metatile_id < primary_metatile_count else cached_map.get("secondary", {})
	var attribute_index: int = metatile_id if metatile_id < primary_metatile_count else metatile_id - primary_metatile_count
	var attributes: PackedInt32Array = tileset.get("attributes", PackedInt32Array())
	return int(attributes[attribute_index]) if attribute_index >= 0 and attribute_index < attributes.size() else 0

func default_spawn(map_id: String) -> Dictionary:
	var cached_map: Dictionary = _get_or_build_map_cache(map_id)
	if not bool(cached_map.get("ok", false)):
		return cached_map
	var width: int = int(cached_map.get("width", 0))
	var height: int = int(cached_map.get("height", 0))
	var center: Vector2i = Vector2i(width / 2, height / 2)
	var objects: Array = cached_map.get("objects", [])
	var best_position: Vector2i = center
	var best_distance: int = 1 << 30
	for y in range(height):
		for x in range(width):
			var cell: Dictionary = _map_cell_from_cache(cached_map, x, y)
			if not _cell_can_stand(cell) or _position_occupied(objects, x, y):
				continue
			var distance: int = absi(x - center.x) + absi(y - center.y)
			if distance < best_distance:
				best_distance = distance
				best_position = Vector2i(x, y)
	var spawn_cell: Dictionary = _map_cell_from_cache(cached_map, best_position.x, best_position.y)
	var elevation: int = int(spawn_cell.get("elevation", 0))
	if elevation == 0 or elevation == 15:
		elevation = 3
	return {"ok": true, "map_id": map_id, "x": best_position.x, "y": best_position.y, "elevation": elevation}

func can_walk(map_id: String, from_x: int, from_y: int, to_x: int, to_y: int, elevation: int = 3, occupied: Variant = null) -> bool:
	var cached_map: Dictionary = _get_or_build_map_cache(map_id)
	if not bool(cached_map.get("ok", false)):
		return false
	var dx: int = to_x - from_x
	var dy: int = to_y - from_y
	var direction: int = _direction_from_delta(dx, dy)
	if direction == 0:
		return false
	var destination: Dictionary = _map_cell_from_cache(cached_map, to_x, to_y)
	if not bool(destination.get("ok", false)) or bool(destination.get("undefined", false)):
		return false
	var destination_warp: Dictionary = _warp_record_at(cached_map, to_x, to_y, elevation)
	if not _cell_can_stand_for_direction(destination, direction) and destination_warp.is_empty():
		return false
	var occupied_objects: Array = cached_map.get("objects", []) if occupied == null else occupied
	if _position_occupied(occupied_objects, to_x, to_y):
		return false
	if not _elevations_compatible(elevation, int(destination.get("elevation", 0))):
		return false
	if destination_warp.is_empty() and _directionally_blocked(int(destination.get("behavior", 0)), direction):
		return false
	var source: Dictionary = _map_cell_from_cache(cached_map, from_x, from_y)
	if _directionally_blocked(int(source.get("behavior", 0)), _opposite_direction(direction)):
		return false
	return true

func movement_result(map_id: String, x: int, y: int, direction: int, elevation: int = 3, occupied: Variant = null) -> Dictionary:
	var vector: Vector2i = _direction_vector(direction)
	if vector == Vector2i.ZERO:
		return {"ok": false, "error": "invalid movement direction"}
	var destination: Vector2i = Vector2i(x, y) + vector
	var map_value: Dictionary = map_data(map_id)
	if map_value.is_empty():
		return {"ok": false, "error": "unknown map"}
	var width: int = int(map_value.get("width", 0))
	var height: int = int(map_value.get("height", 0))
	if destination.x < 0 or destination.y < 0 or destination.x >= width or destination.y >= height:
		return _movement_through_connection(map_id, x, y, direction, elevation, occupied)
	var source_cell: Dictionary = map_cell(map_id, x, y)
	var source_behavior: int = int(source_cell.get("behavior", 0))
	if _is_directional_stair_warp_behavior(source_behavior, direction):
		var stair_warp: Dictionary = warp_at(map_id, x, y, elevation)
		if bool(stair_warp.get("ok", false)):
			return {"ok": true, "map_id": map_id, "x": x, "y": y, "from_x": x, "from_y": y, "jump": false, "stair": true, "stair_behavior": source_behavior, "warp": stair_warp, "elevation": elevation}
	if not can_walk(map_id, x, y, destination.x, destination.y, elevation, occupied):
		return {"ok": false, "error": "blocked"}
	var destination_cell: Dictionary = map_cell(map_id, destination.x, destination.y)
	if _jump_direction(int(destination_cell.get("behavior", 0))) == direction:
		var landing: Vector2i = destination + vector
		if landing.x < 0 or landing.y < 0 or landing.x >= width or landing.y >= height or not can_walk(map_id, destination.x, destination.y, landing.x, landing.y, elevation, occupied):
			return {"ok": false, "error": "jump landing is blocked"}
		return {"ok": true, "map_id": map_id, "x": landing.x, "y": landing.y, "from_x": x, "from_y": y, "intermediate_x": destination.x, "intermediate_y": destination.y, "jump": true, "elevation": int(_map_cell_from_cache(_get_or_build_map_cache(map_id), landing.x, landing.y).get("elevation", elevation))}
	var destination_warp: Dictionary = warp_at(map_id, destination.x, destination.y, elevation)
	var has_door_warp: bool = bool(destination_warp.get("ok", false))
	return {"ok": true, "map_id": map_id, "x": destination.x, "y": destination.y, "from_x": x, "from_y": y, "jump": false, "stair": false, "door": has_door_warp, "warp": destination_warp if has_door_warp else {}, "elevation": int(destination_cell.get("elevation", elevation))}

func interaction_at(map_id: String, x: int, y: int, direction: int, elevation: int = 3, visible_objects: Array = []) -> Dictionary:
	var vector: Vector2i = _direction_vector(direction)
	if vector == Vector2i.ZERO:
		return {"ok": false, "error": "invalid interaction direction"}
	var objects_to_check: Array = visible_objects
	if objects_to_check.is_empty():
		var cached_map: Dictionary = _get_or_build_map_cache(map_id)
		objects_to_check = cached_map.get("objects", [])
	var target: Vector2i = Vector2i(x, y) + vector
	for object_value in objects_to_check:
		if not object_value is Dictionary:
			continue
		var object: Dictionary = object_value
		if not bool(object.get("interactable", true)):
			continue
		if int(object.get("x", -1)) != target.x or int(object.get("y", -1)) != target.y:
			continue
		var object_elevation: int = int(object.get("elevation", elevation))
		if object_elevation != 0 and object_elevation != elevation:
			continue
		var background_kind: int = int(object.get("background_kind", 0))
		if background_kind > 0 and background_kind != direction:
			continue
		var pages: Array = object.get("dialogue_pages", [])
		var text: String = str(pages[0]) if not pages.is_empty() else "Someone is standing here."
		return {"ok": true, "kind": str(object.get("kind", "object")), "dialogue_id": str(object.get("dialogue_id", "")), "pages": pages, "text": text, "object": object}
	return {"ok": false, "error": "nothing to interact with"}

func _movement_through_connection(map_id: String, x: int, y: int, direction: int, elevation: int, occupied: Variant = null) -> Dictionary:
	var cached_map: Dictionary = _get_or_build_map_cache(map_id)
	if not bool(cached_map.get("ok", false)):
		return cached_map
	for connection_value in cached_map.get("connections", []):
		if not connection_value is Dictionary or int(connection_value.get("direction", 0)) != direction:
			continue
		var connection: Dictionary = connection_value
		var target_map_id: String = str(connection.get("map_id", ""))
		var target_map: Dictionary = map_data(target_map_id)
		var target_cache: Dictionary = _get_or_build_map_cache(target_map_id, target_map)
		if not bool(target_cache.get("ok", false)):
			continue
		var offset: int = int(connection.get("offset", 0))
		var target_x: int = 0
		var target_y: int = 0
		match direction:
			CONNECTION_EAST:
				target_x = 0
				target_y = y - offset
			CONNECTION_WEST:
				target_x = int(target_cache.get("width", 0)) - 1
				target_y = y - offset
			CONNECTION_SOUTH:
				target_x = x - offset
				target_y = 0
			CONNECTION_NORTH:
				target_x = x - offset
				target_y = int(target_cache.get("height", 0)) - 1
		var target_cell: Dictionary = _map_cell_from_cache(target_cache, target_x, target_y)
		var target_occupied: Array = target_cache.get("objects", []) if occupied == null else occupied
		if not _cell_can_stand(target_cell) or _position_occupied(target_occupied, target_x, target_y):
			continue
		var target_elevation: int = int(target_cell.get("elevation", elevation))
		if target_elevation == 0 or target_elevation == 15:
			target_elevation = elevation
		if not _elevations_compatible(elevation, target_elevation):
			continue
		return {"ok": true, "map_id": target_map_id, "x": target_x, "y": target_y, "from_x": x, "from_y": y, "transition": true, "jump": false, "elevation": target_elevation}
	return {"ok": false, "error": "map edge is blocked"}

func warp_at(map_id: String, x: int, y: int, elevation: int = 3) -> Dictionary:
	var cached_map: Dictionary = _get_or_build_map_cache(map_id)
	if not bool(cached_map.get("ok", false)):
		return cached_map
	for warp_value in cached_map.get("warps", []):
		if not warp_value is Dictionary:
			continue
		var warp: Dictionary = warp_value
		if int(warp.get("x", -1)) != x or int(warp.get("y", -1)) != y:
			continue
		var warp_elevation: int = int(warp.get("elevation", 0))
		if warp_elevation != 0 and warp_elevation != elevation:
			continue
		var target_map_id: String = str(warp.get("map_id", ""))
		var target_cache: Dictionary = _get_or_build_map_cache(target_map_id)
		if not bool(target_cache.get("ok", false)):
			return {"ok": false, "error": "warp destination is not available"}
		var destination_warp_id: int = int(warp.get("warp_id", -1))
		var destination_x: int = -1
		var destination_y: int = -1
		var destination_elevation: int = elevation
		var target_warps: Array = target_cache.get("warps", [])
		if destination_warp_id >= 0 and destination_warp_id < target_warps.size() and target_warps[destination_warp_id] is Dictionary:
			var destination_warp: Dictionary = target_warps[destination_warp_id]
			destination_x = int(destination_warp.get("x", -1))
			destination_y = int(destination_warp.get("y", -1))
			destination_elevation = int(destination_warp.get("elevation", destination_elevation))
		if destination_x < 0 or destination_y < 0:
			var spawn: Dictionary = default_spawn(target_map_id)
			if not bool(spawn.get("ok", false)):
				return spawn
			destination_x = int(spawn.get("x", 0))
			destination_y = int(spawn.get("y", 0))
			destination_elevation = int(spawn.get("elevation", destination_elevation))
		return {"ok": true, "map_id": target_map_id, "x": destination_x, "y": destination_y, "elevation": destination_elevation, "warp": true}
	return {"ok": false, "error": "no warp at position"}

func _warp_record_at(cached_map: Dictionary, x: int, y: int, elevation: int = -1) -> Dictionary:
	for warp_value in cached_map.get("warps", []):
		if not warp_value is Dictionary:
			continue
		var warp: Dictionary = warp_value
		if int(warp.get("x", -1)) != x or int(warp.get("y", -1)) != y:
			continue
		var warp_elevation: int = int(warp.get("elevation", 0))
		if elevation >= 0 and warp_elevation != 0 and warp_elevation != elevation:
			continue
		return warp
	return {}

func _cell_can_stand(cell: Dictionary) -> bool:
	return bool(cell.get("ok", false)) and not bool(cell.get("undefined", false)) and int(cell.get("collision", 1)) == 0

func _cell_can_stand_for_direction(cell: Dictionary, direction: int) -> bool:
	if _cell_can_stand(cell):
		return true
	return (direction == CONNECTION_NORTH or direction == CONNECTION_SOUTH) and int(cell.get("behavior", 0)) == _format_int("rock_stairs_behavior", ROCK_STAIRS_BEHAVIOR)

func _position_occupied(objects: Array, x: int, y: int) -> bool:
	for object_value in objects:
		if object_value is Dictionary and bool(object_value.get("blocks_movement", true)) and int(object_value.get("x", -1)) == x and int(object_value.get("y", -1)) == y:
			return true
	return false

func _elevations_compatible(source_elevation: int, destination_elevation: int) -> bool:
	return source_elevation == 0 or destination_elevation == 0 or destination_elevation == 15 or source_elevation == destination_elevation

func _directionally_blocked(behavior: int, direction: int) -> bool:
	match direction:
		1:
			return behavior == 0x33 or behavior == 0x36 or behavior == 0x37
		2:
			return behavior == 0x32 or behavior == 0x34 or behavior == 0x35
		3:
			return behavior == 0x31 or behavior == 0x35 or behavior == 0x37
		4:
			return behavior == 0x30 or behavior == 0x34 or behavior == 0x36
	return false

func _jump_direction(behavior: int) -> int:
	match behavior:
		0x38:
			return CONNECTION_EAST
		0x39:
			return CONNECTION_WEST
		0x3A:
			return CONNECTION_NORTH
		0x3B:
			return CONNECTION_SOUTH
	return 0

func _is_stair_warp_behavior(behavior: int) -> bool:
	var format: Dictionary = source_profile.get("format", {})
	var stair_behaviors: Array = format.get("stair_warp_behaviors", [0x6C, 0x6D, 0x6E, 0x6F])
	return stair_behaviors.has(behavior)

func _is_directional_stair_warp_behavior(behavior: int, direction: int) -> bool:
	if direction == CONNECTION_WEST:
		return behavior == 0x6D or behavior == 0x6F
	if direction == CONNECTION_EAST:
		return behavior == 0x6C or behavior == 0x6E
	return false

func _direction_from_delta(dx: int, dy: int) -> int:
	if dx == 0 and dy == 1:
		return CONNECTION_SOUTH
	if dx == 0 and dy == -1:
		return CONNECTION_NORTH
	if dx == -1 and dy == 0:
		return CONNECTION_WEST
	if dx == 1 and dy == 0:
		return CONNECTION_EAST
	return 0

func _opposite_direction(direction: int) -> int:
	match direction:
		CONNECTION_SOUTH:
			return CONNECTION_NORTH
		CONNECTION_NORTH:
			return CONNECTION_SOUTH
		CONNECTION_WEST:
			return CONNECTION_EAST
		CONNECTION_EAST:
			return CONNECTION_WEST
	return 0

func _direction_vector(direction: int) -> Vector2i:
	match direction:
		CONNECTION_SOUTH:
			return Vector2i(0, 1)
		CONNECTION_NORTH:
			return Vector2i(0, -1)
		CONNECTION_WEST:
			return Vector2i(-1, 0)
		CONNECTION_EAST:
			return Vector2i(1, 0)
	return Vector2i.ZERO

func _render_cached_map(cached_map: Dictionary, animation_phase: int) -> Image:
	var animated_tiles: Array = cached_map.get("animated_tiles", [])
	if animated_tiles.is_empty() or animation_phase == 0:
		return (cached_map.get("base_image") as Image).duplicate()
	var image: Image = (cached_map.get("base_image") as Image).duplicate()
	var primary: Dictionary = cached_map.get("primary", {})
	var secondary: Dictionary = cached_map.get("secondary", {})
	var animated_primary: PackedByteArray = _animated_primary_tiles(cached_map.get("primary_tiles", PackedByteArray()), animation_phase, bool(cached_map.get("primary_animation_enabled", false)))
	var ignored_animated_tiles: Array = []
	for tile_value in animated_tiles:
		if tile_value is Dictionary:
			var tile: Dictionary = tile_value
			_draw_tile(image, int(tile.get("x", 0)), int(tile.get("y", 0)), int(tile.get("entry", 0)), primary, secondary, ignored_animated_tiles, animated_primary)
	return image

func _render_cached_layer(cached_map: Dictionary, animation_phase: int, foreground: bool) -> Image:
	var image: Image = (cached_map.get("base_foreground_image" if foreground else "base_background_image") as Image).duplicate()
	var primary: Dictionary = cached_map.get("primary", {})
	var secondary: Dictionary = cached_map.get("secondary", {})
	var animated_primary: PackedByteArray = _animated_primary_tiles(cached_map.get("primary_tiles", PackedByteArray()), animation_phase, bool(cached_map.get("primary_animation_enabled", false))) if animation_phase != 0 else PackedByteArray()
	var animated_tiles: Array = cached_map.get("animated_foreground_tiles" if foreground else "animated_background_tiles", [])
	var ignored_animated_tiles: Array = []
	for tile_value in animated_tiles:
		if tile_value is Dictionary:
			var tile: Dictionary = tile_value
			_draw_tile(image, int(tile.get("x", 0)), int(tile.get("y", 0)), int(tile.get("entry", 0)), primary, secondary, ignored_animated_tiles, animated_primary)
	return image

func _animated_primary_tiles(base_tiles: PackedByteArray, animation_phase: int, enabled: bool) -> PackedByteArray:
	var tiles: PackedByteArray = base_tiles.duplicate()
	if not enabled:
		return tiles
	var tile_bytes: int = _format_int("tile_bytes", TILE_BYTES)
	var water_offsets: Array = _animation_offsets("water")
	var sand_offsets: Array = _animation_offsets("sand")
	var flower_offsets: Array = _animation_offsets("flower")
	if not water_offsets.is_empty():
		_copy_rom_bytes(tiles, _format_int("water_tile_index", 416) * tile_bytes, int(water_offsets[animation_phase % water_offsets.size()]), _format_int("water_tile_count", 48) * tile_bytes)
	if not sand_offsets.is_empty():
		_copy_rom_bytes(tiles, _format_int("sand_tile_index", 464) * tile_bytes, int(sand_offsets[animation_phase % sand_offsets.size()]), _format_int("sand_tile_count", 18) * tile_bytes)
	if not flower_offsets.is_empty():
		_copy_rom_bytes(tiles, _format_int("flower_tile_index", 508) * tile_bytes, int(flower_offsets[animation_phase % flower_offsets.size()]), _format_int("flower_tile_count", 4) * tile_bytes)
	return tiles

func _copy_rom_bytes(destination: PackedByteArray, destination_offset: int, source_offset: int, length: int) -> void:
	if destination_offset < 0 or destination_offset + length > destination.size() or not _valid_range(source_offset, length):
		return
	for index in range(length):
		destination[destination_offset + index] = rom_data[source_offset + index]

func _read_map_objects(header_offset: int, map_id: String) -> Array:
	var objects: Array = []
	var events_offset: int = _read_rom_pointer(header_offset + 4)
	var events_header_size: int = _format_int("map_events_header_size", MAP_EVENTS_HEADER_SIZE)
	var object_event_size: int = _format_int("map_object_event_size", MAP_OBJECT_EVENT_SIZE)
	if events_offset < 0 or not _valid_range(events_offset, events_header_size):
		return objects
	var object_count: int = int(rom_data[events_offset])
	var objects_offset: int = _read_rom_pointer(events_offset + 4)
	if object_count <= 0 or objects_offset < 0 or not _valid_range(objects_offset, object_count * object_event_size):
		return objects
	for object_index in range(object_count):
		var offset: int = objects_offset + object_index * object_event_size
		var kind: int = int(rom_data[offset + 2])
		if kind != 0:
			continue
		var graphics_id: int = int(rom_data[offset + 1])
		var movement_type: int = int(rom_data[offset + 9])
		var default_facing: int = _initial_object_facing(movement_type)
		var sprite: Dictionary = render_object_sprite(graphics_id, 0)
		if not bool(sprite.get("ok", false)):
			continue
		var local_id: int = int(rom_data[offset])
		var script_offset: int = _read_rom_pointer(offset + 0x10)
		var dialogue: Dictionary = _read_dialogue_for_script(script_offset)
		if not dialogue.is_empty():
			dialogue["id"] = "%s:%d" % [map_id, local_id]
			_register_dialogue(map_id, local_id, script_offset, dialogue)
		objects.append({"kind": "object", "local_id": local_id, "graphics_id": graphics_id, "resolved_graphics_id": int(sprite.get("resolved_graphics_id", graphics_id)), "x": _read_s16(offset + 4), "y": _read_s16(offset + 6), "elevation": int(rom_data[offset + 8]), "movement_type": movement_type, "default_facing": default_facing, "facing": default_facing, "script_offset": script_offset, "dialogue_id": str(dialogue.get("id", "")), "dialogue_pages": dialogue.get("pages", []), "texture": sprite.get("texture"), "width": int(sprite.get("width", 0)), "height": int(sprite.get("height", 0)), "frame_count": int(sprite.get("frame_count", 1)), "render": true, "blocks_movement": true, "interactable": true})
	return objects

func _initial_object_facing(movement_type: int) -> int:
	match movement_type:
		0x03, 0x07, 0x19, 0x1D, 0x21, 0x26, 0x2A, 0x2D, 0x31, 0x40, 0x45:
			return CONNECTION_NORTH
		0x04, 0x08, 0x1A, 0x1F, 0x23, 0x28, 0x2C, 0x30, 0x32, 0x41, 0x44:
			return CONNECTION_SOUTH
		0x05, 0x09, 0x1B, 0x20, 0x22, 0x25, 0x2B, 0x2F, 0x33, 0x42, 0x46:
			return CONNECTION_WEST
		0x06, 0x0A, 0x1C, 0x1E, 0x24, 0x27, 0x29, 0x2E, 0x34, 0x43, 0x47:
			return CONNECTION_EAST
	return CONNECTION_SOUTH

func _read_map_background_events(header_offset: int, map_id: String) -> Array:
	var events: Array = []
	var events_offset: int = _read_rom_pointer(header_offset + 4)
	if events_offset < 0 or not _valid_range(events_offset, MAP_EVENTS_HEADER_SIZE):
		return events
	var event_count: int = int(rom_data[events_offset + 3])
	var events_data_offset: int = _read_rom_pointer(events_offset + 16)
	if event_count <= 0 or events_data_offset < 0 or not _valid_range(events_data_offset, event_count * MAP_BG_EVENT_SIZE):
		return events
	for event_index in range(event_count):
		var offset: int = events_data_offset + event_index * MAP_BG_EVENT_SIZE
		var event_kind: int = int(rom_data[offset + 5])
		if event_kind < 0 or event_kind > 4:
			continue
		var script_offset: int = _read_rom_pointer(offset + 8)
		var dialogue: Dictionary = _read_dialogue_for_script(script_offset)
		if not dialogue.is_empty():
			dialogue["id"] = "%s:bg:%d" % [map_id, event_index]
			_register_dialogue(map_id, -event_index - 1, script_offset, dialogue)
		events.append({"kind": "sign", "background_kind": event_kind, "local_id": -event_index - 1, "x": int(_read_u16(offset)), "y": int(_read_u16(offset + 2)), "elevation": int(rom_data[offset + 4]), "script_offset": script_offset, "dialogue_id": str(dialogue.get("id", "")), "dialogue_pages": dialogue.get("pages", []), "render": false, "blocks_movement": false, "interactable": true})
	return events

func _register_dialogue(map_id: String, local_id: int, script_offset: int, dialogue: Dictionary) -> void:
	var records: Dictionary = string_catalog.get("records", {})
	if not records is Dictionary:
		records = {}
	var key: String = "%s:%d" % [map_id, local_id]
	records[key] = {"map_id": map_id, "local_id": local_id, "script_offset": script_offset, "text_offset": int(dialogue.get("text_offset", -1)), "raw": str(dialogue.get("raw", "")), "pages": dialogue.get("pages", [])}
	string_catalog["schema_version"] = 1
	string_catalog["content_id"] = content_id()
	string_catalog["language"] = "en"
	string_catalog["records"] = records
	OpenMMOStorage.write_strings(content_id(), string_catalog)

func _read_dialogue_for_script(script_offset: int) -> Dictionary:
	if script_offset < 0 or not _valid_range(script_offset, 1):
		return {}
	var cursor: int = script_offset
	var limit: int = mini(rom_data.size(), script_offset + 512)
	var data_slot_zero: int = -1
	while cursor < limit:
		var opcode: int = int(rom_data[cursor])
		if opcode == 0x02 or opcode == 0x03:
			break
		var command_size: int = 1
		match opcode:
			0x04, 0x05:
				command_size = 5
			0x06, 0x07:
				command_size = 6
			0x08, 0x09, 0x0A, 0x0B:
				command_size = 2
			0x0F:
				command_size = 6
			0x4F:
				command_size = 7
			0x50:
				command_size = 9
			0x67:
				command_size = 5
			0x00, 0x01, 0x0C, 0x0D, 0x0E, 0x5A, 0x66, 0x68, 0x69, 0x6A, 0x6B, 0x6C, 0x6D:
				command_size = 1
			_:
				return {}
		if cursor + command_size > limit:
			return {}
		if opcode == 0x0F and int(rom_data[cursor + 1]) == 0:
			var loadword_offset: int = _read_rom_pointer(cursor + 2)
			if loadword_offset >= 0:
				data_slot_zero = loadword_offset
		if opcode == 0x67:
			var message_offset: int = _read_rom_pointer(cursor + 1)
			if message_offset < 0:
				message_offset = data_slot_zero
			if message_offset < 0:
				return {}
			return _decode_rom_text(message_offset)
		cursor += command_size
	return {}

func _decode_rom_text(text_offset: int) -> Dictionary:
	if not _valid_range(text_offset, 1):
		return {}
	var cursor: int = text_offset
	var raw: PackedByteArray = PackedByteArray()
	var pages: Array = []
	var current: String = ""
	while cursor < rom_data.size() and raw.size() < 4096:
		var value: int = int(rom_data[cursor])
		raw.append(value)
		cursor += 1
		match value:
			0xFF:
				break
			0xFE:
				current += "\n"
			0xFB, 0xFA:
				pages.append(current)
				current = ""
			0xFD:
				if cursor >= rom_data.size():
					break
				var placeholder: int = int(rom_data[cursor])
				raw.append(placeholder)
				cursor += 1
				current += _placeholder_name(placeholder)
			0xF7:
				current += "{DYNAMIC}"
			0xF8, 0xF9:
				if cursor < rom_data.size():
					raw.append(rom_data[cursor])
					cursor += 1
				current += "{CONTROL}"
			0xFC:
				current += "{CONTROL}"
			_:
				current += _decode_rom_character(value)
	if not current.is_empty() or pages.is_empty():
		pages.append(current)
	while not pages.is_empty() and str(pages[pages.size() - 1]).is_empty():
		pages.pop_back()
	if pages.is_empty():
		return {}
	return {"text_offset": text_offset, "raw": raw.hex_encode(), "pages": pages}

func dialogue_for_text_id(text_id: int) -> Dictionary:
	var candidates: Array[int] = [text_id]
	var packed_offset: int = text_id & 0x0FFFFFFF
	if packed_offset != text_id:
		candidates.append(packed_offset)
	for candidate_value in candidates:
		var candidate: int = int(candidate_value)
		if not _valid_range(candidate, 1):
			continue
		var dialogue: Dictionary = _decode_rom_text(candidate)
		if not dialogue.is_empty():
			return dialogue
	return {}

func _decode_rom_character(value: int) -> String:
	if value == 0x00:
		return " "
	if value >= 0xA1 and value <= 0xAA:
		return char(48 + value - 0xA1)
	if value >= 0xBB and value <= 0xD4:
		return char(65 + value - 0xBB)
	if value >= 0xD5 and value <= 0xEE:
		return char(97 + value - 0xD5)
	match value:
		0x1B:
			return "é"
		0xAB:
			return "!"
		0xAC:
			return "?"
		0xAD:
			return "."
		0xAE:
			return "-"
		0xB0:
			return "…"
		0xB4:
			return "'"
		0xB8:
			return ","
		0xBA:
			return "/"
		0xF0:
			return ":"
	return "{0x%02X}" % value

func _placeholder_name(value: int) -> String:
	match value:
		1:
			return "{PLAYER}"
		6:
			return "{RIVAL}"
	return "{VAR_%02X}" % value

func _read_map_warps(header_offset: int) -> Array:
	var warps: Array = []
	var events_offset: int = _read_rom_pointer(header_offset + 4)
	var events_header_size: int = _format_int("map_events_header_size", MAP_EVENTS_HEADER_SIZE)
	var warp_event_size: int = _format_int("map_warp_event_size", MAP_WARP_EVENT_SIZE)
	if events_offset < 0 or not _valid_range(events_offset, events_header_size):
		return warps
	var warp_count: int = int(rom_data[events_offset + 1])
	var warps_offset: int = _read_rom_pointer(events_offset + 8)
	if warp_count <= 0 or warps_offset < 0 or not _valid_range(warps_offset, warp_count * warp_event_size):
		return warps
	for warp_index in range(warp_count):
		var offset: int = warps_offset + warp_index * warp_event_size
		var map_index: int = int(rom_data[offset + 6])
		var map_group: int = int(rom_data[offset + 7])
		warps.append({"warp_index": warp_index, "x": _read_s16(offset), "y": _read_s16(offset + 2), "elevation": int(rom_data[offset + 4]), "warp_id": int(rom_data[offset + 5]), "map_index": map_index, "map_group": map_group, "map_id": _map_id_for_location(map_group, map_index)})
	return warps

func _read_map_connections(header_offset: int) -> Array:
	var connections: Array = []
	var connections_offset: int = _read_rom_pointer(header_offset + 12)
	var connections_header_size: int = _format_int("map_connections_header_size", MAP_CONNECTIONS_HEADER_SIZE)
	var connection_size: int = _format_int("map_connection_size", MAP_CONNECTION_SIZE)
	if connections_offset < 0 or not _valid_range(connections_offset, connections_header_size):
		return connections
	var connection_count: int = _read_s32(connections_offset)
	var records_offset: int = _read_rom_pointer(connections_offset + 4)
	if connection_count <= 0 or records_offset < 0 or not _valid_range(records_offset, connection_count * connection_size):
		return connections
	for connection_index in range(connection_count):
		var offset: int = records_offset + connection_index * connection_size
		var map_group: int = int(rom_data[offset + 8])
		var map_index: int = int(rom_data[offset + 9])
		connections.append({"direction": int(rom_data[offset]), "offset": _read_s32(offset + 4), "map_group": map_group, "map_index": map_index, "map_id": _map_id_for_location(map_group, map_index)})
	return connections

func render_facing_object_sprite(graphics_id: int, direction: int, moving: bool = false, frame_step: int = 0) -> Dictionary:
	var direction_name: String = "south"
	match direction:
		CONNECTION_NORTH:
			direction_name = "north"
		CONNECTION_WEST:
			direction_name = "west"
		CONNECTION_EAST:
			direction_name = "east"
	var format: Dictionary = source_profile.get("format", {})
	var facing_frames: Dictionary = format.get("object_facing_frames", {})
	var direction_spec: Dictionary = facing_frames.get(direction_name, {})
	var frame_index: int = int(direction_spec.get("idle", 0))
	var flip_h: bool = bool(direction_spec.get("flip_h", false))
	if moving:
		var walk_frames: Array = direction_spec.get("walk", [])
		if not walk_frames.is_empty():
			frame_index = int(walk_frames[posmod(frame_step, walk_frames.size())])
	return render_object_sprite(graphics_id, frame_index, flip_h)

func render_object_sprite(graphics_id: int, frame: int = 0, flip_h: bool = false) -> Dictionary:
	var resolved_graphics_id: int = graphics_id
	var object_sprites: Dictionary = _object_sprite_specs()
	if resolved_graphics_id < 0 or resolved_graphics_id >= 152 or not object_sprites.has(resolved_graphics_id):
		resolved_graphics_id = 16
	var spec: Dictionary = object_sprites.get(resolved_graphics_id, {})
	if spec.is_empty():
		return {"ok": false, "error": "FireRed object graphics are not available for this graphics ID"}
	var frame_count: int = int(spec.get("frame_count", 1))
	var logical_frame_index: int = posmod(frame, maxi(frame_count, 1))
	var frame_index: int = logical_frame_index
	var frame_sequence: Array = spec.get("frame_sequence", [])
	if not frame_sequence.is_empty():
		frame_index = int(frame_sequence[posmod(logical_frame_index, frame_sequence.size())])
	var cache_key: String = "%d:%d:%d" % [resolved_graphics_id, logical_frame_index, int(flip_h)]
	var cached_texture: Texture2D = sprite_cache.get(cache_key) as Texture2D
	if cached_texture != null:
		return {"ok": true, "texture": cached_texture, "width": int(spec.get("width", 0)), "height": int(spec.get("height", 0)), "frame_count": frame_count, "resolved_graphics_id": resolved_graphics_id}
	var width: int = int(spec.get("width", 0))
	var height: int = int(spec.get("height", 0))
	var frame_bytes: int = int(spec.get("frame_bytes", 0))
	var data_offset: int = int(spec.get("data_offset", -1)) + frame_index * frame_bytes
	var palette_offset: int = int(spec.get("palette_offset", -1))
	if width <= 0 or height <= 0 or frame_bytes <= 0 or width % 8 != 0 or height % 8 != 0 or not _valid_range(data_offset, frame_bytes) or not _valid_range(palette_offset, 32):
		return {"ok": false, "error": "FireRed object graphics data is outside the selected ROM"}
	var image: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	var tiles_wide: int = width / 8
	for pixel_y in range(height):
		for pixel_x in range(width):
			var tile_index: int = (pixel_y >> 3) * tiles_wide + (pixel_x >> 3)
			var packed: int = int(rom_data[data_offset + tile_index * _format_int("tile_bytes", TILE_BYTES) + (pixel_y & 7) * 4 + ((pixel_x & 7) >> 1)])
			var color_index: int = packed & 0x0F if (pixel_x & 1) == 0 else (packed >> 4) & 0x0F
			var color: Color = _read_palette_color(palette_offset + color_index * 2)
			if color_index == 0:
				color = Color(color.r, color.g, color.b, 0.0)
			image.set_pixel(pixel_x, pixel_y, color)
	if flip_h:
		image.flip_x()
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	sprite_cache[cache_key] = texture
	return {"ok": true, "texture": texture, "width": width, "height": height, "frame_count": frame_count, "resolved_graphics_id": resolved_graphics_id}

func _read_tileset(offset: int, tile_count: int, metatile_count: int, palette_count: int) -> Dictionary:
	if offset < 0 or metatile_count <= 0 or not _valid_range(offset, 0x18):
		return {}
	var tile_bytes_per_tile: int = _format_int("tile_bytes", TILE_BYTES)
	var tiles_per_metatile: int = _format_int("tiles_per_metatile", TILES_PER_METATILE)
	var primary_tile_count: int = _format_int("primary_tile_count", PRIMARY_TILE_COUNT)
	var tiles_offset: int = _read_rom_pointer(offset + 4)
	var palettes_offset: int = _read_rom_pointer(offset + 8)
	var metatiles_offset: int = _read_rom_pointer(offset + 12)
	if tiles_offset < 0 or palettes_offset < 0 or metatiles_offset < 0:
		return {}
	var metatile_words: PackedInt32Array = PackedInt32Array()
	var metatile_bytes: int = metatile_count * tiles_per_metatile * 2
	if not _valid_range(metatiles_offset, metatile_bytes):
		return {}
	for index in range(metatile_count * tiles_per_metatile):
		metatile_words.append(_read_u16(metatiles_offset + index * 2))
	var effective_tile_count: int = tile_count
	var tiles: PackedByteArray = PackedByteArray()
	if int(rom_data[offset]) != 0:
		var compressed_tiles: PackedByteArray = _read_lz77(tiles_offset)
		if compressed_tiles.is_empty():
			return {}
		if effective_tile_count <= 0:
			effective_tile_count = compressed_tiles.size() / tile_bytes_per_tile
		if compressed_tiles.size() < effective_tile_count * tile_bytes_per_tile:
			return {}
		if compressed_tiles.size() > effective_tile_count * tile_bytes_per_tile:
			tiles = compressed_tiles.slice(0, effective_tile_count * tile_bytes_per_tile)
		else:
			tiles = compressed_tiles
	else:
		if effective_tile_count <= 0:
			var max_tile_index: int = -1
			for tile_entry in metatile_words:
				var global_tile_index: int = int(tile_entry) & _format_int("map_grid_metatile_id_mask", MAPGRID_METATILE_ID_MASK)
				if global_tile_index >= primary_tile_count:
					max_tile_index = maxi(max_tile_index, global_tile_index - primary_tile_count)
			effective_tile_count = maxi(max_tile_index + 1, 1)
		var tile_bytes: int = effective_tile_count * tile_bytes_per_tile
		if not _valid_range(tiles_offset, tile_bytes):
			return {}
		tiles = rom_data.slice(tiles_offset, tiles_offset + tile_bytes)
	if tiles.size() < effective_tile_count * tile_bytes_per_tile:
		return {}
	var palettes: Array = []
	var palette_bytes: int = palette_count * 16 * 2
	if not _valid_range(palettes_offset, palette_bytes):
		return {}
	for palette_index in range(palette_count * 16):
		palettes.append(_read_palette_color(palettes_offset + palette_index * 2))
	var attributes: PackedInt32Array = PackedInt32Array()
	var attributes_offset: int = _read_rom_pointer(offset + 20)
	if attributes_offset < 0 or not _valid_range(attributes_offset, metatile_count * 4):
		return {}
	for attribute_index in range(metatile_count):
		attributes.append(_read_u32(attributes_offset + attribute_index * 4))
	return {"tiles": tiles, "metatiles": metatile_words, "palettes": palettes, "attributes": attributes, "tile_count": effective_tile_count, "animation_callback": _read_rom_pointer(offset + 16)}

func _draw_metatile(image: Image, destination_x: int, destination_y: int, tileset: Dictionary, metatile_index: int, primary: Dictionary, secondary: Dictionary, animated_tiles: Array, primary_override: PackedByteArray = PackedByteArray()) -> void:
	if not primary_override.is_empty():
		_draw_metatile_uncached(image, destination_x, destination_y, tileset, metatile_index, primary, secondary, animated_tiles, primary_override)
		return
	var cache: Dictionary = tileset.get("_metatile_cache", {})
	var cache_key: String = str(metatile_index)
	var cached: Dictionary = cache.get(cache_key, {})
	if cached.is_empty():
		var cached_image: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
		cached_image.fill(Color(0.0, 0.0, 0.0, 0.0))
		var cached_animated_tiles: Array = []
		_draw_metatile_uncached(cached_image, 0, 0, tileset, metatile_index, primary, secondary, cached_animated_tiles)
		cached = {"image": cached_image, "animated_tiles": cached_animated_tiles}
		cache[cache_key] = cached
		tileset["_metatile_cache"] = cache
	var cached_image_value: Image = cached.get("image") as Image
	if cached_image_value == null:
		return
	image.blend_rect(cached_image_value, Rect2i(0, 0, 16, 16), Vector2i(destination_x, destination_y))
	for tile_value in cached.get("animated_tiles", []):
		if tile_value is Dictionary:
			var tile: Dictionary = tile_value
			animated_tiles.append({"x": destination_x + int(tile.get("x", 0)), "y": destination_y + int(tile.get("y", 0)), "entry": int(tile.get("entry", 0))})

func _draw_metatile_uncached(image: Image, destination_x: int, destination_y: int, tileset: Dictionary, metatile_index: int, primary: Dictionary, secondary: Dictionary, animated_tiles: Array, primary_override: PackedByteArray = PackedByteArray()) -> void:
	var metatiles: PackedInt32Array = tileset.get("metatiles", PackedInt32Array())
	var tiles_per_metatile: int = _format_int("tiles_per_metatile", TILES_PER_METATILE)
	var base: int = metatile_index * tiles_per_metatile
	if metatile_index < 0 or base + tiles_per_metatile > metatiles.size():
		return
	var attributes: PackedInt32Array = tileset.get("attributes", PackedInt32Array())
	var layer_type: int = 0
	if metatile_index < attributes.size():
		layer_type = (int(attributes[metatile_index]) & _format_int("map_grid_layer_type_mask", MAPGRID_LAYER_TYPE_MASK)) >> _format_int("map_grid_layer_type_shift", MAPGRID_LAYER_TYPE_SHIFT)
	match layer_type:
		1:
			_draw_metatile_layer(image, destination_x, destination_y, metatiles, base, 0, primary, secondary, animated_tiles, primary_override)
			_draw_metatile_layer(image, destination_x, destination_y, metatiles, base, 4, primary, secondary, animated_tiles, primary_override)
		2:
			_draw_metatile_layer(image, destination_x, destination_y, metatiles, base, 0, primary, secondary, animated_tiles, primary_override)
			_draw_metatile_layer(image, destination_x, destination_y, metatiles, base, 4, primary, secondary, animated_tiles, primary_override)
		_:
			_draw_metatile_layer(image, destination_x, destination_y, metatiles, base, 0, primary, secondary, animated_tiles, primary_override)
			_draw_metatile_layer(image, destination_x, destination_y, metatiles, base, 4, primary, secondary, animated_tiles, primary_override)

func _draw_metatile_layers(background_image: Image, foreground_image: Image, destination_x: int, destination_y: int, tileset: Dictionary, metatile_index: int, primary: Dictionary, secondary: Dictionary, animated_background_tiles: Array = [], animated_foreground_tiles: Array = [], primary_override: PackedByteArray = PackedByteArray()) -> void:
	if not primary_override.is_empty():
		_draw_metatile_layers_uncached(background_image, foreground_image, destination_x, destination_y, tileset, metatile_index, primary, secondary, animated_background_tiles, animated_foreground_tiles, primary_override)
		return
	var cache: Dictionary = tileset.get("_layer_cache", {})
	var cache_key: String = str(metatile_index)
	var cached: Dictionary = cache.get(cache_key, {})
	if cached.is_empty():
		var cached_background: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
		cached_background.fill(Color.BLACK)
		var cached_foreground: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
		cached_foreground.fill(Color(0.0, 0.0, 0.0, 0.0))
		var cached_background_tiles: Array = []
		var cached_foreground_tiles: Array = []
		_draw_metatile_layers_uncached(cached_background, cached_foreground, 0, 0, tileset, metatile_index, primary, secondary, cached_background_tiles, cached_foreground_tiles)
		cached = {"background": cached_background, "foreground": cached_foreground, "background_tiles": cached_background_tiles, "foreground_tiles": cached_foreground_tiles}
		cache[cache_key] = cached
		tileset["_layer_cache"] = cache
	var cached_background_value: Image = cached.get("background") as Image
	var cached_foreground_value: Image = cached.get("foreground") as Image
	if cached_background_value == null or cached_foreground_value == null:
		return
	background_image.blend_rect(cached_background_value, Rect2i(0, 0, 16, 16), Vector2i(destination_x, destination_y))
	foreground_image.blend_rect(cached_foreground_value, Rect2i(0, 0, 16, 16), Vector2i(destination_x, destination_y))
	for tile_value in cached.get("background_tiles", []):
		if tile_value is Dictionary:
			var background_tile: Dictionary = tile_value
			animated_background_tiles.append({"x": destination_x + int(background_tile.get("x", 0)), "y": destination_y + int(background_tile.get("y", 0)), "entry": int(background_tile.get("entry", 0))})
	for tile_value in cached.get("foreground_tiles", []):
		if tile_value is Dictionary:
			var foreground_tile: Dictionary = tile_value
			animated_foreground_tiles.append({"x": destination_x + int(foreground_tile.get("x", 0)), "y": destination_y + int(foreground_tile.get("y", 0)), "entry": int(foreground_tile.get("entry", 0))})

func _draw_metatile_layers_uncached(background_image: Image, foreground_image: Image, destination_x: int, destination_y: int, tileset: Dictionary, metatile_index: int, primary: Dictionary, secondary: Dictionary, animated_background_tiles: Array = [], animated_foreground_tiles: Array = [], primary_override: PackedByteArray = PackedByteArray()) -> void:
	var metatiles: PackedInt32Array = tileset.get("metatiles", PackedInt32Array())
	var tiles_per_metatile: int = _format_int("tiles_per_metatile", TILES_PER_METATILE)
	var base: int = metatile_index * tiles_per_metatile
	if metatile_index < 0 or base + tiles_per_metatile > metatiles.size():
		return
	var attributes: PackedInt32Array = tileset.get("attributes", PackedInt32Array())
	var layer_type: int = 0
	if metatile_index < attributes.size():
		layer_type = (int(attributes[metatile_index]) & _format_int("map_grid_layer_type_mask", MAPGRID_LAYER_TYPE_MASK)) >> _format_int("map_grid_layer_type_shift", MAPGRID_LAYER_TYPE_SHIFT)
	_draw_metatile_layer(background_image, destination_x, destination_y, metatiles, base, 0, primary, secondary, animated_background_tiles, primary_override)
	if layer_type == 1:
		_draw_metatile_layer(background_image, destination_x, destination_y, metatiles, base, 4, primary, secondary, animated_background_tiles, primary_override)
	else:
		_draw_metatile_layer(foreground_image, destination_x, destination_y, metatiles, base, 4, primary, secondary, animated_foreground_tiles, primary_override)

func _draw_metatile_layer(image: Image, destination_x: int, destination_y: int, metatiles: PackedInt32Array, base: int, start: int, primary: Dictionary, secondary: Dictionary, animated_tiles: Array, primary_override: PackedByteArray = PackedByteArray()) -> void:
	var tiles_per_metatile: int = _format_int("tiles_per_metatile", TILES_PER_METATILE)
	for local_index in range(4):
		var tile_index: int = start + local_index
		if tile_index >= tiles_per_metatile:
			continue
		_draw_tile(image, destination_x + (local_index & 1) * 8, destination_y + (local_index >> 1) * 8, int(metatiles[base + tile_index]), primary, secondary, animated_tiles, primary_override)

func _draw_tile(image: Image, destination_x: int, destination_y: int, tile_entry: int, primary: Dictionary, secondary: Dictionary, animated_tiles: Array = [], primary_override: PackedByteArray = PackedByteArray()) -> void:
	var tile_bytes_per_tile: int = _format_int("tile_bytes", TILE_BYTES)
	var primary_tile_count: int = _format_int("primary_tile_count", PRIMARY_TILE_COUNT)
	var metatile_id_mask: int = _format_int("map_grid_metatile_id_mask", MAPGRID_METATILE_ID_MASK)
	var global_tile_index: int = tile_entry & metatile_id_mask
	var tileset: Dictionary = primary if global_tile_index < primary_tile_count else secondary
	var tile_index: int = global_tile_index if global_tile_index < primary_tile_count else global_tile_index - primary_tile_count
	var tile_count: int = int(tileset.get("tile_count", 0))
	if tile_index < 0 or tile_index >= tile_count:
		return
	var tile_bytes: PackedByteArray = primary_override if global_tile_index < primary_tile_count and primary_override.size() > 0 else tileset.get("tiles", PackedByteArray())
	var palette_bank: int = (tile_entry >> 12) & 0x0F
	var palette_values: Array = primary.get("palettes", [])
	var primary_palette_count: int = _format_int("primary_palette_count", PRIMARY_PALETTE_COUNT)
	var secondary_palette_count: int = _format_int("secondary_palette_count", SECONDARY_PALETTE_COUNT)
	if palette_bank < primary_palette_count:
		palette_bank = mini(palette_bank, primary_palette_count - 1)
	else:
		palette_values = secondary.get("palettes", [])
		palette_bank = clampi(palette_bank, primary_palette_count, primary_palette_count + secondary_palette_count - 1)
	var h_flip: bool = (tile_entry & 0x0400) != 0
	var v_flip: bool = (tile_entry & 0x0800) != 0
	var tile_offset: int = tile_index * tile_bytes_per_tile
	for pixel_y in range(8):
		var sample_y: int = 7 - pixel_y if v_flip else pixel_y
		for pixel_x in range(8):
			var sample_x: int = 7 - pixel_x if h_flip else pixel_x
			var packed: int = int(tile_bytes[tile_offset + sample_y * 4 + (sample_x >> 1)])
			var color_index: int = packed & 0x0F if (sample_x & 1) == 0 else packed >> 4
			if color_index == 0:
				continue
			var color: Color = palette_values[palette_bank * 16 + color_index]
			image.set_pixel(destination_x + pixel_x, destination_y + pixel_y, color)
	if animated_tiles != null and bool(primary.get("animation_enabled", false)) and _is_animated_tile(global_tile_index):
		animated_tiles.append({"x": destination_x, "y": destination_y, "entry": tile_entry})

func _tileset_animation_enabled(tileset: Dictionary) -> bool:
	if bool(tileset.get("is_secondary", true)):
		return false
	if int(tileset.get("animation_callback", -1)) < 0:
		return false
	var animations: Dictionary = source_profile.get("animations", {})
	return not animations.is_empty()

func _is_animated_tile(tile_index: int) -> bool:
	var water_start: int = _format_int("water_tile_index", 416)
	var sand_start: int = _format_int("sand_tile_index", 464)
	var flower_start: int = _format_int("flower_tile_index", 508)
	return (tile_index >= water_start and tile_index < water_start + _format_int("water_tile_count", 48)) or (tile_index >= sand_start and tile_index < sand_start + _format_int("sand_tile_count", 18)) or (tile_index >= flower_start and tile_index < flower_start + _format_int("flower_tile_count", 4))

func _read_s16(offset: int) -> int:
	var value: int = _read_u16(offset)
	return value - 0x10000 if value >= 0x8000 else value

func _read_palette_color(offset: int) -> Color:
	var value: int = _read_u16(offset)
	return Color(float(value & 0x1F) / 31.0, float((value >> 5) & 0x1F) / 31.0, float((value >> 10) & 0x1F) / 31.0, 1.0)

func _read_lz77(offset: int) -> PackedByteArray:
	if offset < 0 or not _valid_range(offset, 4) or int(rom_data[offset]) != 0x10:
		return PackedByteArray()
	var output_size: int = int(rom_data[offset + 1]) | (int(rom_data[offset + 2]) << 8) | (int(rom_data[offset + 3]) << 16)
	var output: PackedByteArray = PackedByteArray()
	output.resize(output_size)
	var input_offset: int = offset + 4
	var output_offset: int = 0
	while output_offset < output_size:
		if not _valid_range(input_offset, 1):
			return PackedByteArray()
		var flags: int = int(rom_data[input_offset])
		input_offset += 1
		for bit in range(8):
			if output_offset >= output_size:
				break
			if (flags & (0x80 >> bit)) == 0:
				if not _valid_range(input_offset, 1):
					return PackedByteArray()
				output[output_offset] = rom_data[input_offset]
				input_offset += 1
				output_offset += 1
				continue
			if not _valid_range(input_offset, 2):
				return PackedByteArray()
			var first: int = int(rom_data[input_offset])
			var second: int = int(rom_data[input_offset + 1])
			input_offset += 2
			var copy_length: int = (first >> 4) + 3
			var displacement: int = ((first & 0x0F) << 8) | second
			var source_offset: int = output_offset - displacement - 1
			if source_offset < 0:
				return PackedByteArray()
			for copy_index in range(copy_length):
				if output_offset >= output_size:
					break
				output[output_offset] = output[source_offset + copy_index]
				output_offset += 1
	return output

func _read_rom_pointer(offset: int) -> int:
	if not _valid_range(offset, 4):
		return -1
	var value: int = _read_u32(offset)
	var region: int = value & 0xFF000000
	if region != 0x08000000 and region != 0x09000000 and region != 0x0A000000:
		return -1
	var file_offset: int = value & 0x01FFFFFF
	return file_offset if _valid_range(file_offset, 1) else -1

func _read_u16(offset: int) -> int:
	return int(rom_data[offset]) | (int(rom_data[offset + 1]) << 8)

func _read_u32(offset: int) -> int:
	return int(rom_data[offset]) | (int(rom_data[offset + 1]) << 8) | (int(rom_data[offset + 2]) << 16) | (int(rom_data[offset + 3]) << 24)

func _read_s32(offset: int) -> int:
	var value: int = _read_u32(offset)
	return value - 0x100000000 if value >= 0x80000000 else value

func _valid_range(offset: int, length: int) -> bool:
	return offset >= 0 and length >= 0 and offset <= rom_data.size() and length <= rom_data.size() - offset
