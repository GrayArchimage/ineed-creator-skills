# 开始使用

把工程和创作者技能包交给你的 AI，从包根 `SKILL.md` 开始。入口会识别工程，再读取对应引擎及功能技能；不要求 AI 自动扫描所有子目录。

## 选择交付物

| 你的项目 | 阅读入口 | 可以完成什么 |
|---|---|---|
| HTML / CSS / JavaScript 或静态构建产物 | [Web 接入](../skills/engines/web/SKILL.md) | 打包、平台数据和平台界面接入 |
| 有 project.godot 的源工程 | [Godot 接入](../skills/engines/godot/SKILL.md) | 安装插件、绑定游戏事件、Web 导出与验收 |
| 只有 HTML / PCK / WASM 成品 | [Godot 接入](../skills/engines/godot/SKILL.md) | 托管兼容检查；完整玩法接入仍需源工程 |
| Unity 或其他引擎 | [支持范围](packaging/formats.md) | 先报告未验证范围，当前不承诺 SDK 接入 |

## 最短接入流程

1. 下载完整 Skill ZIP，解压为单一 `ineed-creator/` 目录。
2. 让 AI 阅读 `SKILL.md`，运行 `python3 scripts/project.py inspect <工程目录或ZIP>`。命令应从包根执行，也可以使用脚本绝对路径。
3. 选择所需功能及界面方式；能从工程发现的入口由 AI 自行识别。商品、奖励、榜单规则由创作者确认，不让 AI 猜测。
4. Godot 工程运行 `python3 scripts/project.py install <工程目录>`；AI 继续绑定真实开局、结算、保存、暂停事件。安装脚本不会自动理解所有玩法。
5. 按[导出设置](packaging/godot-export.md)生成新目录，按[验收清单](packaging/validation.md)测试，再上传 ZIP。

## 两种界面方式

- 游戏界面 + 平台数据：游戏自行绘制商店、榜单和按钮，SDK 提供商品、权益和排行数据。
- 平台界面 + 平台数据：调用 `ui.store` / `ui.leaderboard`，使用平台已有界面。

两种方式都由可信平台完成账号验证、付款确认及真实广告展示。推荐游戏自绘界面；没有明确偏好时采用平台界面。不要在游戏中收集账号密码、伪造付款或广告完成。

## 预发布状态

当前技能包属于预发布；Godot 范围为 4.3+、GDScript、Compatibility、单线程 Web。能力以实际平台协商结果为准，未配置供应商的激励广告不可用。完整技能包含插件、脚本及示例；纯 Markdown 文档包供阅读，不代替完整安装包。

## 把任务交给 AI

“请按 iNeed 创作者 Skill 检查这个 Godot 工程。保留现有游戏界面，接入登录、商品购买/消耗和排行榜。先从代码找入口，只问缺失的价格、数量和规则，输出平台交接单及可上传 ZIP。没有配置的能力明确标记待办，不模拟成功。”

接下来按顺序读[完整开发流程](integration/workflow.md)、[接口手册](integration/api.md)、[界面建议](integration/ui.md)和[功能验收](integration/acceptance.md)。SDK 从[GitHub](https://github.com/GrayArchimage/ineed-creator-skills/tree/main/ineed-creator/skills/engines/godot)获取；固定版本见 Release，不依赖游戏运行时联网下载代码。
