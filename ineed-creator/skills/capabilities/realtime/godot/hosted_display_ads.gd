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

## Explicit ordinary ads (host capability ads.show/ads.close). No reward is granted.
## Use one request_id per desired display; reuse it only to update the same banner geometry.
static func show(ad_type: String, placement: String, request_id: String, space: Control = null, rotated_clockwise: bool = false, keep_aspect: bool = true) -> Dictionary:
	var params := {"type": ad_type, "placement": placement, "requestId": request_id}
	if ad_type == "banner":
		if not is_instance_valid(space):
			return {"ok": false, "error": {"code": "INVALID_PARAMS", "message": "Banner requires a Control"}}
		params["layout"] = _layout(space, rotated_clockwise, keep_aspect)
	return await _request("ads.show", params)

static func close(request_id: String) -> Dictionary:
	return await _request("ads.close", {"requestId": request_id})

static func _request(method: String, params: Dictionary) -> Dictionary:
	if not OS.has_feature("web") or not JavaScriptBridge.eval("typeof window.INeedHost !== 'undefined'", true):
		return {"ok": false, "error": {"code": "UNSUPPORTED", "message": "Display ads require a supported platform host"}}
	var tree := Engine.get_main_loop() as SceneTree
	var sdk := tree.root.get_node_or_null("INeed")
	if sdk == null:
		return {"ok": false, "error": {"code": "UNSUPPORTED", "message": "Install the INeed autoload"}}
	if not sdk.supports(method):
		var initialized: Dictionary = await sdk.initialize()
		if not initialized.get("ok", false):
			return initialized
	if not sdk.supports(method):
		return {"ok": false, "error": {"code": "UNSUPPORTED", "message": "This host has not enabled display ads"}}
	return await sdk.request(method, params)

static func _layout(space: Control, rotated_clockwise: bool, keep_aspect: bool) -> Dictionary:
	if not OS.has_feature("web"):
		return {}
	var rect := space.get_global_rect()
	var viewport := space.get_viewport_rect().size
	if viewport.x <= 0 or viewport.y <= 0:
		return {}
	var values := {"x": rect.position.x, "y": rect.position.y, "width": rect.size.x, "height": rect.size.y,
		"viewportX": viewport.x, "viewportY": viewport.y, "rotated": rotated_clockwise, "keepAspect": keep_aspect}
	var raw: Variant = JavaScriptBridge.eval("""
(function(r) {
  var canvas=document.getElementById('canvas'); if(!canvas)return '{}';
  var box=canvas.getBoundingClientRect(),w=r.rotated?box.height:box.width,h=r.rotated?box.width:box.height;
  var sx=w/r.viewportX,sy=h/r.viewportY,ox=0,oy=0;
  if(r.keepAspect){var scale=Math.min(sx,sy);ox=(w-r.viewportX*scale)/2;oy=(h-r.viewportY*scale)/2;sx=scale;sy=scale;}
  return JSON.stringify({x:(r.rotated?box.top:box.left)+ox+r.x*sx,y:(r.rotated?innerWidth-box.right:box.top)+oy+r.y*sy,
    width:r.width*sx,height:r.height*sy,viewportWidth:innerWidth,rotated:r.rotated});
})(%s)
""" % JSON.stringify(values), true)
	var parsed: Variant = JSON.parse_string(str(raw))
	return parsed if parsed is Dictionary else {}
