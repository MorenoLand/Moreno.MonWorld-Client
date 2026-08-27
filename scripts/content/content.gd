class_name MonWorldContent
extends RefCounted

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
const MAP_CONNECTIONS_HEADER_SIZE: int = 0x08
const MAP_CONNECTION_SIZE: int = 0x0C
const CONNECTION_SOUTH: int = 1
const CONNECTION_NORTH: int = 2
const CONNECTION_WEST: int = 3
const CONNECTION_EAST: int = 4
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
var sprite_cache: Dictionary = {}

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
	var source_profile: Dictionary = MonWorldRomProfile.from_header(header)
	if source_profile.is_empty():
		return {"ok": false, "error": "unsupported GBA game code %s" % str(header.get("game_code", ""))}
	if bool(source_profile.get("supports_map_rendering", false)) and not _has_map_layout(data, source_profile):
		return {"ok": false, "error": "%s header found, but no compatible map layout was discovered" % str(source_profile.get("game", "GBA"))}
	var context: HashingContext = HashingContext.new()
	var rom_sha1: String = ""
	if context.start(HashingContext.HASH_SHA1) == OK:
		context.update(data)
		rom_sha1 = context.finish().hex_encode()
	var content: MonWorldContent = MonWorldContent.new()
	content.rom_data = data
	content.rom_sha1 = rom_sha1
	content.rom_header = header
	content.source_profile = source_profile
	content.manifest = _manifest_for_profile(source_profile, rom_sha1)
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
	if width <= 0 or height <= 0 or width > 512 or height > 512:
		return {"ok": false, "error": "FireRed map dimensions are invalid"}
	return {"ok": true, "map_group": map_group, "map_index": map_index, "header_offset": header_offset, "layout_offset": layout_offset, "width": width, "height": height, "map_offset": map_offset, "primary_offset": primary_offset, "secondary_offset": secondary_offset}

func _map_id_for_location(map_group: int, map_index: int) -> String:
	for map_value in manifest.get("maps", []):
		if map_value is Dictionary and int(map_value.get("map_group", -1)) == map_group and int(map_value.get("map_index", -1)) == map_index:
			return str(map_value.get("id", ""))
	return "rom-map-%d-%d" % [map_group, map_index]

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
			return {"id": map_id, "name": "ROM map %d/%d" % [int(reference.get("map_group", -1)), int(reference.get("map_index", -1))], "map_group": int(reference.get("map_group", -1)), "map_index": int(reference.get("map_index", -1)), "width": int(descriptor.get("width", 0)), "height": int(descriptor.get("height", 0))}
	return {}

func render_map(map_id: String, animation_tick: int = 0) -> Dictionary:
	var map_value: Dictionary = map_data(map_id)
	if map_value.is_empty():
		return {"ok": false, "error": "unknown map"}
	var source: Dictionary = manifest.get("source", {})
	if not bool(source_profile.get("supports_map_rendering", false)):
		return {"ok": false, "error": "%s map reader is not enabled yet" % str(source.get("game", "GBA"))}
	var cached_map: Dictionary = _get_or_build_map_cache(map_id, map_value)
	if not bool(cached_map.get("ok", false)):
		return cached_map
	var animation_phase: int = posmod(animation_tick, 40)
	var texture_cache: Dictionary = cached_map.get("textures", {})
	var image_cache: Dictionary = cached_map.get("images", {})
	var background_texture_cache: Dictionary = cached_map.get("background_textures", {})
	var foreground_texture_cache: Dictionary = cached_map.get("foreground_textures", {})
	var cache_key: String = str(animation_phase)
	var texture: Texture2D = texture_cache.get(cache_key) as Texture2D
	var image: Image = image_cache.get(cache_key) as Image
	if texture == null or image == null:
		image = _render_cached_map(cached_map, animation_phase)
		texture = ImageTexture.create_from_image(image)
		texture_cache[cache_key] = texture
		image_cache[cache_key] = image
		cached_map["textures"] = texture_cache
		cached_map["images"] = image_cache
		map_cache[map_id] = cached_map
	var background_texture: Texture2D = background_texture_cache.get(cache_key) as Texture2D
	if background_texture == null:
		var background_image: Image = _render_cached_layer(cached_map, animation_phase, false)
		background_texture = ImageTexture.create_from_image(background_image)
		background_texture_cache[cache_key] = background_texture
		cached_map["background_textures"] = background_texture_cache
	var foreground_texture: Texture2D = foreground_texture_cache.get(cache_key) as Texture2D
	if foreground_texture == null:
		var foreground_image: Image = _render_cached_layer(cached_map, animation_phase, true)
		foreground_texture = ImageTexture.create_from_image(foreground_image)
		foreground_texture_cache[cache_key] = foreground_texture
		cached_map["foreground_textures"] = foreground_texture_cache
	map_cache[map_id] = cached_map
	return {"ok": true, "texture": texture, "image": image, "background_texture": background_texture, "foreground_texture": foreground_texture, "width": int(cached_map.get("width", 0)), "height": int(cached_map.get("height", 0)), "header_offset": int(cached_map.get("header_offset", -1)), "layout_offset": int(cached_map.get("layout_offset", -1)), "objects": cached_map.get("objects", []), "warps": cached_map.get("warps", []), "connections": cached_map.get("connections", []), "map_cells": cached_map.get("map_cells", PackedInt32Array()), "animation_phase": animation_phase}

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
	var image: Image = Image.create(width * 16, height * 16, false, Image.FORMAT_RGBA8)
	image.fill(Color("101721"))
	var background_image: Image = Image.create(width * 16, height * 16, false, Image.FORMAT_RGBA8)
	background_image.fill(Color("101721"))
	var foreground_image: Image = Image.create(width * 16, height * 16, false, Image.FORMAT_RGBA8)
	foreground_image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var animated_tiles: Array = []
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
			_draw_metatile_layers(background_image, foreground_image, map_x * 16, map_y * 16, tileset, metatile_index, primary, secondary)
	var objects: Array = _read_map_objects(header_offset)
	return {"ok": true, "base_image": image, "base_background_image": background_image, "base_foreground_image": foreground_image, "primary": primary, "secondary": secondary, "primary_tiles": primary.get("tiles", PackedByteArray()), "animated_tiles": animated_tiles, "map_cells": map_cells, "objects": objects, "warps": _read_map_warps(header_offset), "connections": _read_map_connections(header_offset), "textures": {}, "images": {}, "background_textures": {}, "foreground_textures": {}, "width": width, "height": height, "header_offset": header_offset, "layout_offset": layout_offset, "map_group": int(map_value.get("map_group", -1)), "map_index": int(map_value.get("map_index", -1))}

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

func can_walk(map_id: String, from_x: int, from_y: int, to_x: int, to_y: int, elevation: int = 3, occupied: Array = []) -> bool:
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
	if not _cell_can_stand(destination) and destination_warp.is_empty():
		return false
	if _position_occupied(cached_map.get("objects", []) if occupied.is_empty() else occupied, to_x, to_y):
		return false
	if not _elevations_compatible(elevation, int(destination.get("elevation", 0))):
		return false
	if destination_warp.is_empty() and _directionally_blocked(int(destination.get("behavior", 0)), direction):
		return false
	var source: Dictionary = _map_cell_from_cache(cached_map, from_x, from_y)
	if _directionally_blocked(int(source.get("behavior", 0)), _opposite_direction(direction)):
		return false
	return true

func movement_result(map_id: String, x: int, y: int, direction: int, elevation: int = 3, occupied: Array = []) -> Dictionary:
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
		return _movement_through_connection(map_id, x, y, direction, elevation)
	if not can_walk(map_id, x, y, destination.x, destination.y, elevation, occupied):
		return {"ok": false, "error": "blocked"}
	var destination_cell: Dictionary = map_cell(map_id, destination.x, destination.y)
	if _jump_direction(int(destination_cell.get("behavior", 0))) == direction:
		var landing: Vector2i = destination + vector
		if landing.x < 0 or landing.y < 0 or landing.x >= width or landing.y >= height or not can_walk(map_id, destination.x, destination.y, landing.x, landing.y, elevation, occupied):
			return {"ok": false, "error": "jump landing is blocked"}
		return {"ok": true, "map_id": map_id, "x": landing.x, "y": landing.y, "from_x": x, "from_y": y, "intermediate_x": destination.x, "intermediate_y": destination.y, "jump": true, "elevation": int(_map_cell_from_cache(_get_or_build_map_cache(map_id), landing.x, landing.y).get("elevation", elevation))}
	return {"ok": true, "map_id": map_id, "x": destination.x, "y": destination.y, "from_x": x, "from_y": y, "jump": false, "stair": _is_stair_warp_behavior(int(destination_cell.get("behavior", 0))), "stair_behavior": int(destination_cell.get("behavior", 0)), "elevation": int(destination_cell.get("elevation", elevation))}

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
		if int(object.get("x", -1)) != target.x or int(object.get("y", -1)) != target.y:
			continue
		var object_elevation: int = int(object.get("elevation", elevation))
		if object_elevation != 0 and object_elevation != elevation:
			continue
		return {"ok": true, "kind": "object", "text": _interaction_text(object), "object": object}
	return {"ok": false, "error": "nothing to interact with"}

func _interaction_text(object: Dictionary) -> String:
	match int(object.get("graphics_id", -1)):
		88:
			return "Mom: Take care, honey."
		71:
			return "Professor Oak: The world is full of discoveries."
		18:
			return "Youngster: Hey! Nice to meet you."
		23:
			return "A local resident smiles at you."
		92, 95:
			return "There is nothing to interact with right now."
	return "Someone is standing here."

func _movement_through_connection(map_id: String, x: int, y: int, direction: int, elevation: int) -> Dictionary:
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
		if not _cell_can_stand(target_cell) or _position_occupied(target_cache.get("objects", []), target_x, target_y):
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

func _position_occupied(objects: Array, x: int, y: int) -> bool:
	for object_value in objects:
		if object_value is Dictionary and int(object_value.get("x", -1)) == x and int(object_value.get("y", -1)) == y:
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
	var primary: Dictionary = cached_map.get("primary", {})
	var secondary: Dictionary = cached_map.get("secondary", {})
	var animated_primary: PackedByteArray = _animated_primary_tiles(cached_map.get("primary_tiles", PackedByteArray()), animation_phase)
	var width: int = int(cached_map.get("width", 0))
	var height: int = int(cached_map.get("height", 0))
	var map_cells: PackedInt32Array = cached_map.get("map_cells", PackedInt32Array())
	var metatile_id_mask: int = _format_int("map_grid_metatile_id_mask", MAPGRID_METATILE_ID_MASK)
	var primary_metatile_count: int = _format_int("primary_metatile_count", PRIMARY_METATILE_COUNT)
	var image: Image = Image.create(width * 16, height * 16, false, Image.FORMAT_RGBA8)
	image.fill(Color("101721"))
	for map_y in range(height):
		for map_x in range(width):
			var cell_index: int = map_y * width + map_x
			if cell_index < 0 or cell_index >= map_cells.size():
				continue
			var metatile_id: int = int(map_cells[cell_index]) & metatile_id_mask
			var tileset: Dictionary = primary
			var metatile_index: int = metatile_id
			if metatile_id >= primary_metatile_count:
				tileset = secondary
				metatile_index = metatile_id - primary_metatile_count
			_draw_metatile(image, map_x * 16, map_y * 16, tileset, metatile_index, primary, secondary, [], animated_primary)
	return image

func _render_cached_layer(cached_map: Dictionary, animation_phase: int, foreground: bool) -> Image:
	var width: int = int(cached_map.get("width", 0))
	var height: int = int(cached_map.get("height", 0))
	var image: Image = Image.create(width * 16, height * 16, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0) if foreground else Color("101721"))
	var primary: Dictionary = cached_map.get("primary", {})
	var secondary: Dictionary = cached_map.get("secondary", {})
	var map_cells: PackedInt32Array = cached_map.get("map_cells", PackedInt32Array())
	var animated_primary: PackedByteArray = _animated_primary_tiles(cached_map.get("primary_tiles", PackedByteArray()), animation_phase) if animation_phase != 0 else PackedByteArray()
	var metatile_id_mask: int = _format_int("map_grid_metatile_id_mask", MAPGRID_METATILE_ID_MASK)
	var primary_metatile_count: int = _format_int("primary_metatile_count", PRIMARY_METATILE_COUNT)
	var layer_start: int = 4 if foreground else 0
	for map_y in range(height):
		for map_x in range(width):
			var cell_index: int = map_y * width + map_x
			if cell_index < 0 or cell_index >= map_cells.size():
				continue
			var metatile_id: int = int(map_cells[cell_index]) & metatile_id_mask
			var tileset: Dictionary = primary
			var metatile_index: int = metatile_id
			if metatile_id >= primary_metatile_count:
				tileset = secondary
				metatile_index = metatile_id - primary_metatile_count
			var metatiles: PackedInt32Array = tileset.get("metatiles", PackedInt32Array())
			var base: int = metatile_index * _format_int("tiles_per_metatile", TILES_PER_METATILE)
			if metatile_index >= 0 and base + layer_start + 4 <= metatiles.size():
				_draw_metatile_layer(image, map_x * 16, map_y * 16, metatiles, base, layer_start, primary, secondary, [], animated_primary)
	return image

func _animated_primary_tiles(base_tiles: PackedByteArray, animation_phase: int) -> PackedByteArray:
	var tiles: PackedByteArray = base_tiles.duplicate()
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

func _read_map_objects(header_offset: int) -> Array:
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
		var sprite: Dictionary = render_object_sprite(graphics_id, 0)
		if not bool(sprite.get("ok", false)):
			continue
		objects.append({"local_id": int(rom_data[offset]), "graphics_id": graphics_id, "resolved_graphics_id": int(sprite.get("resolved_graphics_id", graphics_id)), "x": _read_s16(offset + 4), "y": _read_s16(offset + 6), "elevation": int(rom_data[offset + 8]), "movement_type": int(rom_data[offset + 9]), "texture": sprite.get("texture"), "width": int(sprite.get("width", 0)), "height": int(sprite.get("height", 0)), "frame_count": int(sprite.get("frame_count", 1))})
	return objects

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
	return {"tiles": tiles, "metatiles": metatile_words, "palettes": palettes, "attributes": attributes, "tile_count": effective_tile_count}

func _draw_metatile(image: Image, destination_x: int, destination_y: int, tileset: Dictionary, metatile_index: int, primary: Dictionary, secondary: Dictionary, animated_tiles: Array, primary_override: PackedByteArray = PackedByteArray()) -> void:
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

func _draw_metatile_layers(background_image: Image, foreground_image: Image, destination_x: int, destination_y: int, tileset: Dictionary, metatile_index: int, primary: Dictionary, secondary: Dictionary) -> void:
	var metatiles: PackedInt32Array = tileset.get("metatiles", PackedInt32Array())
	var tiles_per_metatile: int = _format_int("tiles_per_metatile", TILES_PER_METATILE)
	var base: int = metatile_index * tiles_per_metatile
	if metatile_index < 0 or base + tiles_per_metatile > metatiles.size():
		return
	_draw_metatile_layer(background_image, destination_x, destination_y, metatiles, base, 0, primary, secondary, [])
	_draw_metatile_layer(foreground_image, destination_x, destination_y, metatiles, base, 4, primary, secondary, [])
		2:
			_draw_metatile_layer(image, destination_x, destination_y, metatiles, base, 0, primary, secondary, animated_tiles, primary_override)
			_draw_metatile_layer(image, destination_x, destination_y, metatiles, base, 4, primary, secondary, animated_tiles, primary_override)
		_:
			_draw_metatile_layer(image, destination_x, destination_y, metatiles, base, 0, primary, secondary, animated_tiles, primary_override)
			_draw_metatile_layer(image, destination_x, destination_y, metatiles, base, 4, primary, secondary, animated_tiles, primary_override)

func _draw_metatile_layer(image: Image, destination_x: int, destination_y: int, metatiles: PackedInt32Array, base: int, start: int, primary: Dictionary, secondary: Dictionary, animated_tiles: Array, primary_override: PackedByteArray) -> void:
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
	if animated_tiles != null and global_tile_index >= _format_int("animated_tile_start", 416) and global_tile_index < _format_int("animated_tile_end", 482):
		animated_tiles.append({"x": destination_x, "y": destination_y, "entry": tile_entry})

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
