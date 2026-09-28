extends Control
var output: Label
var rows: VBoxContainer
var use_platform := true
var save_version := 0
var score := 0
var previous_pause := false
var previous_mute := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rows = VBoxContainer.new()
	rows.position = Vector2(20, 20)
	add_child(rows)
	output = Label.new()
	output.custom_minimum_size.x = 590
	output.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(output)
	var mode := CheckButton.new()
	mode.text = "Platform UI (off = game UI)"
	mode.button_pressed = true
	mode.toggled.connect(func(on: bool) -> void: use_platform = on)
	rows.add_child(mode)
	button("Login", func() -> void: show_result(await INeed.login()))
	button("Store", store)
	button("Leaderboard", leaderboard)
	button("Load", load_save)
	button("Add 1 point and save", save)
	INeed.platform_event.connect(func(name: String, _data: Dictionary) -> void:
		if name == "pause":
			previous_pause = get_tree().paused
			previous_mute = AudioServer.is_bus_mute(0)
			get_tree().paused = true
			AudioServer.set_bus_mute(0, true)
		elif name == "resume":
			get_tree().paused = previous_pause
			AudioServer.set_bus_mute(0, previous_mute)
		elif name == "account.changed":
			save_version = -1
	)
	show_result(await INeed.initialize())

func button(text: String, callback: Callable) -> void:
	var item := Button.new()
	item.text = text
	item.pressed.connect(callback)
	rows.add_child(item)

func show_result(result: Dictionary) -> void:
	output.text = JSON.stringify(result)

func store() -> void:
	if use_platform:
		show_result(await INeed.open_store())
	else:
		var result: Dictionary = await INeed.request("payments.products")
		show_result(result)
		if result.get("ok", false):
			for product in result.get("value", []):
				var key: String = product.get("productKey", "")
				button(str(product.get("name", key)), func() -> void: show_result(await INeed.buy(key)))

func leaderboard() -> void:
	var result: Dictionary = await INeed.request("leaderboards.list")
	show_result(result)
	if result.get("ok", false):
		for board in result.get("value", {}).get("boards", []):
			var key: String = board.get("boardKey", "")
			button(str(board.get("title", key)), func() -> void:
				show_result(await INeed.open_leaderboard(key) if use_platform else await INeed.request("leaderboards.get", {"boardKey": key}))
			)

func load_save() -> void:
	var result: Dictionary = await INeed.request("storage.load")
	show_result(result)
	if result.get("ok", false):
		var value: Dictionary = result.get("value", {})
		save_version = int(value.get("version", 0))
		score = int(value.get("value", {}).get("score", 0)) if value.get("value") is Dictionary else 0

func save() -> void:
	if save_version < 0:
		output.text = "Account changed. Load before saving."
		return
	var result: Dictionary = await INeed.request("storage.save", {"baseVersion": save_version, "value": {"score": score + 1}})
	show_result(result)
	if result.get("ok", false):
		save_version = int(result.get("value", {}).get("version", save_version))
		score += 1
