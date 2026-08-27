class_name MonWorldMapPlayCanvas
extends Control

signal location_changed(map_id: String, x: int, y: int)
signal back_requested
signal interaction_requested(text: String)

const TILE_PIXELS: float = 16.0
const CAMERA_MAX_CELLS_X: int = 30
const CAMERA_MAX_CELLS_Y: int = 20

var content: MonWorldContent
var map_id: String = ""
var map_texture: Texture2D
var foreground_texture: Texture2D
var map_pixel_size: Vector2 = Vector2.ZERO
var objects: Array = []
var player_position: Vector2i = Vector2i.ZERO
var player_elevation: int = 3
var player_texture: Texture2D
var animation_tick: int = 0
var movement_active: bool = false
var movement_start: Vector2 = Vector2.ZERO
var movement_target: Vector2 = Vector2.ZERO
var movement_jump: bool = false
var movement_stair: bool = false
var movement_stair_behavior: int = 0
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
var movement_repeat_elapsed: float = 0.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true
	focus_mode = Control.FOCUS_ALL
	queue_redraw()

func set_content(value: MonWorldContent) -> void:
	content = value
	player_texture = null
	foreground_texture = null
	if not map_id.is_empty():
		_set_spawn()
	queue_redraw()

func set_input_enabled(value: bool) -> void:
	input_enabled = value
	if value:
		grab_focus()

func set_animation_tick(value: int) -> void:
	animation_tick = value
	if content == null or map_id.is_empty():
		return
	var result: Dictionary = content.render_map(map_id, animation_tick)
	if bool(result.get("ok", false)):
		_apply_map(result, false)
	_update_player_texture()
	queue_redraw()

func set_map(texture: Texture2D, map_width: int, map_height: int, map_objects: Array, selected_map_id: String = "", map_foreground_texture: Texture2D = null) -> void:
	var changed: bool = not selected_map_id.is_empty() and map_id != selected_map_id
	if not selected_map_id.is_empty():
		map_id = selected_map_id
	map_texture = texture
	foreground_texture = map_foreground_texture
	map_pixel_size = Vector2(map_width * 16, map_height * 16)
	objects = map_objects
	if changed or not has_spawn:
		_set_spawn()
	_update_player_texture()
	queue_redraw()

func _apply_map(result: Dictionary, reset_spawn: bool) -> void:
	map_texture = result.get("background_texture", result.get("texture")) as Texture2D
	foreground_texture = result.get("foreground_texture") as Texture2D
	map_pixel_size = Vector2(int(result.get("width", 0)) * 16, int(result.get("height", 0)) * 16)
	objects = result.get("objects", [])
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
		get_viewport().set_input_as_handled()
		var interaction: Dictionary = content.interaction_at(map_id, player_position.x, player_position.y, player_facing, player_elevation, objects)
		if bool(interaction.get("ok", false)):
			interaction_requested.emit(str(interaction.get("text", "")))
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
		movement_repeat_elapsed = 0.0
		_request_move(direction)

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

func _request_move(direction: int) -> void:
	if content == null or map_id.is_empty() or not has_spawn:
		return
	player_facing = direction
	_update_player_texture()
	queue_redraw()
	var result: Dictionary = content.movement_result(map_id, player_position.x, player_position.y, direction, player_elevation, objects)
	if not bool(result.get("ok", false)):
		return
	pending_map_id = str(result.get("map_id", map_id))
	pending_position = Vector2i(int(result.get("x", player_position.x)), int(result.get("y", player_position.y)))
	pending_elevation = int(result.get("elevation", player_elevation))
	movement_stair = bool(result.get("stair", false))
	movement_stair_behavior = int(result.get("stair_behavior", 0))
	pending_warp = result.get("warp", {}) if movement_stair else {}
	movement_start = Vector2(player_position)
	movement_target = Vector2(pending_position)
	movement_jump = bool(result.get("jump", false))
	movement_elapsed = 0.0
	movement_duration = 0.20 if movement_stair else 0.28 if movement_jump else 0.14
	movement_active = true
	queue_redraw()

func _process(delta: float) -> void:
	if warp_cooldown > 0.0:
		warp_cooldown = maxf(warp_cooldown - delta, 0.0)
	if not movement_active:
		if held_direction != 0:
			movement_repeat_elapsed += delta
			if movement_repeat_elapsed >= 0.08:
				movement_repeat_elapsed = 0.0
				_request_move(held_direction)
		else:
			movement_repeat_elapsed = 0.0
		return
	movement_elapsed += delta
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
	pending_warp = {}
	player_position = completed_position
	player_elevation = completed_elevation
	if completed_map_id != map_id:
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

func _load_map(next_map_id: String, reset_spawn: bool = false) -> void:
	if content == null or next_map_id.is_empty():
		return
	map_id = next_map_id
	var result: Dictionary = content.render_map(map_id, animation_tick)
	if not bool(result.get("ok", false)):
		return
	_apply_map(result, reset_spawn)
	if not reset_spawn:
		has_spawn = true
	_update_player_texture()

func _update_player_texture() -> void:
	if content == null:
		return
	var frame_step: int = 0
	if movement_active and movement_duration > 0.0:
		frame_step = int(floorf(clampf(movement_elapsed / movement_duration, 0.0, 0.999) * 4.0))
	var sprite: Dictionary = content.render_facing_object_sprite(19, player_facing, movement_active, frame_step)
	player_texture = sprite.get("texture") as Texture2D

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("080B10"), true)
	if map_texture == null or map_pixel_size.x <= 0.0 or map_pixel_size.y <= 0.0 or not has_spawn:
		return
	var available_size: Vector2 = size - Vector2(24.0, 24.0)
	var camera_world_size: Vector2 = Vector2(minf(map_pixel_size.x, CAMERA_MAX_CELLS_X * TILE_PIXELS), minf(map_pixel_size.y, CAMERA_MAX_CELLS_Y * TILE_PIXELS))
	var tile_scale: float = minf(available_size.x / camera_world_size.x, available_size.y / camera_world_size.y)
	tile_scale = maxf(tile_scale, 0.01)
	var world_player: Vector2 = movement_start.lerp(movement_target, clampf(movement_elapsed / movement_duration, 0.0, 1.0)) if movement_active else Vector2(player_position)
	if movement_active and movement_jump:
		world_player.y -= sin(clampf(movement_elapsed / movement_duration, 0.0, 1.0) * PI) * 0.75
	var camera_center: Vector2 = (world_player + Vector2(0.5, 0.5)) * TILE_PIXELS
	var camera_origin: Vector2 = camera_center - camera_world_size * 0.5
	camera_origin.x = clampf(camera_origin.x, 0.0, maxf(map_pixel_size.x - camera_world_size.x, 0.0))
	camera_origin.y = clampf(camera_origin.y, 0.0, maxf(map_pixel_size.y - camera_world_size.y, 0.0))
	var destination_size: Vector2 = camera_world_size * tile_scale
	var destination_position: Vector2 = (size - destination_size) * 0.5
	draw_texture_rect_region(map_texture, Rect2(destination_position, destination_size), Rect2(camera_origin, camera_world_size), Color.WHITE, false, true)
	var drawables: Array = []
	for object_value in objects:
		if not object_value is Dictionary:
			continue
		var object: Dictionary = object_value
		var texture: Texture2D = object.get("texture") as Texture2D
		if texture == null:
			continue
		var sprite_size: Vector2 = Vector2(int(object.get("width", 0)), int(object.get("height", 0)))
		if sprite_size.x <= 0.0 or sprite_size.y <= 0.0:
			continue
		drawables.append({"texture": texture, "width": sprite_size.x, "height": sprite_size.y, "world_anchor": Vector2((int(object.get("x", 0)) + 0.5) * TILE_PIXELS, (int(object.get("y", 0)) + 1.0) * TILE_PIXELS), "sort_y": float(int(object.get("y", 0)) + 1), "sort_order": 0})
	if player_texture != null:
		var player_size: Vector2 = Vector2(player_texture.get_width(), player_texture.get_height())
		var player_anchor: Vector2 = (world_player + Vector2(0.5, 1.0)) * TILE_PIXELS
		if movement_active and movement_stair:
			player_anchor += _stair_offset(clampf(movement_elapsed / movement_duration, 0.0, 1.0), movement_stair_behavior)
		drawables.append({"texture": player_texture, "width": player_size.x, "height": player_size.y, "world_anchor": player_anchor, "sort_y": world_player.y + 1.0, "sort_order": 1})
	drawables.sort_custom(_sort_drawables)
	for drawable_value in drawables:
		var drawable: Dictionary = drawable_value
		var drawable_texture: Texture2D = drawable.get("texture") as Texture2D
		var drawable_size: Vector2 = Vector2(float(drawable.get("width", 0.0)), float(drawable.get("height", 0.0)))
		var drawable_anchor: Vector2 = drawable.get("world_anchor", Vector2.ZERO)
		var drawable_position: Vector2 = destination_position + (drawable_anchor - camera_origin) * tile_scale - Vector2(drawable_size.x * tile_scale * 0.5, drawable_size.y * tile_scale)
		draw_texture_rect(drawable_texture, Rect2(drawable_position, drawable_size * tile_scale), false)
	if foreground_texture != null:
		draw_texture_rect_region(foreground_texture, Rect2(destination_position, destination_size), Rect2(camera_origin, camera_world_size), Color.WHITE, false, true)
	var font: Font = ThemeDB.fallback_font
	draw_rect(Rect2(12, size.y - 42, minf(size.x - 24, 540), 30), Color(0.03, 0.04, 0.06, 0.85), true)
	draw_string(font, Vector2(24, size.y - 21), "WASD / arrows: move   •   ROM map: %s   •   %d, %d" % [map_id, player_position.x, player_position.y], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("d7e0eb"))

func _sort_drawables(left: Dictionary, right: Dictionary) -> bool:
	var left_y: float = float(left.get("sort_y", 0.0))
	var right_y: float = float(right.get("sort_y", 0.0))
	if not is_equal_approx(left_y, right_y):
		return left_y < right_y
	return int(left.get("sort_order", 0)) < int(right.get("sort_order", 0))

func _stair_offset(progress: float, behavior: int) -> Vector2:
	var frame: float = progress * 12.0
	var horizontal_sign: float = 1.0 if behavior == 0x6C or behavior == 0x6E else -1.0
	var horizontal: float = horizontal_sign * frame * 0.5
	var vertical: float = -frame * 0.3125 if behavior == 0x6C or behavior == 0x6D else maxf(frame - 6.0, 0.0) * 0.09375
	return Vector2(horizontal, vertical)
