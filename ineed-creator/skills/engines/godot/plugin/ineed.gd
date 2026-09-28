extends Node
## Stable JSON-only bridge. Keep callback references alive for the node lifetime.
signal platform_event(name: String, data: Dictionary)
const PLUGIN_VERSION := "0.1.0"
var _bridge: JavaScriptObject
var _event_callback: JavaScriptObject
var _callbacks: Dictionary = {}
var _sequence := 0
var _capabilities: Array = []
var _initialized := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func initialize() -> Dictionary:
	if not OS.has_feature("web"):
		return _error("UNSUPPORTED", "iNeed requires a hosted Web export")
	_bridge = JavaScriptBridge.get_interface("INeedHost")
	if _bridge == null:
		return _error("UNSUPPORTED", "This host does not provide the iNeed engine runtime")
	if _event_callback == null:
		_event_callback = JavaScriptBridge.create_callback(_on_event)
		_bridge.subscribe(_event_callback)
	var result: Dictionary = await request("hello", {"protocols": [1], "pluginVersion": PLUGIN_VERSION})
	if result.get("ok", false):
		_capabilities = result.get("value", {}).get("capabilities", [])
		_initialized = true
	return result

func supports(capability: String) -> bool:
	return _initialized and capability in _capabilities

func request(method: String, params: Dictionary = {}) -> Dictionary:
	if _bridge == null:
		return _error("UNSUPPORTED", "Call initialize on a supported Web host first")
	_sequence += 1
	var id := _sequence
	var state := {"done": false, "result": {}}
	var callback := JavaScriptBridge.create_callback(func(args: Array) -> void:
		if state.done:
			return
		var value: Variant = JSON.parse_string(str(args[0])) if not args.is_empty() else null
		state.result = value if value is Dictionary else _error("PROTOCOL_ERROR", "Invalid JSON response")
		state.done = true
	)
	_callbacks[id] = callback
	_bridge.dispatch(JSON.stringify({"protocol": 1, "method": method, "params": params}), callback)
	var deadline := Time.get_ticks_msec() + (1860000 if method in ["payments.buy", "ui.store", "ads.rewarded"] else 310000)
	while not state.done and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_callbacks.erase(id)
	return state.result if state.done else _error("TIMEOUT", "Platform request timed out; verify status before retrying")

func login() -> Dictionary:
	return await request("login")

func buy(product_key: String) -> Dictionary:
	return await request("payments.buy", {"productKey": product_key})

func open_store() -> Dictionary:
	return await request("ui.store")

func open_leaderboard(board_key: String, scope: String = "world") -> Dictionary:
	return await request("ui.leaderboard", {"boardKey": board_key, "scope": scope})

func show_rewarded(placement: String, action_id: String) -> Dictionary:
	return await request("ads.rewarded", {"placement": placement, "actionId": action_id})

func _on_event(args: Array) -> void:
	if args.is_empty():
		return
	var event: Variant = JSON.parse_string(str(args[0]))
	if event is Dictionary:
		platform_event.emit(str(event.get("name", "")), event.get("data", {}))

func _exit_tree() -> void:
	if _bridge != null and _event_callback != null:
		_bridge.unsubscribe(_event_callback)

func _error(code: String, message: String) -> Dictionary:
	return {"ok": false, "error": {"code": code, "message": message}}
