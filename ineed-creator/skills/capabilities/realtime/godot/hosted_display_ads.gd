extends RefCounted
## Optional display-ad requests. No reward, purchase or matchmaking result is returned.

static func _post(message: Dictionary) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("parent.postMessage(" + JSON.stringify(message) + ", '*')", true)

static func matching_closed() -> void:
	_post({"type": "ineed:hosted-ad-event", "event": "match-waiting", "visible": false})

static func matching_waiting(space: Control, rotated_clockwise: bool = false, keep_aspect: bool = true) -> void:
	if not OS.has_feature("web") or not is_instance_valid(space):
		return
	var rect := space.get_global_rect()
	var viewport := space.get_viewport_rect().size
	if viewport.x <= 0 or viewport.y <= 0:
		matching_closed()
		return
	var values := {"x": rect.position.x, "y": rect.position.y, "width": rect.size.x, "height": rect.size.y,
		"viewportX": viewport.x, "viewportY": viewport.y, "rotated": rotated_clockwise, "keepAspect": keep_aspect}
	JavaScriptBridge.eval("""
(function (r) {
  var canvas = document.getElementById('canvas');
  if (!canvas) return;
  var box = canvas.getBoundingClientRect();
  var sx = (r.rotated ? box.height : box.width) / r.viewportX;
  var sy = (r.rotated ? box.width : box.height) / r.viewportY;
  var ox = 0, oy = 0;
  if (r.keepAspect) {
    var scale = Math.min(sx, sy);
    ox = ((r.rotated ? box.height : box.width) - r.viewportX * scale) / 2;
    oy = ((r.rotated ? box.width : box.height) - r.viewportY * scale) / 2;
    sx = scale; sy = scale;
  }
  parent.postMessage({type: 'ineed:hosted-ad-event', event: 'match-waiting', visible: true, layout: {
    x: (r.rotated ? box.top : box.left) + ox + r.x * sx,
    y: (r.rotated ? innerWidth - box.right : box.top) + oy + r.y * sy,
    width: r.width * sx, height: r.height * sy, viewportWidth: innerWidth, rotated: r.rotated
  }}, '*');
})(%s)
""" % JSON.stringify(values), true)

static func defeat(result_id: String) -> void:
	_post({"type": "ineed:hosted-ad-event", "event": "game-result", "state": "ended", "outcome": "defeat", "resultId": result_id})

static func playing() -> void:
	_post({"type": "ineed:hosted-ad-event", "event": "game-result", "state": "playing"})

static func dismissed() -> void:
	_post({"type": "ineed:hosted-ad-event", "event": "game-result", "state": "dismissed"})
