---
name: ineed-godot
description: 为 Godot GDScript 源工程接入 iNeed 登录、购买与消耗、排行榜、激励广告和存档，绑定真实事件并验收单线程 Web 导出。
---
# Godot 接入

适用 Godot 4.3+、GDScript、Compatibility 渲染器、单线程 Web。此 Skill 指导 AI 修改源工程；SDK 只提供桥接，不自动理解游戏玩法。只有成品时见“只有成品”。

## 先读哪一页

| 当前任务 | 阅读资料 |
|---|---|
| 判断是否能做 | [能力与支持边界](../../../guides/integration/support.md) |
| 首次安装、接线、导出 | 本页，随后阅读 [完整开发流程](../../../guides/integration/workflow.md) |
| 查函数、参数、返回值 | [Godot 接口手册](../../../guides/integration/api.md) |
| 自绘商店或使用平台页面 | [界面与交互建议](../../../guides/integration/ui.md) |
| 遇到失败、超时、重复操作 | [异常与恢复](../../../guides/integration/recovery.md) |
| 上传前验收 | [功能验收](../../../guides/integration/acceptance.md)及[与 iNeed 沟通](../../platform-handoff/SKILL.md) |

SDK 获取：[GitHub Godot 插件](https://github.com/GrayArchimage/ineed-creator-skills/tree/main/ineed-creator/skills/engines/godot)。可运行的最小工程在同一目录的 example 中。正式交付记录所用 Release 标签、插件版本和哈希，不让游戏启动时从 GitHub 下载浮动版本。

## 1. 检查工程并确认范围

从已解压的创作者技能包根目录运行：

```sh
python3 scripts/project.py inspect "/完整路径/游戏工程"
python3 scripts/project.py install "/完整路径/游戏工程"
```

AI 应解析包根后使用脚本绝对路径，不能假定用户终端就在技能目录。安装脚本把插件复制到工程 addons/ineed/ineed.gd 并注册 INeed Autoload；不是 EditorPlugin，不需要勾选编辑器插件。重复安装不会重复注册；现有插件内容不同或 Autoload 冲突时先比较，不能覆盖。

先查项目版本、语言、导出预设、现有 SDK、主菜单、开局、结算、商店、存档和暂停逻辑。只询问尚不能从工程/用户指示确定的事项：需要哪些能力、商品/奖励语义、榜单规则、界面分工。问题清单见[完整开发流程](../../../guides/integration/workflow.md)。

## 2. 建立一处平台适配层

在项目已有服务节点或新增的适配节点中初始化一次，连接一次 platform_event。逐个检查实际方法名的 supports；不能使用 supports("payments") 这样的分类名称。初始化失败保留原免费玩法，对依赖平台的按钮显示原因，不能伪装成功。

```gdscript
extends Node

func _ready() -> void:
    var result: Dictionary = await INeed.initialize()
    if not result.get("ok", false):
        push_warning(str(result.get("error", {})))
        return
    if INeed.supports("account.get"):
        var account_result: Dictionary = await INeed.request("account.get")
        print(account_result)
```

统一返回结构是成功 `{ok: true, value: ...}` 或失败 `{ok: false, error: {code, message}}`。Dictionary 非空不代表成功；value 的形状随方法变化。详细示例见[接口手册](../../../guides/integration/api.md)。

## 3. 按实际需求绑定事件

- [登录与账号](../../capabilities/login/SKILL.md)：游客入口、登录按钮、账号切换和恢复。
- [商品购买与消耗](../../capabilities/payments/SKILL.md)：购买增加库存；真实使用才扣减；已有库存不重复购买。
- [排行榜](../../capabilities/leaderboards/SKILL.md)：真实开局生成 runId，结束冻结成绩，重试复用原数据。
- [激励广告](../../capabilities/rewarded-ads/SKILL.md)：确认平台开通、绑定触发动作、按可信 receipt 去重。
- [存档](../../capabilities/storage/SKILL.md)：绑定现有保存/读取入口，处理版本与冲突。

修改前寻找已有连接，避免 repeated connect、重复开局、重复扣减；不要改原游戏规则。新增方法只能由平台登记并授权，不得通过 request 执行远程 GDScript 或任意 HTTP 接口。

## 4. 暂停、界面和导出

按[界面建议](../../../guides/integration/ui.md)连接 pause/resume，恢复先前状态，不能无条件解除用户主动暂停。适配节点和 INeed Autoload 在暂停期间仍应处理回调。

游戏自绘 UI 要覆盖动态商品名、昵称的字体，不能只保留剧情字集。示例附带的 OFL 字体覆盖常见中文，补充生僻字或 emoji 仍需另行验证。不要把玩家头像 URL 任意转换为可执行内容；头像缺失要有占位。

检查 thread_support=false、extensions_support=false，保留匹配的 JS/WASM/PCK/worklet，按[Godot 导出设置](../../../guides/packaging/godot-export.md)生成新目录，再按[功能验收](../../../guides/integration/acceptance.md)逐项测试。Godot 4.0–4.2、C# Web、多线程、Unity 不属于当前接入范围。

## 只有成品

只做托管兼容检查和平台壳功能。不能声称已绑定内部奖励、真实开局结算、原生存档或暂停；不要盲改 PCK。需要完整接入时列出所缺源工程及事件。

## 交付给平台

输出修改文件、节点/按钮位置、已绑定标识、插件版本、待配置项、测试证据及[配置交接单](../../platform-handoff/SKILL.md)。标明预览模拟与真实服务的差别。保持旧接口、旧语义及旧存档；不因新增需求绕过[兼容性原则](../../../COMPATIBILITY.md)。

联机读取 [实时联机](../../capabilities/realtime/SKILL.md)；本地制作与上传交接使用 [完整交接流程](../../../guides/integration/handoff-workflow.md)。核实源工程与当前上传包相符，不能因名称相同就覆盖新版本。
