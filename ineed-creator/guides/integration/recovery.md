# 异常与恢复

游戏只在对应操作的 ok=true 后应用结果；非空对象、关闭弹窗、账号已登录都不是业务成功。未知错误保留原状态并显示可理解的提示。

## 按错误选择处理

| code 或现象 | 处理 |
|---|---|
| UNSUPPORTED / PROTOCOL_UNSUPPORTED | 标明宿主/能力未支持；停用该功能，保留可独立运行部分 |
| AUTH_REQUIRED | 按需登录；取消就停止依赖登录的动作 |
| ACCOUNT_CHANGED / SESSION_CHANGED | 丢弃旧身份 UI 结果，加载新身份；核实原账号交易，不自动回滚 |
| CANCELLED | 回到原入口，不扣本地数值、不授予权益 |
| INSUFFICIENT_BALANCE | 不发放权益；提供充值/返回，保留原游戏选择 |
| INSUFFICIENT_INVENTORY | 只消耗路径提示不足；明确的购买并使用路径才允许购买一次 |
| PURCHASE_UNCONFIRMED（插件组合调用） | 先核实上次购买；保留待核实标记，刷新后也不自动重买 |
| BUSY | 已有动作执行中；等待后人工重试，不并发打开多个模态框 |
| TIMEOUT / REQUEST_FAILED / CONSUME_FAILED | 不猜测交易失败或成功；保留业务 ID，查询/恢复原动作，不自动新建购买 |
| INVALID_PARAMS / INVALID_ARGUMENT | 检查 key、类型和范围；不循环请求同样坏参数 |
| STORAGE_CONFLICT | 保留两份，重新读版本并让用户决定 |
| STORAGE_TOO_LARGE / STORAGE_FORMAT / STORAGE_UNAVAILABLE | 保留本地草稿，修复体积/兼容性/浏览器存储后再试 |
| NO_FILL / EXPIRED / PROVIDER_ERROR / REWARD_FAILED | 不发广告奖励；恢复游戏并允许适当重试 |

下层接口可能转发其他错误；旧版购买取消也可能映射为 REQUEST_FAILED。不得只识别 CANCELLED 然后把其他错误当成功。

## 需要持久化的恢复线索

| 操作 | 同一次重试必须不变 | 成功后记录 |
|---|---|---|
| 消耗 / 购买并消耗 | 账号、作品、productKey、quantity、requestId、动作内容 | consumptionId；对应玩法是否已应用及恢复点 |
| 排行榜 | 账号、boardKey、runId、score、durationMs、endedAt、stats | receipt 和提交状态 |
| 激励广告 | 账号、作品、placement、actionId | receiptId 及奖励应用状态 |
| 存档 | 本地待保存内容、原 baseVersion、schemaVersion | 新 version；冲突时不能直接替换 baseVersion 覆盖 |

买入库存后尚未使用，刷新应从服务器会话恢复库存。只购买的 Godot v1 调用没有公开自定义订单 requestId 或订单查询方法；未知购买结果应核对权益/库存并交平台查订单，不自动再次 buy。

组合调用在重试时先用原 requestId 调用 consume，已成功的消费直接返回原回执，不会先检查“库存为零”然后再次购买。客户端恢复线索不可作为授权凭据；服务端仍验证身份和库存。

## 排查日志如何给平台

```text
作品：链接/作品标识，正式或预览
版本：游戏 ZIP SHA256、插件版本、hello 返回 runtimeVersion
时间：含时区，设备系统、浏览器名称版本（QQ/微信请注明）
入口：菜单路径、按钮、预期与实际
身份：平台用户标识（私密提交给平台，不公开个人资料）
请求：方法、productKey/boardKey/placement、requestId/runId/actionId
响应：ok、error.code/message，orderId/consumptionId/receiptId（如果有）
复现：刷新前后、是否切账号、是否断网、是否点了重试
```

不得包含 token、密码、私钥、完整存档或支付敏感信息。平台可按这些线索关联购买、钱包扣款、库存、消费及奖励记录；Godot 包装器没有承诺向游戏暴露所有日志字段。

## 服务端与客户端的界限

SDK 负责发出受约束的请求；平台负责支付授权和账本；游戏负责只在成功后执行玩法。已经下载的客户端可被玩家修改，不能把“客户端无法被改”作为安全保证。真正有价值的发放、扣减和竞争结果需相应服务器验证。遇到安全疑点保留证据，不能通过“错误就免费继续”改善体验。
