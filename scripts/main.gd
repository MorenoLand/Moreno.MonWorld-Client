extends Node

var current_screen: Node

func _ready() -> void:
	_show_auth()

func _replace_screen(scene: PackedScene) -> Node:
	if is_instance_valid(current_screen):
		current_screen.queue_free()
	current_screen = scene.instantiate()
	add_child(current_screen)
	return current_screen

func _show_auth() -> void:
	var screen = _replace_screen(preload("res://scenes/auth.tscn"))
	screen.authenticated.connect(_show_character_selection)
	screen.local_preview_requested.connect(_show_local_preview)

func _show_character_selection() -> void:
	var screen = _replace_screen(preload("res://scenes/character_selection.tscn"))
	screen.character_selected.connect(_show_world)
	screen.logout_requested.connect(_show_auth)

func _show_world() -> void:
	var screen = _replace_screen(preload("res://scenes/world.tscn"))
	screen.battle_requested.connect(_show_battle)

func _show_battle() -> void:
	var screen = _replace_screen(preload("res://scenes/battle.tscn"))
	screen.exit_requested.connect(_show_world)

func _show_local_preview() -> void:
	if is_instance_valid(current_screen):
		current_screen.queue_free()
	var screen = preload("res://scenes/content_preview.tscn").instantiate()
	screen.content = GameState.content
	current_screen = screen
	add_child(current_screen)
	screen.exit_requested.connect(_show_auth)
