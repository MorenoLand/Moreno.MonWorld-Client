extends SceneTree

const SESSION_SCRIPT: GDScript = preload("res://scripts/net/session.gd")

var session: Node

func _init() -> void:
	var key_path: String = OS.get_environment("OPENMMOGO_ROOT_PUBLIC_KEY")
	if key_path.is_empty() or not FileAccess.file_exists(key_path):
		push_error("Set OPENMMOGO_ROOT_PUBLIC_KEY to the OpenMMO game.public.pem path")
		quit(1)
		return
	session = SESSION_SCRIPT.new()
	get_root().add_child(session)
	session.established.connect(_on_established)
	session.failed.connect(_on_failed)
	var host: String = OS.get_environment("OPENMMOGO_LOGIN_HOST")
	if host.is_empty():
		host = "127.0.0.1"
	var port: int = int(OS.get_environment("OPENMMOGO_LOGIN_PORT"))
	if port <= 0:
		port = 2106
	var timeout: SceneTreeTimer = create_timer(15.0)
	timeout.timeout.connect(_on_timeout)
	var error: Error = session.connect_openmmo(host, port, key_path)
	if error != OK:
		_on_failed("OpenMMO handshake could not start: %s" % error_string(error))

func _on_established() -> void:
	print("OpenMMO live handshake established")
	session.close()
	quit(0)

func _on_failed(message: String) -> void:
	push_error(message)
	quit(1)

func _on_timeout() -> void:
	if session != null:
		session.close()
	push_error("OpenMMO live handshake timed out")
	quit(1)
