class_name OpenMMOMapPlayCanvas
extends Control

signal location_changed(map_id: String, x: int, y: int)
signal back_requested
signal interaction_requested(dialogue: Dictionary)
signal sound_requested(effect: String)

const TILE_PIXELS: float = 16.0
const BORDER_MAP_OFFSET: int = 7
const CAMERA_MAX_CELLS_X: int = 30
const CAMERA_MAX_CELLS_Y: int = 20
const MAX_TILE_SCALE: float = 4.0
const REFERENCE_VIEWPORT_SIZE: Vector2 = Vector2(1280.0, 720.0)
const NORMAL_STEP_DURATION: float = 0.17
const ANIMATION_FRAME_INTERVAL: float = 0.125
const DOOR_ANIMATION_DURATION: float = 16.0 / 60.0
const DOOR_FRAME_COUNT: int = 4

var content
var map_id: String = ""
var map_texture: Texture2D
var foreground_texture: Texture2D
var map_pixel_size: Vector2 = Vector2.ZERO
var objects: Array = []
var regions: Array = []
var region_origins: Dictionary = {}
var world_bounds: Rect2 = Rect2()
var player_position: Vector2i = Vector2i.ZERO
var player_elevation: int = 3
var player_texture: Texture2D
var player_texture_key: String = ""
var animation_tick: int = 0
var animation_elapsed: float = 0.0
var movement_active: bool = false
var movement_start: Vector2 = Vector2.ZERO
var movement_target: Vector2 = Vector2.ZERO
var movement_jump: bool = false
var movement_stair: bool = false
var movement_stair_behavior: int = 0
var movement_door: bool = false
var door_progress: float = 0.0
var movement_elapsed: float = 0.0
var movement_duration: float = 0.14
var pending_map_id: String = ""
var pending_position: Vector2i = Vector2i.ZERO
var pending_elevation: int = 3
var pending_warp: Dictionary = {}
var warp_cooldown: float = 0.0
var has_spawn: bool = false
var input_enabled: bool = false
var player_facing: int = 1
var held_direction: int = 0
var movement_retry_elapsed: float = 0.0
var move_request_pending: bool = false
var move_request_elapsed: float = 0.0
var movement_prediction_pending: bool = false
var world_entities: Array = []
var authoritative_state: bool = false
var dialogue_active: bool = false
var resize_redraw_pending: bool = false

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true
	focus_mode = Control.FOCUS_ALL
	resized.connect(_on_resized)
	queue_redraw()

func _on_resized() -> void:
	if resize_redraw_pending:
		return
	resize_redraw_pending = true
	call_deferred("_finish_resize")

func _finish_resize() -> void:
	resize_redraw_pending = false
	if is_inside_tree():
		queue_redraw()

func set_content(value) -> void:
	content = value
	player_texture = null
	player_texture_key = ""
	foreground_texture = null
	if not map_id.is_empty():
		_set_spawn()
	_refresh_object_textures()
	queue_redraw()

func set_input_enabled(value: bool) -> void:
	input_enabled = value
	if value:
		call_deferred("_restore_input_focus")

func _restore_input_focus() -> void:
	if input_enabled and is_inside_tree():
		grab_focus()

func set_dialogue_active(value: bool) -> void:
	dialogue_active = value
	if value:
		held_direction = 0
		movement_retry_elapsed = 0.0
	else:
		_restore_interaction_facing()

func set_authoritative_state(value: bool) -> void:
	authoritative_state = value
	held_direction = 0
	move_request_pending = false
	move_request_elapsed = 0.0

func set_animation_tick(value: int) -> void:
	animation_tick = value
	queue_redraw()

func request_move(direction_name: String) -> bool:
	var direction: int = 0
	match direction_name.to_lower():
		"down":
			direction = 1
		"up":
			direction = 2
		"left":
			direction = 3
		"right":
			direction = 4
	if direction == 0:
		return false
	return _request_move(direction)

func set_map(texture: Texture2D, map_width: int, map_height: int, map_objects: Array, selected_map_id: String = "", map_foreground_texture: Texture2D = null) -> void:
	var changed: bool = not selected_map_id.is_empty() and map_id != selected_map_id
	if not selected_map_id.is_empty():
		map_id = selected_map_id
	regions = [{"map_id": map_id, "origin": Vector2i.ZERO, "width": map_width, "height": map_height, "background_texture": texture, "foreground_texture": map_foreground_texture, "objects": map_objects, "ready": true}]
	region_origins = {map_id: Vector2i.ZERO}
	_rebuild_world_bounds()
	map_texture = texture
	foreground_texture = map_foreground_texture
	map_pixel_size = Vector2(map_width * 16, map_height * 16)
	objects = map_objects
	if changed or not has_spawn:
		if authoritative_state:
			has_spawn = false
			movement_active = false
			pending_map_id = ""
			pending_warp = {}
		else:
			_set_spawn()
	_refresh_object_textures()
	if animation_tick > 0:
		set_animation_tick(animation_tick)
	_update_player_texture()
	queue_redraw()

func set_world(world_value: Dictionary, selected_map_id: String = "") -> void:
	var previous_map_id: String = map_id
	var previous_regions: Dictionary = region_origins.duplicate()
	regions = world_value.get("regions", []) if world_value.get("regions", []) is Array else []
	region_origins = {}
	for region_value in regions:
		if region_value is Dictionary:
			var region: Dictionary = region_value
			var region_id: String = str(region.get("map_id", ""))
			if not region_id.is_empty():
				region_origins[region_id] = region.get("origin", Vector2i.ZERO)
	_rebuild_world_bounds()
	var next_map_id: String = selected_map_id
	if next_map_id.is_empty():
		next_map_id = str(world_value.get("root_map_id", map_id))
	if next_map_id.is_empty() or not region_origins.has(next_map_id):
		return
	map_id = next_map_id
	_set_active_region(map_id)
	var changed: bool = previous_map_id != map_id
	if changed and not previous_regions.has(map_id):
		movement_active = false
		pending_map_id = ""
		pending_warp = {}
		if authoritative_state:
			has_spawn = false
		elif not has_spawn:
			_set_spawn()
	elif not has_spawn and not authoritative_state:
		_set_spawn()
	_refresh_object_textures()
	if animation_tick > 0:
		set_animation_tick(animation_tick)
	_update_player_texture()
	queue_redraw()

func set_active_map(selected_map_id: String) -> bool:
	if selected_map_id.is_empty() or not region_origins.has(selected_map_id):
		return false
	if not _ensure_region_rendered(selected_map_id):
		return false
	map_id = selected_map_id
	_set_active_region(map_id)
	_update_player_texture()
	queue_redraw()
	return true

func _ensure_region_rendered(selected_map_id: String) -> bool:
	if content == null:
		return false
	for region_index in range(regions.size()):
		if not regions[region_index] is Dictionary:
			continue
		var region: Dictionary = regions[region_index]
		if str(region.get("map_id", "")) != selected_map_id:
			continue
		if bool(region.get("ready", false)) and region.get("background_texture") is Texture2D:
			return true
		var prepared: Dictionary = content.prepare_map(selected_map_id, false)
		if not bool(prepared.get("ok", false)):
			return false
		region["background_texture"] = prepared.get("background_texture", prepared.get("texture"))
		region["foreground_texture"] = prepared.get("foreground_texture")
		region["objects"] = prepared.get("objects", [])
		region["warps"] = prepared.get("warps", [])
		region["connections"] = prepared.get("connections", region.get("connections", []))
		region["animated_background_tiles"] = prepared.get("animated_background_tiles", [])
		region["animated_foreground_tiles"] = prepared.get("animated_foreground_tiles", [])
		region["ready"] = true
		regions[region_index] = region
		_refresh_object_list(region.get("objects", []))
		return true
	return false

func _set_active_region(selected_map_id: String) -> void:
	for region_value in regions:
		if not region_value is Dictionary:
			continue
		var region: Dictionary = region_value
		if str(region.get("map_id", "")) != selected_map_id:
			continue
		map_texture = region.get("background_texture") as Texture2D
		foreground_texture = region.get("foreground_texture") as Texture2D
		map_pixel_size = Vector2(int(region.get("width", 0)) * TILE_PIXELS, int(region.get("height", 0)) * TILE_PIXELS)
		objects = region.get("objects", [])
		return

func _rebuild_world_bounds() -> void:
	if regions.is_empty():
		world_bounds = Rect2()
		return
	var has_bounds: bool = false
	var minimum: Vector2i = Vector2i.ZERO
	var maximum: Vector2i = Vector2i.ZERO
	for region_value in regions:
		if not region_value is Dictionary:
			continue
		var region: Dictionary = region_value
		var origin: Vector2i = _region_origin(str(region.get("map_id", "")))
		var extent: Vector2i = origin + Vector2i(int(region.get("width", 0)), int(region.get("height", 0)))
		if not has_bounds:
			minimum = origin
			maximum = extent
			has_bounds = true
		else:
			minimum.x = mini(minimum.x, origin.x)
			minimum.y = mini(minimum.y, origin.y)
			maximum.x = maxi(maximum.x, extent.x)
			maximum.y = maxi(maximum.y, extent.y)
	if has_bounds:
		world_bounds = Rect2(Vector2(minimum) * TILE_PIXELS, Vector2(maximum - minimum) * TILE_PIXELS)

func _region_origin(selected_map_id: String) -> Vector2i:
	var value: Variant = region_origins.get(selected_map_id, Vector2i.ZERO)
	if value is Vector2i:
		return value
	if value is Vector2:
		return Vector2i(value)
	return Vector2i.ZERO

func _world_position(selected_map_id: String, local_position: Vector2) -> Vector2:
	return Vector2(_region_origin(selected_map_id)) + local_position

func _movement_world_position() -> Vector2:
	if not movement_active:
		return _world_position(map_id, Vector2(player_position))
	var start_world: Vector2 = _world_position(map_id, movement_start)
	var target_world: Vector2
	if region_origins.has(pending_map_id):
		target_world = _world_position(pending_map_id, pending_position)
	else:
		target_world = start_world + _direction_vector(player_facing)
	return start_world.lerp(target_world, clampf(movement_elapsed / movement_duration, 0.0, 1.0))

func set_player_state(x: int, y: int, elevation: int = 3, facing: int = 1) -> void:
	var next_position: Vector2i = Vector2i(x, y)
	if authoritative_state:
		move_request_pending = false
		move_request_elapsed = 0.0
	if authoritative_state and has_spawn and next_position == pending_position and movement_active:
		movement_prediction_pending = false
		pending_elevation = elevation
		return
	if authoritative_state and has_spawn and next_position == player_position and movement_active and movement_prediction_pending:
		return
	if authoritative_state and has_spawn and next_position == player_position:
		player_elevation = elevation
		if not movement_active:
			player_facing = facing
		else:
			pending_elevation = elevation
		queue_redraw()
		return
	if authoritative_state and has_spawn and absi(next_position.x - player_position.x) + absi(next_position.y - player_position.y) == 1:
		player_facing = _direction_between(player_position, next_position)
		movement_start = Vector2(player_position)
		movement_target = Vector2(next_position)
		pending_map_id = map_id
		pending_position = next_position
		pending_elevation = elevation
		movement_elapsed = 0.0
		movement_duration = NORMAL_STEP_DURATION
		movement_active = true
	else:
		player_position = next_position
		player_elevation = elevation
		player_facing = facing
		movement_start = Vector2(player_position)
		movement_target = movement_start
		movement_active = false
	has_spawn = true
	_update_player_texture()
	queue_redraw()

func _direction_between(from: Vector2i, to: Vector2i) -> int:
	if to.y > from.y:
		return 1
	if to.y < from.y:
		return 2
	if to.x < from.x:
		return 3
	if to.x > from.x:
		return 4
	return player_facing

func _direction_vector(direction: int) -> Vector2:
	match direction:
		1:
			return Vector2.DOWN
		2:
			return Vector2.UP
		3:
			return Vector2.LEFT
		4:
			return Vector2.RIGHT
	return Vector2.ZERO

func set_world_entities(values: Array, local_character_id: int) -> void:
	world_entities = []
	if content == null:
		return
	for value in values:
		if not value is Dictionary:
			continue
		var entity: Dictionary = value
		var entity_map_id: String = str(entity.get("map_id", ""))
		if int(entity.get("character_id", 0)) == local_character_id or not region_origins.has(entity_map_id):
			continue
		var is_npc: bool = bool(entity.get("npc", false))
		var graphics_id: int = int(entity.get("graphics_id", 19)) if is_npc else 19
		var sprite: Dictionary = content.render_facing_object_sprite(graphics_id, int(entity.get("facing", 1)), false, 0)
		var texture: Texture2D = sprite.get("texture") as Texture2D
		if texture == null:
			continue
		world_entities.append({"entity_id": int(entity.get("entity_id", 0)), "npc": is_npc, "map_id": entity_map_id, "texture": texture, "width": texture.get_width(), "height": texture.get_height(), "x": int(entity.get("x", 0)), "y": int(entity.get("y", 0)), "elevation": int(entity.get("elevation", 3)), "facing": int(entity.get("facing", 1)), "default_facing": int(entity.get("facing", 1)), "graphics_id": graphics_id, "blocks_movement": bool(entity.get("blocks_movement", is_npc))})
	queue_redraw()

func _apply_map(result: Dictionary, reset_spawn: bool) -> void:
	map_texture = result.get("texture", result.get("background_texture")) as Texture2D
	foreground_texture = result.get("foreground_texture") as Texture2D
	map_pixel_size = Vector2(int(result.get("width", 0)) * 16, int(result.get("height", 0)) * 16)
	objects = result.get("objects", [])
	regions = [{"map_id": map_id, "origin": Vector2i.ZERO, "width": int(result.get("width", 0)), "height": int(result.get("height", 0)), "background_texture": map_texture, "foreground_texture": foreground_texture, "objects": objects, "ready": true}]
	region_origins = {map_id: Vector2i.ZERO}
	_rebuild_world_bounds()
	_refresh_object_textures()
	if reset_spawn:
		_set_spawn()

func _set_spawn() -> void:
	if content == null or map_id.is_empty():
		return
	var spawn: Dictionary = content.default_spawn(map_id)
	if not bool(spawn.get("ok", false)):
		has_spawn = false
		return
	player_position = Vector2i(int(spawn.get("x", 0)), int(spawn.get("y", 0)))
	player_elevation = int(spawn.get("elevation", 3))
	player_facing = 1
	has_spawn = true
	movement_active = false
	movement_stair = false
	movement_stair_behavior = 0
	movement_door = false
	door_progress = 0.0
	pending_warp = {}
	warp_cooldown = 0.0

func _input(event: InputEvent) -> void:
	if not input_enabled or not visible:
		return
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if key_event.keycode == KEY_ESCAPE and key_event.pressed and not key_event.echo:
		get_viewport().set_input_as_handled()
		back_requested.emit()
		return
	if key_event.keycode == KEY_F and key_event.pressed and not key_event.echo:
		if dialogue_active:
			return
		get_viewport().set_input_as_handled()
		interact()
		return
	if dialogue_active:
		return
	var direction: int = _key_direction(key_event)
	if direction == 0:
		return
	if not key_event.pressed:
		if held_direction == direction:
			held_direction = 0
		return
	if key_event.echo:
		return
	held_direction = direction
	get_viewport().set_input_as_handled()
	if not movement_active:
		movement_retry_elapsed = 0.0
		_request_move(direction)

func interact() -> void:
	if content == null or map_id.is_empty() or dialogue_active:
		return
	var target_position: Vector2i = player_position + Vector2i(_direction_vector(player_facing))
	for index in world_entities.size():
		var entity_value: Variant = world_entities[index]
		if not entity_value is Dictionary:
			continue
		var entity: Dictionary = entity_value
		if not bool(entity.get("npc", false)) or str(entity.get("map_id", "")) != map_id or int(entity.get("x", -1)) != target_position.x or int(entity.get("y", -1)) != target_position.y or int(entity.get("elevation", player_elevation)) != player_elevation:
			continue
		if authoritative_state:
			if not GameState.send_entity_interact(int(entity.get("entity_id", 0)), 0):
				return
		_face_world_entity(index, player_facing)
		dialogue_active = true
		return
	var interaction: Dictionary = content.interaction_at(map_id, player_position.x, player_position.y, player_facing, player_elevation, objects)
	if bool(interaction.get("ok", false)):
		if authoritative_state:
			if str(interaction.get("kind", "")) == "sign":
				if GameState.send_tile_interact():
					dialogue_active = true
				return
			return
		_face_interaction_object(interaction.get("object", {}))
		interaction_requested.emit(interaction)

func _key_direction(event: InputEventKey) -> int:
	match event.keycode:
		KEY_DOWN, KEY_S:
			return 1
		KEY_UP, KEY_W:
			return 2
		KEY_LEFT, KEY_A:
			return 3
		KEY_RIGHT, KEY_D:
			return 4
	return 0

func _request_move(direction: int) -> bool:
	if content == null or map_id.is_empty() or not has_spawn:
		return false
	if authoritative_state and (movement_active or move_request_pending):
		return false
	player_facing = direction
	_update_player_texture()
	queue_redraw()
	var occupied: Array = objects.duplicate()
	for entity_value in world_entities:
		if not entity_value is Dictionary:
			continue
		var entity: Dictionary = entity_value
		if bool(entity.get("npc", false)) and bool(entity.get("blocks_movement", true)) and str(entity.get("map_id", "")) == map_id:
			occupied.append({"x": int(entity.get("x", -1)), "y": int(entity.get("y", -1)), "elevation": int(entity.get("elevation", player_elevation)), "collision": 1, "blocks_movement": true})
	var result: Dictionary = content.movement_result(map_id, player_position.x, player_position.y, direction, player_elevation, occupied)
	if authoritative_state:
		if not bool(result.get("ok", false)):
			return false
		if not GameState.send_input(_direction_name(direction), player_position.x, player_position.y):
			return false
		pending_map_id = str(result.get("map_id", map_id))
		pending_position = Vector2i(int(result.get("x", player_position.x)), int(result.get("y", player_position.y)))
		pending_elevation = int(result.get("elevation", player_elevation))
		movement_stair = bool(result.get("stair", false))
		movement_stair_behavior = int(result.get("stair_behavior", 0))
		movement_door = bool(result.get("door", false)) and not movement_stair
		pending_warp = result.get("warp", {}) if movement_stair or movement_door else {}
		movement_start = Vector2(player_position)
		movement_target = movement_start + _direction_vector(direction) if pending_map_id != map_id else Vector2(pending_position)
		movement_jump = bool(result.get("jump", false))
		movement_elapsed = 0.0
		movement_duration = 0.24 if movement_stair else DOOR_ANIMATION_DURATION if movement_door else 0.32 if movement_jump else NORMAL_STEP_DURATION
		door_progress = 0.0
		movement_prediction_pending = true
		movement_active = true
		sound_requested.emit("door" if movement_door else "step")
		queue_redraw()
		move_request_pending = true
		move_request_elapsed = 0.0
		return true
	elif not bool(result.get("ok", false)):
		return false
	pending_map_id = str(result.get("map_id", map_id))
	pending_position = Vector2i(int(result.get("x", player_position.x)), int(result.get("y", player_position.y)))
	pending_elevation = int(result.get("elevation", player_elevation))
	movement_stair = bool(result.get("stair", false))
	movement_stair_behavior = int(result.get("stair_behavior", 0))
	movement_door = bool(result.get("door", false)) and not movement_stair
	pending_warp = result.get("warp", {}) if movement_stair or movement_door else {}
	movement_start = Vector2(player_position)
	movement_target = movement_start + _direction_vector(direction) if pending_map_id != map_id else Vector2(pending_position)
	movement_jump = bool(result.get("jump", false))
	movement_elapsed = 0.0
	movement_duration = 0.24 if movement_stair else DOOR_ANIMATION_DURATION if movement_door else 0.32 if movement_jump else NORMAL_STEP_DURATION
	door_progress = 0.0
	movement_active = true
	sound_requested.emit("door" if movement_door else "step")
	queue_redraw()
	return true

func _process(delta: float) -> void:
	if warp_cooldown > 0.0:
		warp_cooldown = maxf(warp_cooldown - delta, 0.0)
	animation_elapsed += delta
	if animation_elapsed >= ANIMATION_FRAME_INTERVAL:
		animation_elapsed = fmod(animation_elapsed, ANIMATION_FRAME_INTERVAL)
		animation_tick += 1
		queue_redraw()
	if move_request_pending:
		move_request_elapsed += delta
		if move_request_elapsed >= 0.35:
			move_request_pending = false
			move_request_elapsed = 0.0
			if movement_prediction_pending and movement_active:
				movement_active = false
				movement_prediction_pending = false
				player_position = Vector2i(movement_start)
				pending_map_id = ""
				pending_warp = {}
				queue_redraw()
	if not movement_active:
		if held_direction != 0:
			movement_retry_elapsed += delta
			if movement_retry_elapsed >= 0.05:
				movement_retry_elapsed = 0.0
				_request_move(held_direction)
		else:
			movement_retry_elapsed = 0.0
		return
	movement_elapsed += delta
	if movement_door and movement_duration > 0.0:
		door_progress = clampf(movement_elapsed / movement_duration, 0.0, 1.0)
	_update_player_texture()
	if movement_elapsed < movement_duration:
		queue_redraw()
		return
	var completed_map_id: String = pending_map_id
	var completed_position: Vector2i = pending_position
	var completed_elevation: int = pending_elevation
	var completed_warp: Dictionary = pending_warp
	movement_active = false
	movement_stair = false
	movement_stair_behavior = 0
	movement_door = false
	door_progress = 0.0
	pending_warp = {}
	player_position = completed_position
	player_elevation = completed_elevation
	if authoritative_state:
		if completed_map_id != map_id:
			set_active_map(completed_map_id)
		_update_player_texture()
		location_changed.emit(map_id, player_position.x, player_position.y)
		queue_redraw()
		if held_direction != 0 and completed_map_id == map_id:
			movement_retry_elapsed = 0.0
			_request_move(held_direction)
		return
	if completed_map_id != map_id:
		if not set_active_map(completed_map_id):
			_load_map(completed_map_id)
	else:
		_update_player_texture()
	var warp: Dictionary = completed_warp if not completed_warp.is_empty() else content.warp_at(completed_map_id, completed_position.x, completed_position.y, completed_elevation)
	if bool(warp.get("ok", false)) and warp_cooldown <= 0.0:
		map_id = str(warp.get("map_id", map_id))
		player_position = Vector2i(int(warp.get("x", player_position.x)), int(warp.get("y", player_position.y)))
		player_elevation = int(warp.get("elevation", player_elevation))
		_load_map(map_id, false)
		warp_cooldown = 0.35
	location_changed.emit(map_id, player_position.x, player_position.y)
	queue_redraw()
	if held_direction != 0 and not movement_active:
		movement_retry_elapsed = 0.0
		_request_move(held_direction)

func _load_map(next_map_id: String, reset_spawn: bool = false) -> void:
	if content == null or next_map_id.is_empty():
		return
	var connected_world: Dictionary = content.prepare_connected_world(next_map_id, 96, 1, GameState.server_maps)
	if bool(connected_world.get("ok", false)):
		set_world(connected_world, next_map_id)
		if reset_spawn and not authoritative_state:
			_set_spawn()
		return
	map_id = next_map_id
	var result: Dictionary = content.prepare_map(map_id)
	if not bool(result.get("ok", false)):
		return
	_apply_map(result, reset_spawn)
	if animation_tick > 0:
		set_animation_tick(animation_tick)
	if not reset_spawn:
		has_spawn = true
	_refresh_object_textures()
	_update_player_texture()

func _refresh_object_textures() -> void:
	if content == null:
		return
	for region_value in regions:
		if region_value is Dictionary:
			_refresh_object_list(region_value.get("objects", []))
	if regions.is_empty():
		_refresh_object_list(objects)

func _refresh_object_list(values: Array) -> void:
	if content == null:
		return
	for object_value in values:
		if not object_value is Dictionary or not bool(object_value.get("render", true)):
			continue
		var object: Dictionary = object_value
		var sprite: Dictionary = content.render_facing_object_sprite(int(object.get("graphics_id", -1)), int(object.get("facing", object.get("default_facing", 1))), false, 0)
		if bool(sprite.get("ok", false)):
			object["texture"] = sprite.get("texture")
			object["width"] = int(sprite.get("width", 0))
			object["height"] = int(sprite.get("height", 0))

func _update_player_texture() -> void:
	if content == null:
		return
	var frame_step: int = 0
	if movement_active and movement_duration > 0.0:
		frame_step = int(floorf(clampf(movement_elapsed / movement_duration, 0.0, 0.999) * 4.0))
	var movement_key: int = 1 if movement_active else 0
	var texture_key: String = "%d:%d:%d" % [player_facing, movement_key, frame_step]
	if player_texture != null and player_texture_key == texture_key:
		return
	var sprite: Dictionary = content.render_facing_object_sprite(19, player_facing, movement_active, frame_step)
	player_texture = sprite.get("texture") as Texture2D
	player_texture_key = texture_key if player_texture != null else ""

func _tile_scale() -> float:
	var maximum_camera_size: Vector2 = Vector2(CAMERA_MAX_CELLS_X * TILE_PIXELS, CAMERA_MAX_CELLS_Y * TILE_PIXELS)
	var reference_scale: float = minf(maxf(ceilf(maxf(REFERENCE_VIEWPORT_SIZE.x / maximum_camera_size.x, REFERENCE_VIEWPORT_SIZE.y / maximum_camera_size.y)), 1.0), MAX_TILE_SCALE)
	var viewport_scale: float = maxf(ceilf(maxf(size.x / maximum_camera_size.x, size.y / maximum_camera_size.y)), 1.0)
	return minf(reference_scale, viewport_scale)

func dialogue_anchor_screen(dialogue: Dictionary) -> Vector2:
	if regions.is_empty() or not has_spawn:
		return size * 0.5
	var tile_scale: float = _tile_scale()
	var camera_world_size: Vector2 = size / tile_scale
	var world_player: Vector2 = _movement_world_position()
	var camera_center: Vector2 = (world_player + Vector2(0.5, 0.5)) * TILE_PIXELS
	var camera_origin: Vector2 = camera_center - camera_world_size * 0.5
	var object: Dictionary = dialogue.get("object", {})
	var object_map_id: String = str(object.get("map_id", map_id))
	var object_position: Vector2 = _world_position(object_map_id, Vector2(int(object.get("x", player_position.x)), int(object.get("y", player_position.y))))
	var object_x: float = (object_position.x + 0.5) * TILE_PIXELS
	var object_y: float = (object_position.y + 1.0) * TILE_PIXELS
	var object_height: float = float(int(object.get("height", 16)))
	var destination_position: Vector2 = (size - camera_world_size * tile_scale) * 0.5
	return destination_position + Vector2((object_x - camera_origin.x) * tile_scale, (object_y - object_height - camera_origin.y) * tile_scale)

func _face_interaction_object(object_value: Variant) -> void:
	if not object_value is Dictionary:
		return
	var object: Dictionary = object_value
	if not bool(object.get("render", true)) or int(object.get("graphics_id", -1)) < 0:
		return
	var object_direction: int = _opposite_direction(player_facing)
	object["facing"] = object_direction
	var sprite: Dictionary = content.render_facing_object_sprite(int(object.get("graphics_id", -1)), object_direction, false, 0)
	if bool(sprite.get("ok", false)):
		object["texture"] = sprite.get("texture")
		object["width"] = int(sprite.get("width", 0))
		object["height"] = int(sprite.get("height", 0))
	queue_redraw()

func _restore_interaction_facing() -> void:
	for object_value in objects:
		if not object_value is Dictionary:
			continue
		var object: Dictionary = object_value
		var default_facing: int = int(object.get("default_facing", object.get("facing", 1)))
		if int(object.get("facing", default_facing)) != default_facing:
			object["facing"] = default_facing
	_refresh_object_textures()
	queue_redraw()

func restore_interaction_facing() -> void:
	_restore_interaction_facing()
	for index in world_entities.size():
		var entity_value: Variant = world_entities[index]
		if not entity_value is Dictionary:
			continue
		var entity: Dictionary = (entity_value as Dictionary).duplicate()
		if not bool(entity.get("npc", false)):
			continue
		var facing: int = int(entity.get("default_facing", 1))
		entity["facing"] = facing
		var sprite: Dictionary = content.render_facing_object_sprite(int(entity.get("graphics_id", 19)), facing, false, 0)
		if bool(sprite.get("ok", false)):
			entity["texture"] = sprite.get("texture")
			entity["width"] = int(sprite.get("width", 0))
			entity["height"] = int(sprite.get("height", 0))
		world_entities[index] = entity
	queue_redraw()

func _face_world_entity(index: int, player_direction: int) -> void:
	if index < 0 or index >= world_entities.size() or content == null:
		return
	var entity_value: Variant = world_entities[index]
	if not entity_value is Dictionary:
		return
	var entity: Dictionary = (entity_value as Dictionary).duplicate()
	var facing: int = _opposite_direction(player_direction)
	entity["facing"] = facing
	var sprite: Dictionary = content.render_facing_object_sprite(int(entity.get("graphics_id", 19)), facing, false, 0)
	if bool(sprite.get("ok", false)):
		entity["texture"] = sprite.get("texture")
		entity["width"] = int(sprite.get("width", 0))
		entity["height"] = int(sprite.get("height", 0))
	world_entities[index] = entity
	queue_redraw()

func _opposite_direction(direction: int) -> int:
	match direction:
		1:
			return 2
		2:
			return 1
		3:
			return 4
		4:
			return 3
	return 1

func _direction_name(direction: int) -> String:
	match direction:
		1:
			return "down"
		2:
			return "up"
		3:
			return "left"
		4:
			return "right"
	return ""

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK, true)
	if regions.is_empty() or not has_spawn:
		return
	var tile_scale: float = _tile_scale()
	var camera_world_size: Vector2 = size / tile_scale
	var world_player: Vector2 = _movement_world_position()
	if movement_active and movement_jump:
		world_player.y -= sin(clampf(movement_elapsed / movement_duration, 0.0, 1.0) * PI) * 0.75
	var camera_center: Vector2 = (world_player + Vector2(0.5, 0.5)) * TILE_PIXELS
	var camera_origin: Vector2 = camera_center - camera_world_size * 0.5
	if world_bounds.size.x > 0.0:
		camera_origin.x = clampf(camera_origin.x, world_bounds.position.x, maxf(world_bounds.end.x - camera_world_size.x, world_bounds.position.x))
	if world_bounds.size.y > 0.0:
		camera_origin.y = clampf(camera_origin.y, world_bounds.position.y, maxf(world_bounds.end.y - camera_world_size.y, world_bounds.position.y))
	var destination_size: Vector2 = camera_world_size * tile_scale
	var destination_position: Vector2 = (size - destination_size) * 0.5
	var drawables: Array = []
	var camera_rect: Rect2 = Rect2(camera_origin, camera_world_size)
	for border_region_value in regions:
		if not border_region_value is Dictionary:
			continue
		var border_region: Dictionary = border_region_value
		var border_texture: Texture2D = border_region.get("border_texture") as Texture2D
		if border_texture == null:
			continue
		var border_map_id: String = str(border_region.get("map_id", ""))
		var border_origin: Vector2 = Vector2(_region_origin(border_map_id)) * TILE_PIXELS
		var border_size: Vector2 = Vector2(int(border_region.get("width", 0)), int(border_region.get("height", 0))) * TILE_PIXELS
		var border_padding: float = BORDER_MAP_OFFSET * TILE_PIXELS
		var border_limit: Rect2 = Rect2(border_origin, border_size).grow(border_padding)
		_draw_border_pattern(border_texture, border_origin, camera_rect, destination_position, tile_scale, border_limit)
	for region_value in regions:
		if not region_value is Dictionary:
			continue
		var region: Dictionary = region_value
		var region_id: String = str(region.get("map_id", ""))
		var region_origin: Vector2 = Vector2(_region_origin(region_id)) * TILE_PIXELS
		var region_size: Vector2 = Vector2(int(region.get("width", 0)), int(region.get("height", 0))) * TILE_PIXELS
		var region_rect: Rect2 = Rect2(region_origin, region_size)
		var visible_region: Rect2 = region_rect.intersection(camera_rect)
		if visible_region.size.x > 0.0 and visible_region.size.y > 0.0:
			var background: Texture2D = region.get("background_texture") as Texture2D
			if background != null:
				var background_destination: Rect2 = Rect2(destination_position + (visible_region.position - camera_origin) * tile_scale, visible_region.size * tile_scale)
				var background_source: Rect2 = Rect2(visible_region.position - region_origin, visible_region.size)
				draw_texture_rect_region(background, background_destination, background_source, Color.WHITE, false, true)
			for tile_value in region.get("animated_background_tiles", []):
				if not tile_value is Dictionary:
					continue
				var animated_tile: Dictionary = tile_value
				var tile_world_position: Vector2 = region_origin + Vector2(int(animated_tile.get("x", 0)), int(animated_tile.get("y", 0)))
				var tile_rect: Rect2 = Rect2(tile_world_position, Vector2(8.0, 8.0))
				if not tile_rect.intersects(camera_rect):
					continue
				var animated_texture: Texture2D = content.animated_tile_texture(region_id, int(animated_tile.get("entry", 0)), animation_tick)
				if animated_texture == null:
					continue
				draw_texture_rect(animated_texture, Rect2(destination_position + (tile_world_position - camera_origin) * tile_scale, Vector2(8.0, 8.0) * tile_scale), false)
			var foreground: Texture2D = region.get("foreground_texture") as Texture2D
			if foreground != null:
				var first_row: int = maxi(0, floori((camera_rect.position.y - region_origin.y) / TILE_PIXELS) - 1)
				var last_row: int = mini(int(region.get("height", 0)) - 1, ceili((camera_rect.end.y - region_origin.y) / TILE_PIXELS) + 1)
				for row_index in range(first_row, last_row + 1):
					var row_rect: Rect2 = Rect2(region_origin + Vector2(0.0, row_index * TILE_PIXELS), Vector2(region_size.x, TILE_PIXELS))
					var visible_row: Rect2 = row_rect.intersection(camera_rect)
					if visible_row.size.x > 0.0 and visible_row.size.y > 0.0:
						drawables.append({"kind": "foreground", "map_id": region_id, "texture": foreground, "rect": visible_row, "sort_y": float(_region_origin(region_id).y + row_index + 1), "sort_order": 2})
			for tile_value in region.get("animated_foreground_tiles", []):
				if not tile_value is Dictionary:
					continue
				var animated_tile: Dictionary = tile_value
				var tile_world_position: Vector2 = region_origin + Vector2(int(animated_tile.get("x", 0)), int(animated_tile.get("y", 0)))
				var tile_rect: Rect2 = Rect2(tile_world_position, Vector2(8.0, 8.0))
				if not tile_rect.intersects(camera_rect):
					continue
				var animated_texture: Texture2D = content.animated_tile_texture(region_id, int(animated_tile.get("entry", 0)), animation_tick)
				if animated_texture == null:
					continue
				drawables.append({"kind": "animated_tile", "texture": animated_texture, "world_position": tile_world_position, "sort_y": float(_region_origin(region_id).y + floori(float(int(animated_tile.get("y", 0))) / TILE_PIXELS) + 1), "sort_order": 3})
			for object_value in region.get("objects", []):
				if not object_value is Dictionary:
					continue
				var object: Dictionary = object_value
				if authoritative_state and str(object.get("kind", "")) == "object":
					continue
				if not bool(object.get("render", true)):
					continue
				var texture: Texture2D = object.get("texture") as Texture2D
				if texture == null:
					continue
				var sprite_size: Vector2 = Vector2(int(object.get("width", 0)), int(object.get("height", 0)))
				if sprite_size.x <= 0.0 or sprite_size.y <= 0.0:
					continue
				var object_world: Vector2 = _world_position(region_id, Vector2(int(object.get("x", 0)), int(object.get("y", 0))))
				var object_rect: Rect2 = Rect2(Vector2((object_world.x + 0.5) * TILE_PIXELS - sprite_size.x * 0.5, (object_world.y + 1.0) * TILE_PIXELS - sprite_size.y), sprite_size)
				if not object_rect.grow(TILE_PIXELS).intersects(camera_rect):
					continue
				drawables.append({"kind": "sprite", "texture": texture, "width": sprite_size.x, "height": sprite_size.y, "world_anchor": Vector2((object_world.x + 0.5) * TILE_PIXELS, (object_world.y + 1.0) * TILE_PIXELS), "sort_y": object_world.y + 1.0, "sort_order": 0})
	for entity_value in world_entities:
		if not entity_value is Dictionary:
			continue
		var entity: Dictionary = entity_value
		var entity_texture: Texture2D = entity.get("texture") as Texture2D
		if entity_texture == null:
			continue
		var entity_map_id: String = str(entity.get("map_id", ""))
		var entity_world: Vector2 = _world_position(entity_map_id, Vector2(int(entity.get("x", 0)), int(entity.get("y", 0))))
		drawables.append({"kind": "sprite", "texture": entity_texture, "width": float(entity.get("width", 0)), "height": float(entity.get("height", 0)), "world_anchor": Vector2((entity_world.x + 0.5) * TILE_PIXELS, (entity_world.y + 1.0) * TILE_PIXELS), "sort_y": entity_world.y + 1.0, "sort_order": 0})
	if player_texture != null:
		var player_size: Vector2 = Vector2(player_texture.get_width(), player_texture.get_height())
		var player_anchor: Vector2 = (world_player + Vector2(0.5, 1.0)) * TILE_PIXELS
		drawables.append({"kind": "sprite", "texture": player_texture, "width": player_size.x, "height": player_size.y, "world_anchor": player_anchor, "sort_y": world_player.y + 1.0, "sort_order": 1})
	drawables.sort_custom(_sort_drawables)
	for drawable_value in drawables:
		var drawable: Dictionary = drawable_value
		if str(drawable.get("kind", "sprite")) == "foreground":
			var foreground_rect: Rect2 = drawable.get("rect", Rect2())
			var foreground_texture_value: Texture2D = drawable.get("texture") as Texture2D
			var foreground_destination: Rect2 = Rect2(destination_position + (foreground_rect.position - camera_origin) * tile_scale, foreground_rect.size * tile_scale)
			var foreground_origin: Vector2 = Vector2(_region_origin(str(drawable.get("map_id", "")))) * TILE_PIXELS
			draw_texture_rect_region(foreground_texture_value, foreground_destination, Rect2(foreground_rect.position - foreground_origin, foreground_rect.size), Color.WHITE, false, true)
			continue
		if str(drawable.get("kind", "sprite")) == "animated_tile":
			var animated_drawable_texture: Texture2D = drawable.get("texture") as Texture2D
			var animated_world_position: Vector2 = drawable.get("world_position", Vector2.ZERO)
			draw_texture_rect(animated_drawable_texture, Rect2(destination_position + (animated_world_position - camera_origin) * tile_scale, Vector2(8.0, 8.0) * tile_scale), false)
			continue
		var drawable_texture: Texture2D = drawable.get("texture") as Texture2D
		var drawable_size: Vector2 = Vector2(float(drawable.get("width", 0.0)), float(drawable.get("height", 0.0)))
		var drawable_anchor: Vector2 = drawable.get("world_anchor", Vector2.ZERO)
		var drawable_position: Vector2 = destination_position + (drawable_anchor - camera_origin) * tile_scale - Vector2(drawable_size.x * tile_scale * 0.5, drawable_size.y * tile_scale)
		draw_texture_rect(drawable_texture, Rect2(drawable_position, drawable_size * tile_scale), false)

func _draw_border_pattern(texture: Texture2D, region_origin: Vector2, camera_rect: Rect2, destination_position: Vector2, tile_scale: float, draw_limit: Rect2) -> void:
	var pattern_size: Vector2 = Vector2(texture.get_width(), texture.get_height())
	if pattern_size.x <= 0.0 or pattern_size.y <= 0.0:
		return
	var visible_camera: Rect2 = camera_rect.intersection(draw_limit)
	if visible_camera.size.x <= 0.0 or visible_camera.size.y <= 0.0:
		return
	var pattern_origin: Vector2 = region_origin - Vector2(BORDER_MAP_OFFSET * TILE_PIXELS, BORDER_MAP_OFFSET * TILE_PIXELS)
	var first_x: int = floori((visible_camera.position.x - pattern_origin.x) / pattern_size.x) - 1
	var first_y: int = floori((visible_camera.position.y - pattern_origin.y) / pattern_size.y) - 1
	var last_x: int = ceili((visible_camera.end.x - pattern_origin.x) / pattern_size.x) + 1
	var last_y: int = ceili((visible_camera.end.y - pattern_origin.y) / pattern_size.y) + 1
	for pattern_y in range(first_y, last_y):
		for pattern_x in range(first_x, last_x):
			var pattern_rect: Rect2 = Rect2(pattern_origin + Vector2(pattern_x * pattern_size.x, pattern_y * pattern_size.y), pattern_size)
			var visible_rect: Rect2 = pattern_rect.intersection(visible_camera)
			if visible_rect.size.x <= 0.0 or visible_rect.size.y <= 0.0:
				continue
			var destination: Rect2 = Rect2(destination_position + (visible_rect.position - camera_rect.position) * tile_scale, visible_rect.size * tile_scale)
			var source: Rect2 = Rect2(visible_rect.position - pattern_rect.position, visible_rect.size)
			draw_texture_rect_region(texture, destination, source, Color.WHITE, false, true)

func _sort_drawables(left: Dictionary, right: Dictionary) -> bool:
	var left_y: float = float(left.get("sort_y", 0.0))
	var right_y: float = float(right.get("sort_y", 0.0))
	if not is_equal_approx(left_y, right_y):
		return left_y < right_y
	return int(left.get("sort_order", 0)) < int(right.get("sort_order", 0))
