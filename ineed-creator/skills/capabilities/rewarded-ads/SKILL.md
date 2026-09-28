---
name: ineed-rewarded-ads
description: 接入有可信完成验证的一次性广告奖励。
---
# 激励广告

`ads.rewarded` 参数 `{placement,actionId}`；相同奖励动作保持 actionId。广告位及奖励由平台配置。先 supports，未配置/无填充/取消/失败不得发奖。

仅接受平台持久化结算记录返回的 receipt。不要把旧计时访问 token 当成通用奖励凭据，不允许客户端声称广告完成。游戏记录已应用 receiptId，存档冲突时不静默重复发奖；货币/权益等高价值资产以服务端账本为准。服务端未配置可信供应商时明确 UNSUPPORTED，模拟供应商结果只能用于隔离测试。
