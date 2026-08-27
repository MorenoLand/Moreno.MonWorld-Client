class_name MonWorldAPI
extends Node

var base_url: String = "http://127.0.0.1:8081"

func configure(url: String) -> void:
	base_url = url.strip_edges().trim_suffix("/")

func request(path: String, method: int = HTTPClient.METHOD_GET, body: Dictionary = {}, access_token: String = "") -> Dictionary:
	var request_node := HTTPRequest.new()
	request_node.timeout = 10.0
	add_child(request_node)
	var headers := PackedStringArray(["Accept: application/json", "X-MonWorld-Client: godot"])
	if not access_token.is_empty():
		headers.append("Authorization: Bearer %s" % access_token)
	var body_text := ""
	if not body.is_empty():
		headers.append("Content-Type: application/json")
		body_text = JSON.stringify(body)
	var error := request_node.request(base_url + path, headers, method, body_text)
	if error != OK:
		request_node.queue_free()
		return {"ok": false, "status": 0, "error": "HTTP request could not start: %s" % error}
	var response: Array = await request_node.request_completed
	request_node.queue_free()
	var transport_result: int = int(response[0])
	var response_code: int = int(response[1])
	var response_body: PackedByteArray = response[3]
	var parsed: Variant = JSON.parse_string(response_body.get_string_from_utf8())
	if transport_result != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "status": response_code, "error": "Could not reach server (transport error %d)." % transport_result, "data": parsed}
	if response_code < 200 or response_code >= 300:
		var message := "Request failed (%d)" % response_code
		if parsed is Dictionary and parsed.has("error"):
			message = str(parsed.error)
		return {"ok": false, "status": response_code, "error": message, "data": parsed}
	return {"ok": true, "status": response_code, "data": parsed if parsed != null else {}}

func register(username: String, email: String, password: String) -> Dictionary:
	return await request("/api/v1/auth/register", HTTPClient.METHOD_POST, {"username": username, "email": email, "password": password})

func login(username: String, password: String) -> Dictionary:
	return await request("/api/v1/auth/login", HTTPClient.METHOD_POST, {"username": username, "password": password})

func refresh(refresh_token: String) -> Dictionary:
	return await request("/api/v1/auth/refresh", HTTPClient.METHOD_POST, {"refresh_token": refresh_token})

func logout(refresh_token: String) -> Dictionary:
	return await request("/api/v1/auth/logout", HTTPClient.METHOD_POST, {"refresh_token": refresh_token})

func get_content() -> Dictionary:
	return await request("/api/v1/content")

func get_me(access_token: String) -> Dictionary:
	return await request("/api/v1/me", HTTPClient.METHOD_GET, {}, access_token)

func patch_me(email: String, access_token: String) -> Dictionary:
	return await request("/api/v1/me", HTTPClient.METHOD_PATCH, {"email": email}, access_token)

func delete_me(password: String, access_token: String) -> Dictionary:
	return await request("/api/v1/me", HTTPClient.METHOD_DELETE, {"password": password}, access_token)

func cancel_deletion(access_token: String) -> Dictionary:
	return await request("/api/v1/me/deletion/cancel", HTTPClient.METHOD_POST, {}, access_token)

func list_characters(access_token: String) -> Dictionary:
	return await request("/api/v1/characters", HTTPClient.METHOD_GET, {}, access_token)

func create_character(name: String, access_token: String) -> Dictionary:
	return await request("/api/v1/characters", HTTPClient.METHOD_POST, {"name": name}, access_token)

func create_game_session(access_token: String) -> Dictionary:
	return await request("/api/v1/game/session", HTTPClient.METHOD_POST, {}, access_token)
