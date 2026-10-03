# Godot 接口手册

适用插件 0.1.2、协议 v1（既有 request 方法仍兼容 0.1.0）；既有方法依据平台运行时 1.0.1；普通展示为能力协商扩展。最新方法是否可用以当前会话协商为准。[SDK 与源码](https://github.com/GrayArchimage/ineed-creator-skills/tree/main/ineed-creator/skills/engines/godot) · [冻结协议基线](../../protocol-v1.md)。本页为开发参考，不修改旧协议。

## 调用约定

先 `await INeed.initialize()`，检查 result.ok，再 `INeed.supports("完整方法名")`。所有异步方法返回 Dictionary；数据仅允许 JSON 类型，不传 Node、Resource、Callable、Vector2 或二进制对象。向量应由游戏明确转换为普通字段。

```gdscript
var result: Dictionary = await INeed.request("payments.inventory", {"productKey": "entry_ticket"})
if result.get("ok", false):
    var remaining := int(result.get("value", 0))
    print("当前会话剩余次数：", remaining)
else:
    var error: Dictionary = result.get("error", {})
    print(error.get("code", "REQUEST_FAILED"), ": ", error.get("message", ""))
```

成功外层是 `{ok:true,value:...}`；失败外层是 `{ok:false,error:{code,message}}`。某些底层业务返回自身的 ok 字段，仍放在 value 内。不得假定所有 value 都是数组或都有 data 字段。

## 插件简写

| GDScript | 对应桥接方法 | 说明 |
|---|---|---|
| initialize() | hello | 协商协议；返回 protocol/runtimeVersion/capabilities |
| supports(method) | 本地能力查询 | 仅初始化成功后有效，返回 bool |
| request(method, params = {}) | 指定方法 | 通用异步调用 |
| login() | login | 平台认证；返回会话数据 |
| buy(product_key) | payments.buy | 单个商品的可信确认与购买 |
| open_store() | ui.store | 平台商品列表，选购后返回购买结果 |
| open_leaderboard(board_key, scope = "world") | ui.leaderboard | 平台排行榜窗口 |
| show_rewarded(placement, action_id) | ads.rewarded | 真实广告与可信结算 |

插件 0.1.1 的包装器继续保留；旧 0.1.0 可使用 request 接口。

| GDScript | 行为 |
|---|---|
| ensure_logged_in() | 返回当前账号；游客先登录，失败就停止 |
| consume(product_key, quantity, request_id) | 确保登录，只消费，不购买 |
| buy_and_consume(product_key, quantity, request_id) | 确保登录，先消费已有库存，不足时购买一次再消费 |

buy 会先确保登录；账号取消或失败时不购买。组合的完整结果、部分成功和幂等恢复见[商品购买与消耗](../../skills/capabilities/payments/SKILL.md)。组合失败可能附加 context.purchase/stage/requestId，原 error 不被隐藏；它不是原子交易。stage=purchase_unknown 表示购买结果待核实，after_purchase 表示已取得购买成功回执。新包装器可返回 PURCHASE_UNCONFIRMED，阻止未知购买结果下再买；这不是新增的远程协议错误。

## 常用数据：插件 0.1.2 简写

初始化一次后，界面直接调用下面的方法，不需要自己构造桥接消息。它们保留 `{ok,value}` / `{ok:false,error}` 结果；读取失败不能伪装成空列表或零库存。

| GDScript | value / 行为 |
|---|---|
| get_account() | 账号对象或 null；不弹登录 |
| get_user_name(fallback = "玩家") | 昵称，空时用 username，再空用 fallback；不弹登录 |
| get_products() | 商品数组；价格来自平台 |
| get_inventory(product_key = "") | 全部库存数组，指定 key 则是数量 |
| get_entitlements() | 永久权益对象 |
| list_leaderboards() | 对象中的 boards 为可用榜单列表 |
| get_leaderboard(board_key, scope = "world", page = 1, page_size = 20) | 对象中的 entries 为排名列表，还有 personalBest/personalRank/total 等 |
| get_leaderboard_profile() | 对象中的 profile |
| submit_score(frozen_run, expected_account_id) | 需要时自动登录；账号与开局记录不符就停止；原样提交冻结成绩，成功读取 value.receipt |
| set_leaderboard_region(country_code, province_code, city_code = "") | 需要时登录，提交合法地区代码；不猜测用户位置 |

榜单只读方法先读取；仅服务器返回 AUTH_REQUIRED 时打开登录并重读一次。取消登录直接返回失败。提交、购买、消费没有自动重试；未知结果须核对，不能重复扣款或发奖励。旧平台缺少方法返回 UNSUPPORTED。

```gdscript
var ready := await INeed.initialize()
if not ready.get("ok", false): return
var name_result := await INeed.get_user_name()
if name_result.get("ok", false): name_label.text = name_result.value
var ranks := await INeed.get_leaderboard("实际已配置的榜单key")
if ranks.get("ok", false): render_rows(ranks.value.entries)
else: show_error(ranks.error)
```

昵称是显示文本，不能作为账号 ID 或 HTML 执行。动态昵称使用覆盖中文的字体，避免用静态文本子集字体。`account.changed` 后重读并使旧的异步结果失效；不要把上一账号列表显示给下一账号。

## 账号及购买数据

下表“返回”均指外层成功结果的 value。读取账号、商品、库存、权益的是当前 SDK 会话快照，不能作为服务端授权依据。

| 方法 | params | 返回与读取位置 |
|---|---|---|
| account.get | 空 | 账号对象或 null；id、nickname、avatarUrl、username、balanceCoins 等；字段为空须处理 |
| login | 空 | 会话对象，内含 account；推荐登录结束后重新 account.get |
| payments.products | 空 | 商品数组；productKey、name、description、priceCoins、type、grantQuantity；type 为 permanent/consumable；不要销售 systemManaged 项 |
| payments.inventory | 空 | `[{productKey,quantity}]`；无库存可能为空数组 |
| payments.inventory | productKey: String | 此商品数量 Number，没找到返回 0 |
| payments.entitlements | 空 | `{buyout,products:[{productKey,acquiredAt}]}`；不包含消耗品库存 |
| payments.buy | productKey: String | 购买结果，可能含 orderId、noCharge、fulfillment、session；最终 UI 从更新后的会话权益/库存读取 |
| payments.consume | productKey、quantity、requestId | consumptionId、noChange、productKey、quantity、remainingQuantity、session；noChange=true 表示相同操作重放 |
| ui.store | 空 | 选商品并购买；返回与 buy 相同业务结果；关闭可能为 CANCELLED |

consume 的 quantity 为正整数，服务端上限 1,000,000；requestId 为 16–80 位英文字母、数字、下划线或连字符。一个真实动作一个 ID，同动作重试完全相同，新动作用新 ID。buy 当前公开参数只有 productKey；不要传入自造 requestId 并声称购买已经跨刷新幂等。

## 排行榜数据与提交

| 方法 | params | 返回与读取位置 |
|---|---|---|
| leaderboards.list | 空 | `{ok,boards,profile}`；boards 为榜单配置数组 |
| leaderboards.get | boardKey；scope 默认 world；page 默认 1；可选 pageSize | `{ok,board,scope,region,entries,personalBest,personalRank,total,page,pageSize}` |
| leaderboards.submit | boardKey、runId、score、durationMs；可选 endedAt、stats | `{ok,receipt}`；receipt 含 runId、boardKey、score、previousBest、personalBest、isPersonalBest、deltaToBest、rank、submittedAt、replayed |
| leaderboards.profile | 空 | `{ok,profile}`，profile 为昵称、头像、地区及修改地区时间信息 |
| leaderboards.region | countryCode、provinceCode；可选 cityCode | `{ok,profile}`；提交平台认可的地区代码，不能把中文地区名当代码 |
| ui.leaderboard | boardKey；scope 默认 world | 点击返回通常 `{closed:true}`；其他关闭路径可能 CANCELLED |

scope 为 world/province/city。boards 项含 boardKey/title/sortOrder/minScore/maxScore/minDurationMs/maxDurationMs；entries 项含 rank/userId/nickname/avatarUrl/score/achievedAt/isMe。按返回的 pageSize 和 total 分页，不依赖私有上限。地区未知时提示选择或返回世界榜；不要自行定位用户精确位置。

runId 在真实开局时生成，结束后冻结 score、durationMs 及可选 ISO 8601 endedAt。stats 为数值或布尔值的对象；不要放玩家秘密或聊天全文。示例：

```gdscript
var frozen_run: Dictionary = {
    "boardKey": "survival_score",
    "runId": "run_" + Crypto.new().generate_random_bytes(16).hex_encode(),
    "score": 1200,
    "durationMs": 85000
}
# 上述数值只演示形状，正式游戏须用真实开局与结算值。
var result: Dictionary = await INeed.request("leaderboards.submit", frozen_run)
if result.get("ok", false):
    var receipt: Dictionary = result.get("value", {}).get("receipt", {})
    print(receipt.get("personalBest"))
# 网络重试复用 frozen_run；示例成绩禁止提交正式榜单。
```

## 普通展示广告

`ads.show` 接收 `{type: "banner" | "interstitial", placement, requestId, layout?}`；`ads.close` 接收 `{requestId}`。placement 为 1–64 位英文字母、数字或 `_.-`，requestId 为 1–128 位英文字母、数字或 `_:.-`。banner 必须有有效 JSON layout；Godot 的 Control 交给 helper 转换，不能直接传给 request。

Godot 另行 preload `hosted_display_ads.gd`，调用 `await Ads.show(type, placement, request_id, space = null, rotated_clockwise = false, keep_aspect = true)` / `await Ads.close(request_id)`；它不是 INeed Autoload 上新增的简写。Web 使用 `displayAds.show({...})` / `displayAds.close(requestId)`。安装、匹配示例、布局和错误码见[显式展示广告](display-ads.md)。

show 的正常结果 value 为 `{requestId,type,placement,status,shown,reason?}`；status 为 shown/closed/no_fill/cancelled/timeout/skipped。`ok=true` 只表示普通请求被处理，无填充或取消也可为正常结果；不能发奖、解锁商品或视为已支付。新宿主登记 placement + type 授权后仅由游戏显式调用，旧宿主返回 UNSUPPORTED。close 可在加载中调用；早于 show 到达时 value 可仅为 `{requestId,status:"closed",shown:false}`。同 ID 更新 banner 位置不会加载新素材。匹配不能等待广告填充，结束匹配必须 close。

## 激励广告

`ads.rewarded` params 为 `{placement,actionId}`。placement 为 1–64 位英文字母、数字、下划线或连字符；actionId 为 16–80 位同类字符。

成功 value 是 `{receiptId,actionId,placement,reward,replayed}`。reward 是平台为该广告位配置并在创建动作时固定的 JSON 对象，没有通用的 coins 或 quantity 必填字段；与平台约定后才能解释。replayed=true 仍是同一凭据，不能重复应用奖励。取消、无填充、超时均不得当成功。详见[广告 Skill](../../skills/capabilities/rewarded-ads/SKILL.md)。

## 存档

| 方法 | params | 返回 |
|---|---|---|
| storage.load | 空 | `{value,version,schemaVersion,scope}`；首次 value=null、version=0 |
| storage.save | value: JSON；baseVersion: 非负整数；schemaVersion 默认 1 | 至少 `{version,scope}`；不要依赖保存响应一定回传 value |

scope 为 guest/preview/account。schemaVersion 由游戏维护，平台不会自动转换玩法数据。当前运行时要求 schemaVersion 正整数且不超过 1,000,000。先 load 取得 version，再作为 baseVersion 保存；成功后更新本地版本。1 MiB 包含平台存储编码开销和既有数据，游戏内容应留余量，最终以服务器校验为准。

## 事件

`INeed.platform_event.connect(handler)`，handler 签名为 `(name: String, data: Dictionary)`。

| name | data | 游戏责任 |
|---|---|---|
| pause | reason 为触发弹窗的方法 | 保存先前暂停/音频状态，暂停游戏 |
| resume | reason | 恢复先前状态；不是交易成功通知 |
| account.changed | account 对象或 null | 使旧账号异步结果失效，清理显示缓存，重读新身份数据 |

当前没有 purchase.completed、inventory.changed 等通用 Godot 事件；以调用结果和会话读取驱动 UI。同一时间只允许一个平台模态调用，重复可能 BUSY。游戏生命周期处理代码见[界面建议](ui.md)。

## 错误处理与数据来源

常见代码及重试策略见[异常与恢复](recovery.md)。桥接不会返回任意 HTTP 响应头，所以不要假设每个结果都有 traceId。排错记录作品、环境、时间、账号标识、方法、业务 ID 和实际返回码；向平台申请查询交易/消费/奖励账本。不要记录 token、密码和完整私密存档。

本文依据公开插件及平台同版本实现整理；不要求创作者调用内部管理 API。API 扩展必须先由平台实现并公告，再按 supports 接入。
