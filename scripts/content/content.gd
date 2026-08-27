class_name MonWorldContent
extends RefCounted

const SCHEMA_VERSION: int = 1
const FIRE_RED_REV1_SHA1: String = "dd5945db9b930750cb39d00c84da8571feebf417"
const LEAF_GREEN_REV1_SHA1: String = "7862c67bdecbe21d1d69ce082ce34327e1c6ed5e"
const KANTO_GBA_CONTENT_ID: String = "kanto-gba-slice-v1"
const GBA_TITLE_OFFSET: int = 0xA0
const GBA_TITLE_LENGTH: int = 12
const GBA_GAME_CODE_OFFSET: int = 0xAC
const GBA_GAME_CODE_LENGTH: int = 4
const GBA_MAKER_CODE_OFFSET: int = 0xB0
const GBA_MAKER_CODE_LENGTH: int = 2
const FIRE_RED_REV1_TOWNS_MAP_POINTERS_OFFSET: int = 0x352364
const MAP_HEADER_SIZE: int = 0x1C
const MAPGRID_METATILE_ID_MASK: int = 0x03FF
const PRIMARY_METATILE_COUNT: int = 640
const PRIMARY_TILE_COUNT: int = 640
const PRIMARY_PALETTE_COUNT: int = 7
const SECONDARY_PALETTE_COUNT: int = 6
const TILE_BYTES: int = 32
const TILES_PER_METATILE: int = 8
const MAPGRID_LAYER_TYPE_SHIFT: int = 29
const MAPGRID_LAYER_TYPE_MASK: int = 0x60000000
const MAP_EVENTS_HEADER_SIZE: int = 0x14
const MAP_OBJECT_EVENT_SIZE: int = 0x18
const FIRE_RED_GENERAL_WATER_FRAME_OFFSETS: Array[int] = [0x3A76E4, 0x3A7CE4, 0x3A82E4, 0x3A88E4, 0x3A8EE4, 0x3A94E4, 0x3A9AE4, 0x3AA0E4]
const FIRE_RED_GENERAL_SAND_FRAME_OFFSETS: Array[int] = [0x3AA6E4, 0x3AA924, 0x3AAB64, 0x3AADA4, 0x3AAFE4, 0x3AB224, 0x3AB464, 0x3AB6A4]
const FIRE_RED_GENERAL_FLOWER_FRAME_OFFSETS: Array[int] = [0x3A7450, 0x3A74D0, 0x3A7550, 0x3A75D0, 0x3A7650]
const FIRE_RED_REV1_OBJECT_SPRITES: Dictionary = {
	16: {"data_offset": 0x36D998, "width": 16, "height": 16, "frame_bytes": 128, "frame_count": 9, "palette_offset": 0x36D8F8},
	18: {"data_offset": 0x36F018, "width": 16, "height": 32, "frame_bytes": 256, "frame_count": 10, "palette_offset": 0x36D898},
	19: {"data_offset": 0x36FA18, "width": 16, "height": 32, "frame_bytes": 256, "frame_count": 10, "palette_offset": 0x36D8D8},
	23: {"data_offset": 0x370418, "width": 16, "height": 32, "frame_bytes": 256, "frame_count": 10, "palette_offset": 0x36D8D8},
	27: {"data_offset": 0x373418, "width": 16, "height": 32, "frame_bytes": 256, "frame_count": 9, "palette_offset": 0x36D8F8},
	31: {"data_offset": 0x370E18, "width": 16, "height": 32, "frame_bytes": 256, "frame_count": 9, "palette_offset": 0x36D8F8},
	32: {"data_offset": 0x375118, "width": 16, "height": 32, "frame_bytes": 256, "frame_count": 10, "palette_offset": 0x36D8B8},
	68: {"data_offset": 0x38C718, "width": 16, "height": 32, "frame_bytes": 256, "frame_count": 9, "palette_offset": 0x36D8F8},
	71: {"data_offset": 0x389B98, "width": 16, "height": 32, "frame_bytes": 256, "frame_count": 9, "palette_offset": 0x36D8F8},
	92: {"data_offset": 0x38BA98, "width": 16, "height": 16, "frame_bytes": 128, "frame_count": 1, "palette_offset": 0x36D8F8},
	95: {"data_offset": 0x394618, "width": 16, "height": 16, "frame_bytes": 128, "frame_count": 4, "palette_offset": 0x36D8D8}
}

var manifest: Dictionary = {}
var rom_data: PackedByteArray = PackedByteArray()
var rom_sha1: String = ""
var rom_header: Dictionary = {}
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
	var context: HashingContext = HashingContext.new()
	var start_error: int = context.start(HashingContext.HASH_SHA1)
	if start_error != OK:
		return {"ok": false, "error": "could not initialize ROM hash"}
	context.update(data)
	var rom_sha1: String = context.finish().hex_encode()
	var source_game: String = ""
	if rom_sha1 == FIRE_RED_REV1_SHA1:
		source_game = "FireRed"
	elif rom_sha1 == LEAF_GREEN_REV1_SHA1:
		source_game = "LeafGreen"
	else:
		return {"ok": false, "error": "unsupported ROM SHA-1 %s; expected verified FireRed Rev1 or LeafGreen Rev1; patched or unknown ROMs are rejected" % rom_sha1}
	var content: MonWorldContent = MonWorldContent.new()
	content.rom_data = data
	content.rom_sha1 = rom_sha1
	content.rom_header = _read_gba_header(data)
	content.manifest = _kanto_manifest(source_game, rom_sha1)
	return {"ok": true, "content": content}

static func _read_gba_header(data: PackedByteArray) -> Dictionary:
	if data.size() < GBA_MAKER_CODE_OFFSET + GBA_MAKER_CODE_LENGTH:
		return {}
	return {"title": data.slice(GBA_TITLE_OFFSET, GBA_TITLE_OFFSET + GBA_TITLE_LENGTH).get_string_from_ascii().strip_edges(), "game_code": data.slice(GBA_GAME_CODE_OFFSET, GBA_GAME_CODE_OFFSET + GBA_GAME_CODE_LENGTH).get_string_from_ascii(), "maker_code": data.slice(GBA_MAKER_CODE_OFFSET, GBA_MAKER_CODE_OFFSET + GBA_MAKER_CODE_LENGTH).get_string_from_ascii()}

static func _kanto_manifest(source_game: String, rom_sha1: String) -> Dictionary:
	return {"schema_version": SCHEMA_VERSION, "content_id": KANTO_GBA_CONTENT_ID, "source": {"game": source_game, "revision": "Rev1", "rom_sha1": rom_sha1}, "maps": [{"id": "pallet-town", "name": "Pallet Town", "width": 24, "height": 20}, {"id": "route-1", "name": "Route 1", "width": 24, "height": 40}, {"id": "viridian-city", "name": "Viridian City", "width": 48, "height": 40}]}

func content_id() -> String:
	return str(manifest.get("content_id", ""))

func map_data(map_id: String) -> Dictionary:
	for map_value in manifest.get("maps", []):
		if map_value is Dictionary and str(map_value.get("id", "")) == map_id:
			return map_value
	return {}

func render_map(map_id: String, animation_tick: int = 0) -> Dictionary:
	var map_value: Dictionary = map_data(map_id)
	if map_value.is_empty():
		return {"ok": false, "error": "unknown map"}
	var source: Dictionary = manifest.get("source", {})
	if str(source.get("game", "")) != "FireRed":
		return {"ok": false, "error": "direct map rendering currently supports FireRed Rev1; LeafGreen map offsets are not verified yet"}
	var cached_map: Dictionary = map_cache.get(map_id, {})
	if cached_map.is_empty():
		var built_map: Dictionary = _build_map_cache(map_id, map_value)
		if not bool(built_map.get("ok", false)):
			return built_map
		map_cache[map_id] = built_map
		cached_map = built_map
	var animation_phase: int = posmod(animation_tick, 40)
	var texture_cache: Dictionary = cached_map.get("textures", {})
	var image_cache: Dictionary = cached_map.get("images", {})
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
	return {"ok": true, "texture": texture, "image": image, "width": int(cached_map.get("width", 0)), "height": int(cached_map.get("height", 0)), "header_offset": int(cached_map.get("header_offset", -1)), "layout_offset": int(cached_map.get("layout_offset", -1)), "objects": cached_map.get("objects", []), "animation_phase": animation_phase}

func _build_map_cache(map_id: String, map_value: Dictionary) -> Dictionary:
	var map_index: int = -1
	var secondary_tile_count: int = 0
	var secondary_metatile_count: int = 0
	match map_id:
		"pallet-town":
			map_index = 0
			secondary_tile_count = 76
			secondary_metatile_count = 89
		"route-1":
			map_index = 19
			secondary_tile_count = 76
			secondary_metatile_count = 89
		"viridian-city":
			map_index = 1
			secondary_tile_count = 112
			secondary_metatile_count = 95
	if map_index < 0:
		return {"ok": false, "error": "map is not available in the verified Kanto slice"}
	var header_offset: int = _read_rom_pointer(FIRE_RED_REV1_TOWNS_MAP_POINTERS_OFFSET + map_index * 4)
	if header_offset < 0 or not _valid_range(header_offset, MAP_HEADER_SIZE):
		return {"ok": false, "error": "could not resolve the FireRed map header"}
	var layout_offset: int = _read_rom_pointer(header_offset)
	if layout_offset < 0 or not _valid_range(layout_offset, 0x1C):
		return {"ok": false, "error": "could not resolve the FireRed map layout"}
	var width: int = _read_u32(layout_offset)
	var height: int = _read_u32(layout_offset + 4)
	var expected_width: int = int(map_value.get("width", 0))
	var expected_height: int = int(map_value.get("height", 0))
	if width != expected_width or height != expected_height:
		return {"ok": false, "error": "FireRed map layout dimensions do not match the selected map"}
	var map_offset: int = _read_rom_pointer(layout_offset + 12)
	var primary_offset: int = _read_rom_pointer(layout_offset + 16)
	var secondary_offset: int = _read_rom_pointer(layout_offset + 20)
	var map_bytes: int = width * height * 2
	if map_offset < 0 or not _valid_range(map_offset, map_bytes):
		return {"ok": false, "error": "could not read the FireRed map cells"}
	var primary: Dictionary = _read_tileset(primary_offset, PRIMARY_TILE_COUNT, PRIMARY_METATILE_COUNT, PRIMARY_PALETTE_COUNT)
	var secondary: Dictionary = _read_tileset(secondary_offset, secondary_tile_count, secondary_metatile_count, SECONDARY_PALETTE_COUNT)
	if primary.is_empty() or secondary.is_empty():
		return {"ok": false, "error": "could not read the FireRed map tilesets"}
	primary["is_secondary"] = false
	secondary["is_secondary"] = true
	var image: Image = Image.create(width * 16, height * 16, false, Image.FORMAT_RGBA8)
	image.fill(Color("101721"))
	var animated_tiles: Array = []
	var map_cells: PackedInt32Array = PackedInt32Array()
	for map_y in range(height):
		for map_x in range(width):
			var map_word: int = _read_u16(map_offset + (map_y * width + map_x) * 2)
			map_cells.append(map_word)
			var metatile_id: int = map_word & MAPGRID_METATILE_ID_MASK
			var tileset: Dictionary = primary
			var metatile_index: int = metatile_id
			if metatile_id >= PRIMARY_METATILE_COUNT:
				tileset = secondary
				metatile_index = metatile_id - PRIMARY_METATILE_COUNT
			_draw_metatile(image, map_x * 16, map_y * 16, tileset, metatile_index, primary, secondary, animated_tiles)
	var objects: Array = _read_map_objects(header_offset)
	return {"ok": true, "base_image": image, "primary": primary, "secondary": secondary, "primary_tiles": primary.get("tiles", PackedByteArray()), "animated_tiles": animated_tiles, "map_cells": map_cells, "objects": objects, "textures": {}, "images": {}, "width": width, "height": height, "header_offset": header_offset, "layout_offset": layout_offset}

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
	var image: Image = Image.create(width * 16, height * 16, false, Image.FORMAT_RGBA8)
	image.fill(Color("101721"))
	for map_y in range(height):
		for map_x in range(width):
			var cell_index: int = map_y * width + map_x
			if cell_index < 0 or cell_index >= map_cells.size():
				continue
			var metatile_id: int = int(map_cells[cell_index]) & MAPGRID_METATILE_ID_MASK
			var tileset: Dictionary = primary
			var metatile_index: int = metatile_id
			if metatile_id >= PRIMARY_METATILE_COUNT:
				tileset = secondary
				metatile_index = metatile_id - PRIMARY_METATILE_COUNT
			_draw_metatile(image, map_x * 16, map_y * 16, tileset, metatile_index, primary, secondary, [], animated_primary)
	return image

func _animated_primary_tiles(base_tiles: PackedByteArray, animation_phase: int) -> PackedByteArray:
	var tiles: PackedByteArray = base_tiles.duplicate()
	var water_frame: int = animation_phase % FIRE_RED_GENERAL_WATER_FRAME_OFFSETS.size()
	var sand_frame: int = animation_phase % FIRE_RED_GENERAL_SAND_FRAME_OFFSETS.size()
	var flower_frame: int = animation_phase % FIRE_RED_GENERAL_FLOWER_FRAME_OFFSETS.size()
	_copy_rom_bytes(tiles, 416 * TILE_BYTES, FIRE_RED_GENERAL_WATER_FRAME_OFFSETS[water_frame], 48 * TILE_BYTES)
	_copy_rom_bytes(tiles, 464 * TILE_BYTES, FIRE_RED_GENERAL_SAND_FRAME_OFFSETS[sand_frame], 18 * TILE_BYTES)
	_copy_rom_bytes(tiles, 508 * TILE_BYTES, FIRE_RED_GENERAL_FLOWER_FRAME_OFFSETS[flower_frame], 4 * TILE_BYTES)
	return tiles

func _copy_rom_bytes(destination: PackedByteArray, destination_offset: int, source_offset: int, length: int) -> void:
	if destination_offset < 0 or destination_offset + length > destination.size() or not _valid_range(source_offset, length):
		return
	for index in range(length):
		destination[destination_offset + index] = rom_data[source_offset + index]

func _read_map_objects(header_offset: int) -> Array:
	var objects: Array = []
	var events_offset: int = _read_rom_pointer(header_offset + 4)
	if events_offset < 0 or not _valid_range(events_offset, MAP_EVENTS_HEADER_SIZE):
		return objects
	var object_count: int = int(rom_data[events_offset])
	var objects_offset: int = _read_rom_pointer(events_offset + 4)
	if object_count <= 0 or objects_offset < 0 or not _valid_range(objects_offset, object_count * MAP_OBJECT_EVENT_SIZE):
		return objects
	for object_index in range(object_count):
		var offset: int = objects_offset + object_index * MAP_OBJECT_EVENT_SIZE
		var kind: int = int(rom_data[offset + 2])
		if kind != 0:
			continue
		var graphics_id: int = int(rom_data[offset + 1])
		var sprite: Dictionary = render_object_sprite(graphics_id, 0)
		if not bool(sprite.get("ok", false)):
			continue
		objects.append({"local_id": int(rom_data[offset]), "graphics_id": graphics_id, "resolved_graphics_id": int(sprite.get("resolved_graphics_id", graphics_id)), "x": _read_s16(offset + 4), "y": _read_s16(offset + 6), "elevation": int(rom_data[offset + 8]), "movement_type": int(rom_data[offset + 9]), "texture": sprite.get("texture"), "width": int(sprite.get("width", 0)), "height": int(sprite.get("height", 0)), "frame_count": int(sprite.get("frame_count", 1))})
	return objects

func render_object_sprite(graphics_id: int, frame: int = 0) -> Dictionary:
	var resolved_graphics_id: int = graphics_id
	if resolved_graphics_id < 0 or resolved_graphics_id >= 152 or not FIRE_RED_REV1_OBJECT_SPRITES.has(resolved_graphics_id):
		resolved_graphics_id = 16
	var spec: Dictionary = FIRE_RED_REV1_OBJECT_SPRITES.get(resolved_graphics_id, {})
	if spec.is_empty():
		return {"ok": false, "error": "FireRed object graphics are not available for this graphics ID"}
	var frame_count: int = int(spec.get("frame_count", 1))
	var frame_index: int = posmod(frame, maxi(frame_count, 1))
	var cache_key: String = "%d:%d" % [resolved_graphics_id, frame_index]
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
			var packed: int = int(rom_data[data_offset + tile_index * TILE_BYTES + (pixel_y & 7) * 4 + ((pixel_x & 7) >> 1)])
			var color_index: int = packed & 0x0F if (pixel_x & 1) == 0 else (packed >> 4) & 0x0F
			var color: Color = _read_palette_color(palette_offset + color_index * 2)
			if color_index == 0:
				color = Color(color.r, color.g, color.b, 0.0)
			image.set_pixel(pixel_x, pixel_y, color)
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	sprite_cache[cache_key] = texture
	return {"ok": true, "texture": texture, "width": width, "height": height, "frame_count": frame_count, "resolved_graphics_id": resolved_graphics_id}

func _read_tileset(offset: int, tile_count: int, metatile_count: int, palette_count: int) -> Dictionary:
	if offset < 0 or tile_count <= 0 or metatile_count <= 0 or not _valid_range(offset, 0x18):
		return {}
	var tiles_offset: int = _read_rom_pointer(offset + 4)
	var palettes_offset: int = _read_rom_pointer(offset + 8)
	var metatiles_offset: int = _read_rom_pointer(offset + 12)
	if tiles_offset < 0 or palettes_offset < 0 or metatiles_offset < 0:
		return {}
	var tiles: PackedByteArray = PackedByteArray()
	if int(rom_data[offset]) != 0:
		tiles = _read_lz77(tiles_offset)
	else:
		var tile_bytes: int = tile_count * TILE_BYTES
		if not _valid_range(tiles_offset, tile_bytes):
			return {}
		tiles = rom_data.slice(tiles_offset, tiles_offset + tile_bytes)
	if tiles.size() < tile_count * TILE_BYTES:
		return {}
	var metatile_words: PackedInt32Array = PackedInt32Array()
	var metatile_bytes: int = metatile_count * TILES_PER_METATILE * 2
	if not _valid_range(metatiles_offset, metatile_bytes):
		return {}
	for index in range(metatile_count * TILES_PER_METATILE):
		metatile_words.append(_read_u16(metatiles_offset + index * 2))
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
	return {"tiles": tiles, "metatiles": metatile_words, "palettes": palettes, "attributes": attributes, "tile_count": tile_count}

func _draw_metatile(image: Image, destination_x: int, destination_y: int, tileset: Dictionary, metatile_index: int, primary: Dictionary, secondary: Dictionary, animated_tiles: Array, primary_override: PackedByteArray = PackedByteArray()) -> void:
	var metatiles: PackedInt32Array = tileset.get("metatiles", PackedInt32Array())
	var base: int = metatile_index * TILES_PER_METATILE
	if metatile_index < 0 or base + TILES_PER_METATILE > metatiles.size():
		return
	var attributes: PackedInt32Array = tileset.get("attributes", PackedInt32Array())
	var layer_type: int = 0
	if metatile_index < attributes.size():
		layer_type = (int(attributes[metatile_index]) & MAPGRID_LAYER_TYPE_MASK) >> MAPGRID_LAYER_TYPE_SHIFT
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

func _draw_metatile_layer(image: Image, destination_x: int, destination_y: int, metatiles: PackedInt32Array, base: int, start: int, primary: Dictionary, secondary: Dictionary, animated_tiles: Array, primary_override: PackedByteArray) -> void:
	for local_index in range(4):
		var tile_index: int = start + local_index
		_draw_tile(image, destination_x + (local_index & 1) * 8, destination_y + (local_index >> 1) * 8, int(metatiles[base + tile_index]), primary, secondary, animated_tiles, primary_override)

func _draw_tile(image: Image, destination_x: int, destination_y: int, tile_entry: int, primary: Dictionary, secondary: Dictionary, animated_tiles: Array = [], primary_override: PackedByteArray = PackedByteArray()) -> void:
	var global_tile_index: int = tile_entry & 0x03FF
	var tileset: Dictionary = primary if global_tile_index < PRIMARY_TILE_COUNT else secondary
	var tile_index: int = global_tile_index if global_tile_index < PRIMARY_TILE_COUNT else global_tile_index - PRIMARY_TILE_COUNT
	var tile_count: int = int(tileset.get("tile_count", 0))
	if tile_index < 0 or tile_index >= tile_count:
		return
	var tile_bytes: PackedByteArray = primary_override if global_tile_index < PRIMARY_TILE_COUNT and primary_override.size() > 0 else tileset.get("tiles", PackedByteArray())
	var palettes: Array = tileset.get("palettes", [])
	var palette_bank: int = (tile_entry >> 12) & 0x0F
	var palette_values: Array = palettes
	if global_tile_index < PRIMARY_TILE_COUNT:
		palette_bank = mini(palette_bank, PRIMARY_PALETTE_COUNT - 1)
	else:
		palette_bank -= PRIMARY_PALETTE_COUNT
		palette_bank = clampi(palette_bank, 0, SECONDARY_PALETTE_COUNT - 1)
	var h_flip: bool = (tile_entry & 0x0400) != 0
	var v_flip: bool = (tile_entry & 0x0800) != 0
	var tile_offset: int = tile_index * TILE_BYTES
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
	if animated_tiles != null and global_tile_index >= 416 and global_tile_index < 482:
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

func _valid_range(offset: int, length: int) -> bool:
	return offset >= 0 and length >= 0 and offset <= rom_data.size() and length <= rom_data.size() - offset
