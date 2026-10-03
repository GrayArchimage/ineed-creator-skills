---
name: ineed-display-ads
description: 为 Web 或 Godot 绑定创作者选定的普通展示广告入口、位置和关闭条件，并处理无填充与取消；不用于激励发奖。
---
# 普通展示广告

读取[显式展示广告](../../../guides/integration/display-ads.md)，只绑定创作者选择的真实事件。使用本目录 `client.mjs` 的 `displayAds.show/close`，或[Godot helper](../realtime/godot/hosted_display_ads.gd) 的 `Ads.show/close`；方法、参数和状态以该手册为准。

1. 从工程找到入口和退出事件，确认 type、placement 与位置；不猜死亡、失败、重开或开屏时机，不改变创作者玩法。
2. 新接入由平台登记 placement + type 授权后显式调用，旧宿主不支持时继续原免费流程；不要绕过原有付费或激励校验。
3. 匹配与 banner 独立进行；同 requestId 更新布局，取消/匹配结束关闭整块广告，迟到填充不能重现。无填充不画背景、不遮挡按钮。
4. 普通 shown/closed 不发奖励；奖励使用[激励广告](../rewarded-ads/SKILL.md)并由服务端校验。测试模拟素材与真实供应商分别标记。
5. 按[平台交接](../../platform-handoff/SKILL.md)生成可粘贴说明，列出实际入口、类型、placement、关闭条件和已测/待测项；提醒上传后发送给对应作品的平台聊天。
