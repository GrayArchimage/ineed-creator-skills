# Engine protocol v1 (frozen baseline)

Plugin 0.1.0; runtime 1.0.0. JSON only. `INeedHost.dispatch(JSON.stringify({protocol:1,method,params}), callback)` calls callback once with JSON text. Web callers use `await INeedHost.request(method, params)`.

Hello: `hello {protocols:[1],pluginVersion:"0.1.0"}` returns `{ok:true,value:{protocol:1,runtimeVersion,capabilities:[method names]}}`. Query supports only after hello. Missing runtime/unknown method/unsupported protocol never reports success. Runtime is selected by platform work allowlist and fixed for that document's lifetime. Rollback changes the next session, not in-flight operations.

Every response: `{ok:true,value:<JSON>}` or `{ok:false,error:{code,message}}`. Unknown object fields are ignored; unknown capabilities aren't called. No arbitrary URL/HTTP/script execution method exists. Extension developers register method, validation, authorization and tests in platform code before advertising it.

| Method | Parameters / response value |
|---|---|
| login | `{}`; existing platform authenticated session |
| account.get | `{}`; account or null |
| payments.products | `{}`; configured product array |
| payments.inventory | optional productKey; inventory array or quantity |
| payments.entitlements | `{}`; server entitlements and inventory |
| payments.buy | productKey; trusted confirmation, existing order/session |
| payments.consume | productKey, positive integer quantity, stable requestId (16–80 alphanumeric/_/-); server inventory result |
| ui.store | `{}`; platform catalog → trusted confirmation → existing order/session |
| leaderboards.list | `{}`; boards/profile |
| leaderboards.get | boardKey, scope=world, page=1, pageSize; existing leaderboard response |
| leaderboards.submit | boardKey, immutable runId/score/durationMs, optional endedAt/stats; existing run receipt |
| leaderboards.profile | `{}`; cached account profile |
| leaderboards.region | countryCode, provinceCode, optional cityCode |
| ui.leaderboard | boardKey, scope=world; `{closed:true}` or cancellation |
| ads.rewarded | placement, stable actionId (16–80 chars); receiptId/actionId/placement/reward/replayed |
| storage.load | `{}`; value/version/schemaVersion/scope |
| storage.save | value/baseVersion/schemaVersion=1; new version/scope |

Events via subscribe(callback) are JSON text `{name,data}`; returned function unsubscribes. Modal call emits pause before opening, resume exactly once after outcome, preserving prior game/audio state in the game adapter. account.changed invalidates old requests before success delivery (login itself may change account).

Errors: UNSUPPORTED, PROTOCOL_UNSUPPORTED, INVALID_PARAMS, PROTOCOL_ERROR, AUTH_REQUIRED, ACCOUNT_CHANGED, BUSY, CANCELLED, TIMEOUT, REQUEST_FAILED, STORAGE_FORMAT, STORAGE_UNAVAILABLE, STORAGE_CONFLICT, STORAGE_TOO_LARGE, ACTION_CONFLICT, NO_FILL, EXPIRED, PROVIDER_ERROR, REWARD_FAILED. Existing commerce/leaderboard errors may also be forwarded. Never treat an unknown error as success. TIMEOUT on commerce means outcome unknown; refresh server state before retrying.

A reward receipt is a durable one-time settlement. Retrying returns the same receipt; game must deduplicate receiptId. It does not magically mutate arbitrary game currency. Server-side inventory remains authoritative for economic assets. Preview must not write live rewards/cloud saves.

Cloud saves share the platform's 1 MiB limit; engine content is a namespaced entry preserving old JS SDK keys. Guest and preview local slots are separate; no automatic guest/account merge. A storage conflict requires an explicit user/game decision.

Static matching runtime WASM/PCK stays inside the game ZIP. Platform business runtime updates are independent of those assets. New game events and game-native UI changes still require export. Never change these defaults or meanings without compatibility review in COMPATIBILITY.md.
