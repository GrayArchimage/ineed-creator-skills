extends SceneTree
# Actual plugin workflows against an isolated in-memory service. No network or money.
class FakeHost extends "res://addons/ineed/ineed.gd":
    var account_id := "player_a"
    var stock := 0
    var buys := 0
    var logins := 0
    var consumes := 0
    var calls: Array[String] = []
    var receipts := {}
    var login_failure := false
    var payment_failure := false
    var purchase_timeout := false
    var lost_consume_response := false
    var fail_after_purchase := false
    var switch_after_purchase := false
    var unsupported := ""
    var grant := 1
    var product_type := "consumable"

    func supports(method: String) -> bool:
        return method != unsupported

    func request(method: String, params: Dictionary = {}) -> Dictionary:
        calls.append(method)
        if method == "account.get":
            return {"ok": true, "value": {"id": account_id} if not account_id.is_empty() else null}
        if method == "login":
            logins += 1
            if login_failure:
                return _error("CANCELLED", "Login cancelled")
            account_id = "player_a"
            return {"ok": true, "value": {"account": {"id": account_id}}}
        if method == "payments.products":
            return {"ok": true, "value": [{"productKey": "ticket", "type": product_type, "grantQuantity": grant}]}
        if method == "payments.buy":
            if purchase_timeout:
                return _error("TIMEOUT", "Purchase result unknown")
            if payment_failure:
                return _error("INSUFFICIENT_BALANCE", "No balance")
            buys += 1
            stock += grant
            if switch_after_purchase:
                account_id = "player_b"
            return {"ok": true, "value": {"orderId": "order_" + str(buys)}}
        if method == "payments.consume":
            var id: String = str(params.requestId)
            if receipts.has(id):
                var existing: Dictionary = receipts[id]
                if existing.productKey != params.productKey or existing.quantity != params.quantity:
                    return _error("CONSUME_FAILED", "Mismatched replay")
                var replay: Dictionary = existing.duplicate()
                replay["noChange"] = true
                return {"ok": true, "value": replay}
            if params.quantity < 1:
                return _error("INVALID_PARAMS", "quantity")
            if fail_after_purchase and buys > 0:
                return _error("TIMEOUT", "Pending verification")
            if stock < params.quantity:
                return _error("INSUFFICIENT_INVENTORY", "No inventory")
            stock -= params.quantity
            consumes += 1
            var receipt := {"consumptionId": "consume_" + str(consumes), "productKey": params.productKey, "quantity": params.quantity, "noChange": false, "remainingQuantity": stock}
            receipts[id] = receipt
            if lost_consume_response:
                lost_consume_response = false
                return _error("TIMEOUT", "Response lost after commit")
            return {"ok": true, "value": receipt}
        return _error("UNSUPPORTED", method)

var failures := 0
var checks := 0
var hosts: Array[Node] = []
func check(condition: bool, label: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        push_error(label)

func host() -> FakeHost:
    var value := FakeHost.new()
    hosts.append(value)
    return value

func _initialize() -> void:
    run.call_deferred()

func run() -> void:
    var h := host()
    h.account_id = ""
    var result: Dictionary = await h.buy("ticket")
    check(result.ok and h.logins == 1 and h.buys == 1 and h.stock == 1 and h.consumes == 0, "Guest buy logs in, buys only")
    check(h.calls.find("login") < h.calls.find("payments.buy"), "Authentication precedes purchase")
    h = host(); h.account_id = ""; h.login_failure = true
    result = await h.buy("ticket")
    check(not result.ok and h.buys == 0, "Cancelled login never buys")
    h = host(); h.stock = 2
    result = await h.consume("ticket", 1, "use_existing_0001")
    check(result.ok and h.stock == 1 and h.buys == 0, "Consume only uses stock")
    result = await h.consume("ticket", 1, "use_existing_0001")
    check(result.ok and result.value.noChange and h.stock == 1 and h.consumes == 1, "Consume replay does not double debit")
    h = host(); h.stock = 1
    result = await h.buy_and_consume("ticket", 1, "combined_use_0001")
    check(result.ok and h.buys == 0 and h.stock == 0, "Combined existing stock avoids purchase")
    h = host(); h.account_id = ""
    result = await h.buy_and_consume("ticket", 1, "combined_use_0002")
    check(result.ok and h.logins == 1 and h.buys == 1 and h.consumes == 1 and h.stock == 0, "Combined login, buy, consume")
    result = await h.buy_and_consume("ticket", 1, "combined_use_0002")
    check(result.ok and h.buys == 1 and h.consumes == 1, "Combined replay with zero stock never buys again")
    h = host(); h.payment_failure = true
    result = await h.buy_and_consume("ticket", 1, "combined_use_0003")
    check(not result.ok and h.buys == 0 and h.consumes == 0, "Insufficient balance never grants/consumes")
    h = host(); h.lost_consume_response = true
    result = await h.buy_and_consume("ticket", 1, "combined_lost_0004")
    check(not result.ok and result.context.stage == "after_purchase" and h.buys == 1 and h.consumes == 1, "Lost consumption response reports unknown outcome")
    result = await h.buy_and_consume("ticket", 1, "combined_lost_0004")
    check(result.ok and h.buys == 1 and h.consumes == 1, "Lost-response retry reuses original consumption")
    h = host(); h.fail_after_purchase = true
    result = await h.buy_and_consume("ticket", 1, "combined_fail_0005")
    check(not result.ok and result.context.purchase.orderId == "order_1" and h.stock == 1, "Purchase success, consume failure retains inventory and order")
    h.fail_after_purchase = false
    result = await h.buy_and_consume("ticket", 1, "combined_fail_0005")
    check(result.ok and h.buys == 1 and h.consumes == 1, "Partial workflow retry uses paid stock")
    h = host(); h.switch_after_purchase = true
    result = await h.buy_and_consume("ticket", 1, "combined_switch_06")
    check(not result.ok and result.error.code == "ACCOUNT_CHANGED" and h.consumes == 0, "Changed identity never consumes original purchase")
    h = host(); h.unsupported = "payments.consume"
    result = await h.buy_and_consume("ticket", 1, "combined_old_0007")
    check(not result.ok and h.calls.is_empty(), "Old host without consumption fails before login or purchase")
    h = host()
    result = await h.buy_and_consume("ticket", 1, "invalid")
    check(not result.ok and h.calls.is_empty(), "Invalid operation ID fails before mutation")
    result = await h.buy_and_consume("ticket", 2, "combined_batch_08")
    check(not result.ok and h.buys == 0, "No automatic multi-purchase")
    h = host(); h.product_type = "permanent"
    result = await h.buy_and_consume("ticket", 1, "combined_wrong_09")
    check(not result.ok and h.buys == 0, "Combined path rejects permanent product")
    h = host(); h._combined_busy = true
    result = await h.buy_and_consume("ticket", 1, "combined_busy_010")
    check(not result.ok and result.error.code == "BUSY" and h.calls.is_empty(), "Concurrent combined action rejected")
    h = host(); h.purchase_timeout = true
    result = await h.buy_and_consume("ticket", 1, "combined_pending11")
    check(not result.ok and result.context.stage == "purchase_unknown", "Unknown purchase result is not grant success")
    h.purchase_timeout = false
    result = await h.buy_and_consume("ticket", 1, "combined_pending11")
    check(not result.ok and result.error.code == "PURCHASE_UNCONFIRMED" and h.buys == 0, "Unknown prior purchase prevents duplicate purchase attempt")
    h.stock = 1
    result = await h.buy_and_consume("ticket", 1, "combined_pending11")
    check(result.ok and h.buys == 0, "Eventually delivered stock can still recover consumption")
    for item in hosts:
        item.free()
    print("Godot commerce: ", checks, " checks, ", failures, " failures (isolated fixture)")
    quit(1 if failures else 0)
