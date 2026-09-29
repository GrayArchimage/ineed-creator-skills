# 从作品到上线，接入有据可循。

普通网页与 Godot 游戏的打包、接入和发布规范。按工程选择入口，按功能读取 Skill；同一份 Markdown 同时服务创作者和 AI。

## 选择你的工程

- [Web 静态网页](../skills/engines/web/SKILL.md)：静态生产包、平台数据与界面接入。
- [Godot 单线程 Web](../skills/engines/godot/SKILL.md)：Godot 4.3+ / GDScript / Compatibility，插件与事件绑定。

## 按开发阶段找到答案

| 阶段 | 文档 | 可以直接得到什么 |
|---|---|---|
| 判断范围 | [支持能力](integration/support.md) | 已有方法、平台前提、暂不支持的能力 |
| 开始接入 | [完整开发流程](integration/workflow.md) | 工程检查、提问清单、代码和配置分工 |
| 编写代码 | [Godot 接口手册](integration/api.md) | 函数、参数、返回值和数据读取位置 |
| 做好交互 | [界面建议](integration/ui.md) | 自绘/平台 UI、按钮状态、暂停与移动端 |
| 处理失败 | [异常与恢复](integration/recovery.md) | 登录、交易、存档与幂等重试 |
| 准备交付 | [功能验收](integration/acceptance.md) | 可操作测试清单和证据要求 |

登录、商品、排行榜、广告和存档分别有独立 Skill，可从左侧“功能接入”直接阅读。每页提供 Markdown；离线包用于 AI 按需读取。[SDK 在 GitHub 获取](https://github.com/GrayArchimage/ineed-creator-skills/tree/main/ineed-creator/skills/engines/godot)。

## 平台关键限制

| 存储总量 | Godot 解码总量 | 有效资源数 |
|---|---|---|
| 50 MiB | 128 MiB | 500 |

三项是不同维度；还需满足单文件、路径及云存档限制。完整定义见[容量与数量](packaging/limits.md)。

## 按任务查阅

- [快速开始](getting-started.md)：识别项目、选择界面、安装与验收。
- [支持文件类型](packaging/formats.md)：普通资源和条件支持的 Godot 压缩后缀。
- [压缩要求](packaging/compression.md)：ZIP、gzip、Brotli 与编码元数据。
- [运行验收与资源访问](packaging/validation.md)：重复请求、实际下载、内容及平台影响证据。
- [版本与下载](maintenance/releases.md)：完整 Skill 和纯 Markdown 文档、运行时更新与回滚。

## 兼容性优先

平台更新应保持已发布游戏与旧 SDK 的既有行为。发生冲突时交负责开发者决定，不用自动迁移绕过要求。查看[完整原则](../COMPATIBILITY.md)。
