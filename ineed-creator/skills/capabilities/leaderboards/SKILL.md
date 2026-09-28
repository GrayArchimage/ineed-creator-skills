---
name: ineed-leaderboards
description: 接入真实局次成绩与地区排行榜。
---
# 排行榜

真实开局生成 runId，结束冻结 `{boardKey,runId,score,durationMs,endedAt}`，用 `leaderboards.submit` 提交；失败重试使用同一份冻结数据。先查询 `leaderboards.list` 获取已配置榜单，不能替创作者决定分数规则。

自绘界面调用 `leaderboards.get`，支持 world/province/city、page/pageSize；平台界面 `ui.leaderboard`。客户端分数不是防作弊证明，公开竞技要另行设计服务端验证。禁止将脚本模拟分数写入正式榜单。
