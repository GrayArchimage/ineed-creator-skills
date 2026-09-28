---
name: ineed-payments
description: 接入平台商品支付权益和幂等消费。
---
# 支付

数据接口 `payments.products` / `payments.inventory` / `payments.entitlements`。自绘商店使用这些真实数据；平台商店 `ui.store`。两种模式付款均调用 `payments.buy`，平台确认页承接真实支付。

服务端决定价格、权益和库存。只有服务端成功返回并刷新权益后才解锁，不能用本地布尔值。消耗型道具调用 `payments.consume`，为同一动作保存稳定 requestId，失败重试复用；不反复生成新 ID。未知商品列待办，不能擅自设置价格或修改默认商品语义。
