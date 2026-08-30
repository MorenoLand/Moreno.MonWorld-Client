extends Node

const BATTLE_SCRIPT: GDScript = preload("res://scripts/battle/battle.gd")

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var previous_state: Dictionary = GameState.battle_state.duplicate(true)
	var initial: Dictionary = _state(20, 20)
	GameState.battle_state = initial.duplicate(true)
	var battle: Control = BATTLE_SCRIPT.new()
	get_tree().root.add_child(battle)
	if not bool(battle.call("_is_attacker_motion_move", 39, {"name": "TAILWHIP"})):
		_fail(battle, previous_state, "Tail Whip was not classified as attacker-only motion")
		return
	var player_hit: Dictionary = {"type": "move_event", "event": {"source_entity": -10, "source_move": 33, "targets": [{"entity_id": -20, "events": [{"current_hp": 14}]}]}, "state": _state(20, 14)}
	var opponent_hit: Dictionary = {"type": "move_event", "event": {"source_entity": -20, "source_move": 33, "targets": [{"entity_id": -10, "events": [{"current_hp": 15}]}]}, "state": _state(15, 14)}
	battle.call("_on_battle_event", player_hit)
	battle.call("_on_battle_event", opponent_hit)
	if not bool(battle.get("battle_event_busy")) or (battle.get("battle_event_queue") as Array).size() != 1:
		_fail(battle, previous_state, "back-to-back battle moves were not queued")
		return
	var pre_hit_state: Dictionary = battle.get("state") as Dictionary
	if int((pre_hit_state.get("opponent_party", []) as Array)[0].get("current_hp", -1)) != 20:
		_fail(battle, previous_state, "target HP was applied before the attack hit")
		return
	await get_tree().create_timer(0.7).timeout
	var first_hit_state: Dictionary = battle.get("state") as Dictionary
	var first_hit_player_bar: ProgressBar = battle.get("player_hp_bar") as ProgressBar
	var first_hit_opponent_bar: ProgressBar = battle.get("opponent_hp_bar") as ProgressBar
	if int((first_hit_state.get("opponent_party", []) as Array)[0].get("current_hp", -1)) != 14 or int((first_hit_state.get("player_party", []) as Array)[0].get("current_hp", -1)) != 20:
		_fail(battle, previous_state, "the first hit did not apply only its own target HP")
		return
	if not bool(battle.get("battle_event_busy")) or (battle.get("battle_event_queue") as Array).size() != 1:
		_fail(battle, previous_state, "the counterattack started before the first move completed")
		return
	if first_hit_opponent_bar.value >= 20.0 or not is_equal_approx(first_hit_player_bar.value, 20.0):
		_fail(battle, previous_state, "the first hit did not begin the correct HP-bar drain")
		return
	await get_tree().create_timer(2.5).timeout
	var rendered_state: Dictionary = battle.get("state") as Dictionary
	var player_bar: ProgressBar = battle.get("player_hp_bar") as ProgressBar
	var opponent_bar: ProgressBar = battle.get("opponent_hp_bar") as ProgressBar
	if bool(battle.get("battle_event_busy")) or not (battle.get("battle_event_queue") as Array).is_empty():
		_fail(battle, previous_state, "battle move queue did not drain")
		return
	if int((rendered_state.get("player_party", []) as Array)[0].get("current_hp", -1)) != 15 or int((rendered_state.get("opponent_party", []) as Array)[0].get("current_hp", -1)) != 14:
		_fail(battle, previous_state, "battle move states were not presented in order")
		return
	if not is_equal_approx(player_bar.value, 15.0) or not is_equal_approx(opponent_bar.value, 14.0):
		_fail(battle, previous_state, "battle HP bars did not animate to server HP")
		return
	battle.queue_free()
	GameState.battle_state = previous_state
	get_tree().quit(0)

func _state(player_hp: int, opponent_hp: int) -> Dictionary:
	return {"player_name": "Player", "active_slot": 0, "opponent_active_slot": 0, "player_party": [{"slot": 0, "entity_id": -10, "name": "PLAYERMON", "species": 4, "level": 5, "current_hp": player_hp, "max_hp": 20}], "opponent_party": [{"slot": 0, "entity_id": -20, "name": "FOEMON", "species": 16, "level": 4, "current_hp": opponent_hp, "max_hp": 20}], "can_act": false}

func _fail(battle: Control, previous_state: Dictionary, message: String) -> void:
	push_error(message)
	battle.queue_free()
	GameState.battle_state = previous_state
	get_tree().quit(1)
