---
name: ineed-web
description: 接入普通静态网页的 iNeed 平台能力。
---
# Web

平台注入 `window.INeedHost`，不重复加载业务 SDK。`const result = await INeedHost.request("login", {})`；先 `request("hello",{protocols:[1]})` 再 `supports("payments.buy")`。既有 `window.iNeed` 接口保留。

数据模式使用返回结果渲染游戏 UI；平台模式调用 `ui.store`、`ui.leaderboard`。统一返回 envelope，错误必须展示或可重试；支付/奖励不能客户端假造。订阅 `INeedHost.subscribe(callback)` 获取 JSON 文本事件，结束时调用 unsubscribe。
