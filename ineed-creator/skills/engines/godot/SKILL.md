---
name: ineed-godot
description: 接入 Godot 4.3+ GDScript 单线程 Web 游戏。
---
# Godot 接入

脚本位于包根 `scripts/project.py`，从本目录引用为 `../../../scripts/project.py`。运行 `python3 ../../../scripts/project.py install <工程>`；由当前工作目录决定命令路径，优先使用已解析的包根绝对路径。

插件在 `plugin/ineed.gd`，安装到工程 `addons/ineed/ineed.gd` 并注册 `INeed` Autoload。插件不是 EditorPlugin，不需要启用编辑器插件。示例在 `example/`。

先 `await INeed.initialize()`，检查 `supports()` 再调用：`await INeed.login()`、`await INeed.buy(product_key)`、`await INeed.open_leaderboard(board_key)`、`await INeed.show_rewarded(placement, action_id)`。所有结果都是 `{ok, value}` 或 `{ok:false,error:{code,message}}`，不能只检查 Dictionary 是否非空。

通用 `request(method, params)` 支持未来已登记能力；不得执行远程 GDScript，不得透传任意 HTTP 接口。具体协议见 [契约](../../../protocol-v1.md)。

平台界面：`ui.store` / `ui.leaderboard`；游戏自绘：`payments.products` / `leaderboards.get` 等数据接口。账号验证、确认付款与真实广告展示始终在可信平台页面。

连接 `platform_event` 中的 `pause` / `resume`，保存并恢复游戏原有暂停和音频状态，不要无条件恢复为播放。Autoload 必须 PROCESS_MODE_ALWAYS，避免暂停导致回调失效。绑定真实开局和结束，冻结 runId、成绩、耗时，重试不重算。

Godot 4.0–4.2 标准模板不提供本首版的单线程方案，提示升级或另行验证，不宣称所有 Godot 4 版本可用。检查 Web 预设、Compatibility renderer、thread_support=false、extensions_support=false。保留匹配的 wasm/js/pck/worklet 文件；不混用模板版本。

## 只有成品

只做托管兼容检查和平台壳功能。不能声称已绑定内部游戏奖励、真实结算、原生存档或暂停。不要解包后盲改 PCK 玩法逻辑。需要完整接入时说明所缺源工程与事件。

游戏自绘 UI 必须验证动态商品名/昵称的字体覆盖，不能只打包旧剧情字符子集。示例使用英文控件以免依赖系统 CJK 字体；真实中文界面请使用有授权且覆盖所需字符的本地字体。
