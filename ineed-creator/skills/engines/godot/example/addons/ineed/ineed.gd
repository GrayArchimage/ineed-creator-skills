extends Node
## Stable JSON-only bridge. Keep callback references alive for the node lifetime.
signal platform_event(name: String, data: Dictionary)
const PLUGIN_VERSION := "0.1.1"
var _bridge: JavaScriptObject
var _event_callback: JavaScriptObject
var _callbacks: Dictionary = {}
var _sequence := 0
var _capabilities: Array = []
var _initialized := false
var _combined_busy := false
var _unconfirmed_purchases: Dictionary = {}

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

## Explicitly authenticate before starting a purchase. Cancel/error never buys.
func ensure_logged_in() -> Dictionary:
	if not supports("account.get") or not supports("login"):
		return _error("UNSUPPORTED", "Initialize on a host with account and login support first")
	var account: Dictionary = await request("account.get")
	if not account.get("ok", false):
		return account
	if not (account.get("value") is Dictionary) or str(account.value.get("id", "")).is_empty():
		var signed_in: Dictionary = await login()
		if not signed_in.get("ok", false):
			return signed_in
		account = await request("account.get")
		if not account.get("ok", false):
			return account
		if not (account.get("value") is Dictionary) or str(account.value.get("id", "")).is_empty():
			return _error("AUTH_REQUIRED", "Login did not establish an account")
	return account

func buy(product_key: String) -> Dictionary:
	if not supports("payments.buy"):
		return _error("UNSUPPORTED", "Host does not support payments.buy")
	var account: Dictionary = await ensure_logged_in()
	if not account.get("ok", false):
		return account
	return await request("payments.buy", {"productKey": product_key})

## Call at the real use point. Persist request_id for the same action's retries.
func consume(product_key: String, quantity: int, request_id: String) -> Dictionary:
	if not supports("payments.consume"):
		return _error("UNSUPPORTED", "Host does not support payments.consume")
	var account: Dictionary = await ensure_logged_in()
	if not account.get("ok", false):
		return account
	return await request("payments.consume", {"productKey": product_key, "quantity": quantity, "requestId": request_id})

## Use stock first; only an explicit server inventory rejection may trigger one purchase.
## This is a workflow, not an atomic buy/consume transaction. Never auto-refund or retry buying.
func buy_and_consume(product_key: String, quantity: int, request_id: String) -> Dictionary:
	if _combined_busy:
		return _error("BUSY", "A combined purchase/use action is already in progress")
	for method in ["account.get", "login", "payments.products", "payments.buy", "payments.consume"]:
		if not supports(method):
			return _error("UNSUPPORTED", "Host does not support " + method)
	var pattern := RegEx.new()
	pattern.compile("^[A-Za-z0-9_-]{16,80}$")
	if product_key.is_empty() or quantity < 1 or quantity > 1000000 or pattern.search(request_id) == null:
		return _error("INVALID_PARAMS", "Use a valid product, positive quantity and stable 16–80 character requestId")
	_combined_busy = true
	var result: Dictionary = await _buy_and_consume(product_key, quantity, request_id)
	_combined_busy = false
	return result

func _buy_and_consume(product_key: String, quantity: int, request_id: String) -> Dictionary:
	var account: Dictionary = await ensure_logged_in()
	if not account.get("ok", false):
		return account
	var identity: String = str(account.value.get("id", ""))
	var params := {"productKey": product_key, "quantity": quantity, "requestId": request_id}
	var attempt_key := identity + ":" + request_id
	# Retry consume first: a lost success response must not trigger a second purchase.
	var used: Dictionary = await request("payments.consume", params)
	if used.get("ok", false):
		return {"ok": true, "value": {"purchase": null, "consumption": used.value, "usedExistingInventory": true}}
	if used.get("error", {}).get("code", "") != "INSUFFICIENT_INVENTORY":
		return used
	if _unconfirmed_purchases.has(attempt_key):
		var pending: Dictionary = _error("PURCHASE_UNCONFIRMED", "Verify the previous purchase before buying again")
		pending["context"] = {"stage": "purchase_unknown", "requestId": request_id}
		return pending
	var products: Dictionary = await request("payments.products")
	if not products.get("ok", false):
		return products
	var selected: Dictionary = {}
	for item in products.get("value", []):
		if item.get("productKey", "") == product_key:
			selected = item
			break
	if selected.get("type", "") != "consumable" or selected.get("systemManaged", false):
		return _error("INVALID_PARAMS", "Choose a configured consumable product")
	if int(selected.get("grantQuantity", 0)) < quantity:
		return _error("INVALID_PARAMS", "One purchase must cover this quantity; buy separately for larger batches")
	var current: Dictionary = await request("account.get")
	if not current.get("ok", false):
		return current
	if not (current.get("value") is Dictionary) or str(current.value.get("id", "")) != identity:
		return _error("ACCOUNT_CHANGED", "Account changed before purchase")
	var bought: Dictionary = await request("payments.buy", {"productKey": product_key})
	if not bought.get("ok", false):
		if bought.get("error", {}).get("code", "") not in ["CANCELLED", "INSUFFICIENT_BALANCE"]:
			_unconfirmed_purchases[attempt_key] = true
			bought["context"] = {"stage": "purchase_unknown", "requestId": request_id}
		return bought
	current = await request("account.get")
	if not current.get("ok", false) or not (current.get("value") is Dictionary) or str(current.value.get("id", "")) != identity:
		var changed: Dictionary = _error("ACCOUNT_CHANGED", "Verify purchase on the original account before continuing")
		changed["context"] = {"purchase": bought.value, "stage": "after_purchase", "requestId": request_id}
		return changed
	used = await request("payments.consume", params)
	if not used.get("ok", false):
		used["context"] = {"purchase": bought.value, "stage": "after_purchase", "requestId": request_id}
		return used
	return {"ok": true, "value": {"purchase": bought.value, "consumption": used.value, "usedExistingInventory": false}}

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
