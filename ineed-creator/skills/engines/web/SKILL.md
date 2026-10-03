---
name: ineed-web
description: 接入普通静态网页的 iNeed 平台能力。
---
# Web

平台注入 `window.INeedHost`，不重复加载业务 SDK。`const result = await INeedHost.request("login", {})`；先 `request("hello",{protocols:[1]})` 再 `supports("payments.buy")`。既有 `window.iNeed` 接口保留。

数据模式使用返回结果渲染游戏 UI；平台模式调用 `ui.store`、`ui.leaderboard`。统一返回 envelope，错误必须展示或可重试；支付/奖励不能客户端假造。订阅 `INeedHost.subscribe(callback)` 获取 JSON 文本事件，结束时调用 unsubscribe。

普通广告读取[展示广告 Skill](../../capabilities/ads/SKILL.md)，使用 displayAds.show/close 绑定创作者选择的入口与退出；不自动推断死亡或重开。需要奖励改读[激励广告](../../capabilities/rewarded-ads/SKILL.md)，普通展示结果不能发奖。

## 交付给平台

按 [与 iNeed 沟通](../../platform-handoff/SKILL.md) 输出配置交接单和实际入口测试步骤。标识尚未绑定时明确列为待办；平台配置不自动补写游戏事件。

开始先收集用户目标和能力选择；本地完成后按 [完整交接流程](../../../guides/integration/handoff-workflow.md) 生成可复制发布说明，并明确提醒上传后粘贴到作品的平台聊天。实时联网按 [实时联机](../../capabilities/realtime/SKILL.md) 判断当前宿主支持，不默认全开。
