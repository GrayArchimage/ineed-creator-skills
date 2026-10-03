class_name INeedSignaling
extends Node
signal event(name: String, value: Dictionary)
var display_name := "玩家"
var code := ""
var peer_id := 0
var cursor := 0
var build := "realtime-demo-v1"
var _host: JavaScriptObject
var _account_listener: JavaScriptObject
var _callbacks: Array[JavaScriptObject] = []
var _busy := false
var _stopped := true
var _generation := 0
var _watch_generation := -1
var poll_interval := 0.5
var _logging_in := false

func _request(method: String, params: Dictionary = {}) -> Dictionary:
	if not OS.has_feature("web"):
		return {"ok": false, "error": {"code": "WEB_REQUIRED"}}
	# A plain local Web export has no platform host. Check before get_interface,
	# which logs a Godot error for absent JavaScript globals.
	if not JavaScriptBridge.eval("typeof INeedHost === 'object' && INeedHost !== null && typeof INeedHost.dispatch === 'function' && typeof INeedHost.subscribe === 'function' && typeof INeedHost.unsubscribe === 'function'", true):
		return {"ok": false, "error": {"code": "UNSUPPORTED"}}
	_host = JavaScriptBridge.get_interface("INeedHost")
	if _host == null:
		return {"ok": false, "error": {"code": "UNSUPPORTED"}}
	if _account_listener == null:
		_account_listener = JavaScriptBridge.create_callback(func(args):
			var incoming = JSON.parse_string(str(args[0]))
			if incoming is Dictionary and incoming.get("name") == "account.changed" and not _logging_in:
				event.emit("disconnected", {"code": "ACCOUNT_CHANGED"})
				leave())
		_host.subscribe(_account_listener)
	var pending := {"done": false, "result": {}}
	var callback := JavaScriptBridge.create_callback(func(args):
		pending.result = JSON.parse_string(str(args[0]))
		pending.done = true)
	_callbacks.append(callback)
	_host.dispatch(JSON.stringify({"protocol": 1, "method": method, "params": params}), callback)
	while not pending.done:
		await get_tree().process_frame
	_callbacks.erase(callback)
	return pending.result

func enter(mode: String, room_code: String = "") -> Dictionary:
	if _busy or not code.is_empty(): return {"ok": false, "error": {"code": "BUSY"}}
	_busy = true
	var generation := _generation
	var hello := await _request("hello", {"protocols": [1]})
	var capability := "multiplayer.join" if not room_code.is_empty() else ("multiplayer.match" if mode == "random" else "multiplayer.create")
	if not hello.get("ok", false) or not capability in hello.get("value", {}).get("capabilities", []):
		_busy = false
		return {"ok": false, "error": {"code": "UNSUPPORTED"}}
	var account := await _request("account.get")
	if not account.get("ok", false):
		_busy = false
		return account
	if account.get("value") == null:
		_logging_in = true
		var login := await _request("login")
		_logging_in = false
		if not login.get("ok", false):
			_busy = false
			return login
	if generation != _generation:
		_busy = false
		return {"ok": false, "error": {"code": "CANCELLED"}}
	account = await _request("account.get")
	if not account.get("ok", false) or not account.get("value") is Dictionary:
		_busy = false
		return {"ok": false, "error": {"code": "AUTH_REQUIRED"}}
	display_name = str(account.value.get("nickname", "玩家"))
	var action := "match" if mode == "random" else "create"
	var params := {"mode": mode, "build": build, "clientId": Crypto.new().generate_random_bytes(16).hex_encode()}
	if not room_code.is_empty():
		action = "join"
		params = {"code": room_code.strip_edges().to_upper(), "build": build, "clientId": params.clientId}
	var result := await _request("multiplayer." + action, params)
	_busy = false
	if generation != _generation:
		if result.get("ok", false): await _request("multiplayer.leave", {"code": result.value.code})
		return {"ok": false, "error": {"code": "CANCELLED"}}
	if result.get("ok", false):
		code = result.value.code
		peer_id = int(result.value.peerId)
		cursor = 0
		_stopped = false
		poll_interval = 0.5
	return result

func list_rooms() -> Dictionary:
	var hello := await _request("hello", {"protocols": [1]})
	if not hello.get("ok", false) or not "multiplayer.list" in hello.get("value", {}).get("capabilities", []):
		return {"ok": false, "error": {"code": "UNSUPPORTED"}}
	var account := await _request("account.get")
	if not account.get("ok", false):
		_busy = false
		return account
	if account.get("value") == null:
		_logging_in = true
		var login := await _request("login")
		_logging_in = false
		if not login.get("ok", false): return login
	return await _request("multiplayer.list")

func send_signal(kind: String, data: Variant) -> Dictionary:
	if _stopped: return {"ok": false, "error": {"code": "NO_ROOM"}}
	return await _request("multiplayer.signal", {"code": code, "kind": kind, "data": data, "requestId": Crypto.new().generate_random_bytes(16).hex_encode()})

func watch() -> void:
	if _watch_generation == _generation: return
	_watch_generation = _generation
	var generation := _generation
	var failures := 0
	while not _stopped and generation == _generation:
		var result := await _request("multiplayer.poll", {"code": code, "cursor": cursor})
		if _stopped or generation != _generation: break
		if result.get("ok", false):
			failures = 0
			cursor = int(result.value.cursor)
			event.emit("peers", result.value)
			for item in result.value.signals: event.emit("signal", item)
		else:
			failures += 1
			var reason: Dictionary = result.get("error", {})
			if reason.get("code", "") in ["ACCOUNT_CHANGED", "AUTH_REQUIRED", "UNAUTHENTICATED", "FORBIDDEN", "NOT_MEMBER"]:
				_stopped = true
				event.emit("disconnected", reason)
				break
			# Signaling is not the already-established RTC data connection. A room
			# lease or HTTP failure must not terminate a healthy ongoing fight.
			event.emit("signaling_unavailable", reason)
			if reason.get("code", "") in ["ROOM_CLOSED", "ROOM_NOT_FOUND"]:
				_stopped = true
				break
		await get_tree().create_timer(minf(8.0, poll_interval * pow(2, mini(failures, 5)))).timeout
	if _watch_generation == generation: _watch_generation = -1

func leave() -> void:
	_generation += 1
	_stopped = true
	var old_code := code
	code = ""
	if not old_code.is_empty(): await _request("multiplayer.leave", {"code": old_code})

func _exit_tree() -> void:
	_generation += 1
	_stopped = true
	if _host != null and _account_listener != null:
		_host.unsubscribe(_account_listener)
