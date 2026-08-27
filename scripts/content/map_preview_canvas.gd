class_name MonWorldMapPreviewCanvas
extends Control

var map_texture: Texture2D
var map_pixel_size: Vector2 = Vector2.ZERO
var objects: Array = []

func set_map(texture: Texture2D, map_width: int, map_height: int, map_objects: Array) -> void:
	map_texture = texture
	map_pixel_size = Vector2(map_width * 16, map_height * 16)
	objects = map_objects
	queue_redraw()

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	if map_texture == null or map_pixel_size.x <= 0 or map_pixel_size.y <= 0:
		draw_rect(Rect2(Vector2.ZERO, size), Color("080B10"), true)
		return
	var scale: float = minf(size.x / map_pixel_size.x, size.y / map_pixel_size.y)
	if scale <= 0.0:
		return
	var destination_size: Vector2 = map_pixel_size * scale
	var destination: Rect2 = Rect2((size - destination_size) * 0.5, destination_size)
	draw_texture_rect(map_texture, destination, false)
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
		var map_position: Vector2 = Vector2((int(object.get("x", 0)) + 0.5) * 16.0, (int(object.get("y", 0)) + 1.0) * 16.0)
		var sprite_position: Vector2 = destination.position + map_position * scale - Vector2(sprite_size.x * scale * 0.5, sprite_size.y * scale)
		draw_texture_rect(texture, Rect2(sprite_position, sprite_size * scale), false)
