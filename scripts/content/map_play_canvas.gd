class_name MonWorldMapPlayCanvas
extends Control

signal location_changed(map_id: String, x: int, y: int)

var content: MonWorldContent
var map_id: String = ""
var map_texture: Texture2D
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
var movement_elapsed: float = 0.0
var movement_duration: float = 0.14
var pending_map_id: String = ""
var pending_position: Vector2i = Vector2i.ZERO
var pending_elevation: int = 3
var warp_cooldown: float = 0.0
var has_spawn: bool = false
var input_enabled: bool = false

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	focus_mode = Control.FOCUS_ALL
	queue_redraw()

func set_content(value: MonWorldContent) -> void:
	content = value
	player_texture = null
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

func set_map(texture: Texture2D, map_width: int, map_height: int, map_objects: Array, selected_map_id: String = "") -> void:
	var changed: bool = not selected_map_id.is_empty() and map_id != selected_map_id
	if not selected_map_id.is_empty():
		map_id = selected_map_id
	map_texture = texture
	map_pixel_size = Vector2(map_width * 16, map_height * 16)
	objects = map_objects
	if changed or not has_spawn:
		_set_spawn()
	_update_player_texture()
	queue_redraw()

func _apply_map(result: Dictionary, reset_spawn: bool) -> void:
	map_texture = result.get("texture") as Texture2D
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
	has_spawn = true
	movement_active = false
	warp_cooldown = 0.0

func _input(event: InputEvent) -> void:
	if not input_enabled or not visible or movement_active:
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var direction: int = _key_direction(event as InputEventKey)
	if direction == 0:
		return
	get_viewport().set_input_as_handled()
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
	var result: Dictionary = content.movement_result(map_id, player_position.x, player_position.y, direction, player_elevation, objects)
	if not bool(result.get("ok", false)):
		return
	pending_map_id = str(result.get("map_id", map_id))
	pending_position = Vector2i(int(result.get("x", player_position.x)), int(result.get("y", player_position.y)))
	pending_elevation = int(result.get("elevation", player_elevation))
	movement_start = Vector2(player_position)
	movement_target = Vector2(pending_position)
	movement_jump = bool(result.get("jump", false))
	movement_elapsed = 0.0
	movement_duration = 0.28 if movement_jump else 0.14
	movement_active = true
	queue_redraw()

func _process(delta: float) -> void:
	if warp_cooldown > 0.0:
		warp_cooldown = maxf(warp_cooldown - delta, 0.0)
	if not movement_active:
		return
	movement_elapsed += delta
	if movement_elapsed < movement_duration:
		queue_redraw()
		return
	movement_active = false
	player_position = pending_position
	player_elevation = pending_elevation
	if pending_map_id != map_id:
		_load_map(pending_map_id)
	else:
		_update_player_texture()
	var warp: Dictionary = content.warp_at(map_id, player_position.x, player_position.y, player_elevation)
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
	var sprite: Dictionary = content.render_object_sprite(19, animation_tick / 4)
	player_texture = sprite.get("texture") as Texture2D

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("080B10"), true)
	if map_texture == null or map_pixel_size.x <= 0.0 or map_pixel_size.y <= 0.0 or not has_spawn:
		return
	var tile_scale: float = minf(2.0, minf(size.x / (32.0 * 16.0), size.y / (18.0 * 16.0)))
	tile_scale = maxf(tile_scale, 1.0)
	var world_player: Vector2 = movement_start.lerp(movement_target, clampf(movement_elapsed / movement_duration, 0.0, 1.0)) if movement_active else Vector2(player_position)
	if movement_active and movement_jump:
		world_player.y -= sin(clampf(movement_elapsed / movement_duration, 0.0, 1.0) * PI) * 0.75
	var player_anchor: Vector2 = (world_player + Vector2(0.5, 1.0)) * 16.0
	var destination_size: Vector2 = map_pixel_size * tile_scale
	var destination_position: Vector2 = size * 0.5 - player_anchor * tile_scale
	draw_texture_rect(map_texture, Rect2(destination_position, destination_size), false)
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
		var object_anchor: Vector2 = Vector2((int(object.get("x", 0)) + 0.5) * 16.0, (int(object.get("y", 0)) + 1.0) * 16.0)
		var sprite_position: Vector2 = destination_position + object_anchor * tile_scale - Vector2(sprite_size.x * tile_scale * 0.5, sprite_size.y * tile_scale)
		draw_texture_rect(texture, Rect2(sprite_position, sprite_size * tile_scale), false)
	if player_texture != null:
		var player_size: Vector2 = Vector2(player_texture.get_width(), player_texture.get_height())
		var player_position_on_screen: Vector2 = destination_position + player_anchor * tile_scale - Vector2(player_size.x * tile_scale * 0.5, player_size.y * tile_scale)
		draw_texture_rect(player_texture, Rect2(player_position_on_screen, player_size * tile_scale), false)
	var font: Font = ThemeDB.fallback_font
	draw_rect(Rect2(12, size.y - 42, minf(size.x - 24, 540), 30), Color(0.03, 0.04, 0.06, 0.85), true)
	draw_string(font, Vector2(24, size.y - 21), "WASD / arrows: move   •   ROM map: %s   •   %d, %d" % [map_id, player_position.x, player_position.y], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("d7e0eb"))
