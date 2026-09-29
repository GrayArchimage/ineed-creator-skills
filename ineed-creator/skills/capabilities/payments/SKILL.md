---
name: ineed-payments
description: 为游戏接入服务端商品、永久权益与消耗品，区分购买和使用，支持按需登录、组合调用和幂等恢复。
---
# 商品购买与消耗

先读[Godot 接入](../../engines/godot/SKILL.md)及[接口手册](../../../guides/integration/api.md)。本页同时定义创作者需求与游戏接线规则；价格、库存、权益由平台服务端决定。示例标识只演示格式，不能当成已配置商品。

## 先确认商品和入口

每个商品记录名称、productKey、I币价格、类型（permanent/consumable）、发放数量、购买入口及使用时机。可选描述和广告替代需求单独记录。AI 不替创作者定价；从代码发现的按钮名称与位置应直接填写，不让用户猜。

永久商品购买后持续拥有，无需 consume。消耗品购买增加服务端库存，真实使用时消耗。比如选中角色只是准备，若创作者定义“开局扣 1 次”，选角色、切换页面、刷新都不能消耗。

## 三种调用方式

插件 0.1.1 新增 consume、buy_and_consume、ensure_logged_in。旧插件继续使用相同 v1 request 方法；不要将本页新包装器用于 0.1.0 插件。

| 需求 | GDScript | 成功含义 |
|---|---|---|
| 只购买 | `await INeed.buy(product_key)` | 平台购买流程成功；消耗品入库，尚未使用 |
| 只消耗 | `await INeed.consume(product_key, quantity, request_id)` | 服务端扣减成功或返回同动作既有回执 |
| 立即使用，不足时购买 | `await INeed.buy_and_consume(product_key, quantity, request_id)` | 先尝试使用库存；不足时购买一次再消耗，只有消耗成功整体才成功 |

**未登录点击购买会先触发登录。** 登录取消、失败或没有建立账号时，不发起购买。用户完成登录后继续原动作，不要求再次点击商品。只消耗和组合调用也会先确保登录。微信/QQ 可能采用当前页跳转；跳转前游戏须保存待继续的非敏感意图，返回后先读账号和库存，不能盲目再次购买。

组合调用专用于消耗品。已有库存或同一消费 requestId 的成功回执时，不会再购买。仅服务端明确返回 INSUFFICIENT_INVENTORY 才能进入购买；超时、其他失败和旧平台没有该错误码时停止，不猜测缺库存。一次购买的 grantQuantity 必须能覆盖请求 quantity；大批量请使用分开的购买和消耗，不自动连续扣款。

## 两步与组合的返回结构

buy 与 consume 保留外层 `{ok,value}` / `{ok:false,error}`，具体 value 见[接口手册](../../../guides/integration/api.md)。组合成功：

```json
{"ok":true,"value":{"purchase":null,"consumption":{"consumptionId":"...","noChange":false,"remainingQuantity":2},"usedExistingInventory":true}}
```

purchase=null 表示此次调用没有新购买；可能直接用了已有库存，也可能重放了此前消费回执。新购买后为购买回执对象；consumption 为消费结果。

组合不是原子事务：购买可能成功而消费失败。此时整体 ok=false，并在 `context` 中附带 `{stage:"after_purchase",purchase,requestId}`。商品保留在服务端库存（消费结果未知时先核实），不要自动退款，也不能显示“已使用”。重试同一 requestId，先恢复消费结果，不能换 ID 再买一遍。

## 游戏自绘商店

1. 初始化及身份就绪后读取 payments.products；展示平台 name、description、priceCoins、type、grantQuantity，不硬编码价格。
2. 读取 payments.entitlements 标记永久拥有；payments.inventory 显示消耗品数量，隐藏 systemManaged 项的普通购买按钮。
3. 玩家点购买时禁用该动作按钮并显示“正在登录/确认购买/等待到账”；实际认证和扣费确认由平台完成。
4. 只在 ok=true 后读取更新后的会话库存/权益更新 UI；余额不足、取消和未知结果不解锁付费动作。
5. 弹窗关闭的 resume 事件只恢复暂停状态，不能当购买成功事件。

## 平台商店

先 ensure_logged_in，再 open_store。平台负责列出商品与确认购买；游戏仍负责到账显示及真实使用入口。平台商店不会替你绑定开局、消耗或玩法发放。

## 可复制调用示例

以下函数放在游戏已有适配节点中。request_id 由游戏在一次使用意图创建时生成并持久化；不要在每次重试时重新生成。此示例返回结果，接入者将成功分支绑定到真实玩法，不包含自动开局。

```gdscript
func buy_for_later(product_key: String) -> Dictionary:
    return await INeed.buy(product_key)

func use_owned_item(product_key: String, request_id: String) -> Dictionary:
    return await INeed.consume(product_key, 1, request_id)

func buy_if_needed_and_use(product_key: String, request_id: String) -> Dictionary:
    return await INeed.buy_and_consume(product_key, 1, request_id)
```

生成 ID 示例 `"use_" + Crypto.new().generate_random_bytes(16).hex_encode()`。保存账号 ID、作品、productKey、quantity、requestId 和该次游戏动作；这些是恢复线索，不是客户端权益证明。先验证场景和资源可进入，再发起 consume；成功后以 consumptionId 去重并恢复同一动作。SDK 不会自动保存游戏进度，也不保证“扣减后浏览器崩溃”的玩法恢复，必须实现恢复点；没有服务器玩法服务时不能声称完整事务原子性。

## 数据新鲜度和重试

商品、余额、权益与库存是当前会话快照；不能凭缓存余额判断是否允许游戏。每次真正购买/消耗由服务端授权，购买/消耗结果更新会话。跨设备改变需要新会话或平台核实；Godot v1 没有公开订单查询或账户刷新方法。

只购买超时：停止自动重买，核对库存/权益和平台订单。组合中的购买结果未知会附加 context.stage=purchase_unknown；本次插件会话内再次缺库存时返回 PURCHASE_UNCONFIRMED，避免重复购买。游戏应持久化这个待核实状态，刷新后仍不得自行重买；该标记仅用于恢复，不是权益凭据。组合超时：保留 requestId，下次先消费恢复；不在后台无限重试。未知消费错误不能降级成免费放行。账号切换时丢弃旧 UI 结果，并保留归属于旧账号的操作记录供原账号恢复。

## 必须验收

未登录购买自动登录且取消不买；余额不足不授予权益；买后未用刷新仍有库存；重复消费请求只扣一次；消费回执丢失后重试不新增订单；组合中购买成功但消耗失败正确提示；多标签并发不产生负库存；账号 A 结果不应用到 B。预览模拟库存可能刷新重置，不能用它证明正式库存丢失或真实付款成功。

交接单写清“哪里买、哪里用、何时扣、买后未用如何恢复”。记录实际 orderId、consumptionId、requestId 和时间，详情见[功能验收](../../../guides/integration/acceptance.md)。
