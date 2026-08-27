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

var manifest: Dictionary = {}
var rom_data: PackedByteArray = PackedByteArray()
var rom_sha1: String = ""
var rom_header: Dictionary = {}

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

func render_map(map_id: String) -> Dictionary:
	var map_value: Dictionary = map_data(map_id)
	if map_value.is_empty():
		return {"ok": false, "error": "unknown map"}
	var source: Dictionary = manifest.get("source", {})
	if str(source.get("game", "")) != "FireRed":
		return {"ok": false, "error": "direct map rendering currently supports FireRed Rev1; LeafGreen map offsets are not verified yet"}
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
	var image: Image = Image.create(width * 16, height * 16, false, Image.FORMAT_RGBA8)
	image.fill(Color("101721"))
	for map_y in range(height):
		for map_x in range(width):
			var map_word: int = _read_u16(map_offset + (map_y * width + map_x) * 2)
			var metatile_id: int = map_word & MAPGRID_METATILE_ID_MASK
			var tileset: Dictionary = primary
			var metatile_index: int = metatile_id
			if metatile_id >= PRIMARY_METATILE_COUNT:
				tileset = secondary
				metatile_index = metatile_id - PRIMARY_METATILE_COUNT
			_draw_metatile(image, map_x * 16, map_y * 16, tileset, metatile_index)
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	return {"ok": true, "texture": texture, "image": image, "width": width, "height": height, "header_offset": header_offset, "layout_offset": layout_offset}

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
	return {"tiles": tiles, "metatiles": metatile_words, "palettes": palettes, "tile_count": tile_count}

func _draw_metatile(image: Image, destination_x: int, destination_y: int, tileset: Dictionary, metatile_index: int) -> void:
	var metatiles: PackedInt32Array = tileset.get("metatiles", PackedInt32Array())
	var base: int = metatile_index * TILES_PER_METATILE
	if metatile_index < 0 or base + TILES_PER_METATILE > metatiles.size():
		return
	for tile_index in range(4):
		_draw_tile(image, destination_x + (tile_index & 1) * 8, destination_y + (tile_index >> 1) * 8, int(metatiles[base + tile_index]), tileset, false)
	for tile_index in range(4, TILES_PER_METATILE):
		_draw_tile(image, destination_x + ((tile_index - 4) & 1) * 8, destination_y + ((tile_index - 4) >> 1) * 8, int(metatiles[base + tile_index]), tileset, true)

func _draw_tile(image: Image, destination_x: int, destination_y: int, tile_entry: int, tileset: Dictionary, transparent_zero: bool) -> void:
	var tile_index: int = tile_entry & 0x03FF
	var tile_count: int = int(tileset.get("tile_count", 0))
	if tile_index < 0 or tile_index >= tile_count:
		return
	var tile_bytes: PackedByteArray = tileset.get("tiles", PackedByteArray())
	var palettes: Array = tileset.get("palettes", [])
	var palette_bank: int = (tile_entry >> 12) & 0x0F
	if palette_bank * 16 + 15 >= palettes.size():
		palette_bank = 0
	var h_flip: bool = (tile_entry & 0x0400) != 0
	var v_flip: bool = (tile_entry & 0x0800) != 0
	var tile_offset: int = tile_index * TILE_BYTES
	for pixel_y in range(8):
		var sample_y: int = 7 - pixel_y if v_flip else pixel_y
		for pixel_x in range(8):
			var sample_x: int = 7 - pixel_x if h_flip else pixel_x
			var packed: int = int(tile_bytes[tile_offset + sample_y * 4 + (sample_x >> 1)])
			var color_index: int = packed & 0x0F if (sample_x & 1) == 0 else packed >> 4
			if transparent_zero and color_index == 0:
				continue
			var color: Color = palettes[palette_bank * 16 + color_index]
			image.set_pixel(destination_x + pixel_x, destination_y + pixel_y, color)

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
