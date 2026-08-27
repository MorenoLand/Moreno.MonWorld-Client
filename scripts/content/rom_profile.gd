class_name MonWorldRomProfile
extends RefCounted

static func from_header(header: Dictionary) -> Dictionary:
	if str(header.get("maker_code", "")).to_upper() != "01":
		return {}
	match str(header.get("game_code", "")).to_upper():
		"BPRE":
			return _fire_red_profile()
		"BPRF":
			return _leaf_green_profile()
		"BPEE":
			return _profile("pokemon-emerald", "Emerald", "Hoenn", false, -1)
		"AXVE":
			return _profile("pokemon-ruby", "Ruby", "Hoenn", false, -1)
		"AXPE":
			return _profile("pokemon-sapphire", "Sapphire", "Hoenn", false, -1)
	return {}

static func _profile(id: String, game: String, region: String, supports_map_rendering: bool, map_groups_offset: int) -> Dictionary:
	return {"id": id, "game": game, "region": region, "revision": "header-identified", "content_id": "kanto-gba-slice-v1" if region == "Kanto" else "", "supports_map_rendering": supports_map_rendering, "map_groups_offset": map_groups_offset, "map_group_probe_indices": [0, 1, 19], "map_groups": {}, "map_names": [], "extra_maps": [], "format": {}, "animations": {}, "object_sprites": {}}

static func _fire_red_profile() -> Dictionary:
	var profile: Dictionary = _profile("pokemon-fire-red", "FireRed", "Kanto", true, 0x352718)
	profile["map_groups"] = {"dungeons": 1, "towns_and_routes": 3, "indoor_pallet": 4, "indoor_viridian": 5}
	profile["map_names"] = ["PalletTown", "ViridianCity", "PewterCity", "CeruleanCity", "LavenderTown", "VermilionCity", "CeladonCity", "FuchsiaCity", "CinnabarIsland", "IndigoPlateau_Exterior", "SaffronCity", "SaffronCity_Connection", "OneIsland", "TwoIsland", "ThreeIsland", "FourIsland", "FiveIsland", "SevenIsland", "SixIsland", "Route1", "Route2", "Route3", "Route4", "Route5", "Route6", "Route7", "Route8", "Route9", "Route10", "Route11", "Route12", "Route13", "Route14", "Route15", "Route16", "Route17", "Route18", "Route19", "Route20", "Route21_North", "Route21_South", "Route22", "Route23", "Route24", "Route25"]
	profile["extra_maps"] = [{"group": 1, "index": 0, "id": "viridian-forest", "name": "Viridian Forest"}, {"group": 4, "index": 0, "id": "pallet-players-house-1f", "name": "Pallet Town Players House 1F"}, {"group": 4, "index": 1, "id": "pallet-players-house-2f", "name": "Pallet Town Players House 2F"}, {"group": 4, "index": 2, "id": "pallet-rivals-house", "name": "Pallet Town Rivals House"}, {"group": 4, "index": 3, "id": "pallet-oaks-lab", "name": "Pallet Town Professor Oaks Lab"}, {"group": 5, "index": 0, "id": "viridian-house", "name": "Viridian City House"}, {"group": 5, "index": 1, "id": "viridian-gym", "name": "Viridian City Gym"}, {"group": 5, "index": 2, "id": "viridian-school", "name": "Viridian City School"}, {"group": 5, "index": 3, "id": "viridian-mart", "name": "Viridian City Mart"}, {"group": 5, "index": 4, "id": "viridian-pokemon-center-1f", "name": "Viridian City Pokemon Center 1F"}, {"group": 5, "index": 5, "id": "viridian-pokemon-center-2f", "name": "Viridian City Pokemon Center 2F"}]
	profile["format"] = {"map_header_size": 0x1C, "map_grid_metatile_id_mask": 0x03FF, "map_grid_collision_mask": 0x0C00, "map_grid_elevation_mask": 0xF000, "map_grid_collision_shift": 10, "map_grid_elevation_shift": 12, "map_grid_undefined": 0x03FF, "metatile_behavior_mask": 0x000001FF, "primary_metatile_count": 640, "primary_tile_count": 640, "primary_palette_count": 7, "secondary_palette_count": 6, "secondary_rom_palette_count": 16, "tile_bytes": 32, "tiles_per_metatile": 8, "map_grid_layer_type_shift": 29, "map_grid_layer_type_mask": 0x60000000, "map_events_header_size": 0x14, "map_object_event_size": 0x18, "map_warp_event_size": 0x08, "map_connections_header_size": 0x08, "map_connection_size": 0x0C, "connection_south": 1, "connection_north": 2, "connection_west": 3, "connection_east": 4, "water_tile_index": 416, "water_tile_count": 48, "sand_tile_index": 464, "sand_tile_count": 18, "flower_tile_index": 508, "flower_tile_count": 4, "animated_tile_start": 416, "animated_tile_end": 482}
	profile["animations"] = {"water": [0x3A76E4, 0x3A7CE4, 0x3A82E4, 0x3A88E4, 0x3A8EE4, 0x3A94E4, 0x3A9AE4, 0x3AA0E4], "sand": [0x3AA6E4, 0x3AA924, 0x3AAB64, 0x3AADA4, 0x3AAFE4, 0x3AB224, 0x3AB464, 0x3AB6A4], "flower": [0x3A7450, 0x3A74D0, 0x3A7550, 0x3A75D0, 0x3A7650]}
	profile["object_sprites"] = {16: {"data_offset": 0x36D998, "width": 16, "height": 16, "frame_bytes": 128, "frame_count": 9, "palette_offset": 0x36D8F8}, 18: {"data_offset": 0x36F018, "width": 16, "height": 32, "frame_bytes": 256, "frame_count": 10, "palette_offset": 0x36D898}, 19: {"data_offset": 0x36FA18, "width": 16, "height": 32, "frame_bytes": 256, "frame_count": 10, "palette_offset": 0x36D8D8}, 23: {"data_offset": 0x370418, "width": 16, "height": 32, "frame_bytes": 256, "frame_count": 10, "palette_offset": 0x36D8D8}, 27: {"data_offset": 0x373418, "width": 16, "height": 32, "frame_bytes": 256, "frame_count": 9, "palette_offset": 0x36D8F8}, 31: {"data_offset": 0x370E18, "width": 16, "height": 32, "frame_bytes": 256, "frame_count": 9, "palette_offset": 0x36D8F8}, 32: {"data_offset": 0x375118, "width": 16, "height": 32, "frame_bytes": 256, "frame_count": 10, "palette_offset": 0x36D8B8}, 68: {"data_offset": 0x38C718, "width": 16, "height": 32, "frame_bytes": 256, "frame_count": 9, "palette_offset": 0x36D8F8}, 71: {"data_offset": 0x389B98, "width": 16, "height": 32, "frame_bytes": 256, "frame_count": 9, "palette_offset": 0x36D8F8}, 92: {"data_offset": 0x38BA98, "width": 16, "height": 16, "frame_bytes": 128, "frame_count": 1, "palette_offset": 0x36D8F8}, 95: {"data_offset": 0x394618, "width": 16, "height": 16, "frame_bytes": 128, "frame_count": 4, "palette_offset": 0x36D8D8}}
	return profile

static func _leaf_green_profile() -> Dictionary:
	var profile: Dictionary = _profile("pokemon-leaf-green", "LeafGreen", "Kanto", false, -1)
	profile["map_names"] = _fire_red_profile().get("map_names", [])
	profile["extra_maps"] = _fire_red_profile().get("extra_maps", [])
	return profile
