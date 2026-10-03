class_name INeedConnection
extends Node
signal status(message: String)
signal connected(peer: MultiplayerPeer)
signal game_ready(is_host: bool)
signal disconnected
var signaling: INeedSignaling
var rtc: WebRTCPeerConnection
var peer: WebRTCMultiplayerPeer
var _started := false
var _remote_set := false
var _ice: Array[Dictionary] = []
var _signals: Array[Dictionary] = []
var _sending := false
var _generation := 0
var _negotiating := false
var _entering := false
var _game_api: MultiplayerAPI
var _game_ready_emitted := false
var display_name: String:
	get: return signaling.display_name if signaling else ""

## Existing start/connected stay available for custom integrations.
## This helper owns only the peer it installs on this MultiplayerAPI.
func start_game(api: MultiplayerAPI, build: String, mode: String = "random", code: String = "") -> Dictionary:
	if api == null or _game_api != null or peer or _entering:
		return {"ok": false, "error": {"code": "BUSY"}}
	if api.multiplayer_peer != null and not api.multiplayer_peer is OfflineMultiplayerPeer:
		return {"ok": false, "error": {"code": "BUSY", "message": "Another multiplayer session is active"}}
	_game_api = api
	_game_ready_emitted = false
	api.connected_to_server.connect(_notify_game_ready)
	api.peer_connected.connect(_game_peer_connected)
	api.connection_failed.connect(_game_connection_failed)
	var result := await start(mode, build, code)
	if not result.get("ok", false):
		_release_game_api()
		return result
	api.multiplayer_peer = peer
	return result

func is_host() -> bool:
	return signaling != null and signaling.peer_id == 1

func _game_peer_connected(_id: int) -> void:
	if is_host(): _notify_game_ready()

func _notify_game_ready() -> void:
	# MultiplayerAPI must finish its handshake before the game sends RPCs.
	if _game_api == null or _game_ready_emitted: return
	_game_ready_emitted = true
	_emit_game_ready.call_deferred(_generation)

func _emit_game_ready(generation: int) -> void:
	if generation == _generation and _game_api != null and peer:
		game_ready.emit(is_host())

func _game_connection_failed() -> void:
	_fail("连接失败，请重新匹配")

func _release_game_api() -> void:
	if _game_api == null: return
	if _game_api.connected_to_server.is_connected(_notify_game_ready): _game_api.connected_to_server.disconnect(_notify_game_ready)
	if _game_api.peer_connected.is_connected(_game_peer_connected): _game_api.peer_connected.disconnect(_game_peer_connected)
	if _game_api.connection_failed.is_connected(_game_connection_failed): _game_api.connection_failed.disconnect(_game_connection_failed)
	if peer != null and _game_api.multiplayer_peer == peer:
		_game_api.multiplayer_peer = OfflineMultiplayerPeer.new()
	_game_api = null
	_game_ready_emitted = false

func _ready() -> void:
	signaling = INeedSignaling.new()
	add_child(signaling)
	signaling.event.connect(_event)

func start(mode: String, build: String, code: String = "") -> Dictionary:
	if _entering or peer: return {"ok": false, "error": {"code": "BUSY"}}
	_entering = true
	_generation += 1
	var generation := _generation
	signaling.build = build
	var result := await signaling.enter(mode, code)
	_entering = false
	if generation != _generation: return {"ok": false, "error": {"code": "CANCELLED"}}
	if not result.get("ok", false):
		status.emit(str(result.get("error", {})))
		return result
	_negotiating = false
	_started = false
	_remote_set = false
	_ice.clear()
	rtc = WebRTCPeerConnection.new()
	var error := rtc.initialize({"iceServers": result.value.iceServers, "iceTransportPolicy": "relay"})
	if error != OK:
		await leave()
		return {"ok": false, "error": {"code": "RTC_UNAVAILABLE"}}
	peer = WebRTCMultiplayerPeer.new()
	if signaling.peer_id == 1: error = peer.create_server()
	else: error = peer.create_client(signaling.peer_id)
	# add_peer creates the negotiated Godot RPC channels before an offer.
	if error == OK: error = peer.add_peer(rtc, 2 if signaling.peer_id == 1 else 1, 100 if _game_api != null else 500)
	if error != OK:
		await leave()
		return {"ok": false, "error": {"code": "RTC_UNAVAILABLE"}}
	rtc.session_description_created.connect(_description)
	rtc.ice_candidate_created.connect(func(mid, index, candidate): _enqueue("ice", {"sdpMid": mid, "sdpMLineIndex": index, "candidate": candidate}))
	peer.peer_connected.connect(func(_id): status.emit("已连接"); signaling.poll_interval = 5.0; connected.emit(peer))
	peer.peer_disconnected.connect(func(_id): _fail("连接已断开"))
	status.emit("正在匹配…" if mode == "random" else "等待玩家 · " + signaling.code)
	signaling.watch()
	return result

func _process(_delta: float) -> void:
	if peer: peer.poll()

func _event(name: String, value: Dictionary) -> void:
	if not rtc: return
	if name == "peers" and value.peers.size() == 2 and not _negotiating:
		_negotiating = true
		_connection_deadline(_generation)
	if name == "signaling_unavailable":
		if rtc.get_connection_state() != WebRTCPeerConnection.STATE_CONNECTED:
			if value.get("code", "") in ["ROOM_CLOSED", "ROOM_NOT_FOUND"]:
				_fail("匹配已结束，请重试")
			else:
				status.emit("连接不稳")
		return
	if name == "disconnected":
		_fail("连接已断开")
	elif name == "peers" and value.peers.size() == 2 and signaling.peer_id == 1 and not _started:
		_started = true
		if rtc.create_offer() != OK: _fail("连接协商失败")
	elif name == "signal":
		if value.kind == "ice":
			if not _remote_set: _ice.append(value.data)
			else: _add_ice(value.data)
		else:
			var error := rtc.set_remote_description(value.kind, value.data)
			if error != OK:
				_fail("连接协商失败")
				return
			_remote_set = true
			for item in _ice: _add_ice(item)
			_ice.clear()

func _add_ice(item: Dictionary) -> void:
	rtc.add_ice_candidate(item.sdpMid, int(item.sdpMLineIndex), item.candidate)

func _description(kind: String, sdp: String) -> void:
	if not rtc: return
	if rtc.set_local_description(kind, sdp) == OK: _enqueue(kind, sdp)
	else: _fail("连接协商失败")

func _enqueue(kind: String, data: Variant) -> void:
	_signals.append({"kind": kind, "data": data})
	if _sending: return
	_sending = true
	var generation := _generation
	while generation == _generation and not _signals.is_empty() and rtc:
		var item: Dictionary = _signals.pop_front()
		var result := await signaling.send_signal(item.kind, item.data)
		if generation != _generation: return
		if not result.get("ok", false):
			_fail("连接协商中断，请重新匹配")
			break
	_sending = false

func leave() -> void:
	_generation += 1
	_release_game_api()
	_signals.clear()
	_sending = false
	if peer: peer.close()
	peer = null
	if rtc: rtc.close()
	rtc = null
	await signaling.leave()

func _fail(message: String) -> void:
	status.emit(message)
	leave()
	disconnected.emit()

func _connection_deadline(generation: int) -> void:
	await get_tree().create_timer(30.0).timeout
	if generation != _generation or not rtc: return
	if rtc.get_connection_state() != WebRTCPeerConnection.STATE_CONNECTED:
		_fail("连接超时，请重新匹配")
