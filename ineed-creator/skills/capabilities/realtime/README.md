# 实时联机 SDK

平台负责登录、匹配/房间、信令和 TURN；创作者负责角色、操作、战斗规则、胜负和断线画面。第一版支持双人，入口可选随机匹配、大厅、邀请的一种或多种。作品需先在平台聊天确认配置并启用。

## Godot

把 `godot/addons/ineed_realtime` 复制到工程 `addons/ineed_realtime`。在跨场景保留的 Autoload 中创建一次连接：

```gdscript
var connection: INeedConnection

func _ready():
    connection = INeedConnection.new()
    add_child(connection)
    connection.game_ready.connect(_on_game_ready)
    connection.disconnected.connect(_on_disconnected)

func match_game():
    var result := await connection.start_game(multiplayer, "my-game-v1")
    if not result.get("ok", false): show_match_error(result.error)

func _on_game_ready(is_host: bool):
    name_label.text = connection.display_name
    # 到这里 Godot 已能发送 RPC。接回原有选角、双方准备、开局流程。
    begin_existing_lobby(is_host)

func _on_disconnected():
    pause_match_and_show_exit()

func exit_match():
    await connection.leave()
```

`start_game` 负责按需登录、信令、TURN、peer 安装/释放和 Godot 握手。`game_ready` 才表示可以调用原有 RPC，返回成功仅表示进入房间。放在跨场景 Autoload；重复点击返回 BUSY；退出 `leave()` 后不会清理别的连接。旧 `start(mode, build, code)` 与 `connected(peer)` 继续保留，供自管 MultiplayerAPI 的项目使用；不要同时混用两种所有权。

大厅：`await connection.signaling.list_rooms()` → 展示列表 → `start_game(multiplayer, build, "lobby", code)`；建公开房不传 code。邀请：`start_game(multiplayer, build, "invite")` 返回房间码，另一人带 code 加入。只需要随机匹配时不要添加其余入口。

### 已能本地联机的工程要改哪里

保留 Godot MultiplayerAPI、RPC、角色权威、状态转移及序列化。把原有 ENet 的“建房/连接 IP”入口替换成 `start_game`，把旧连接完成回调接到 `game_ready`；不要让创作者实现 SDP、ICE、HTTP 轮询或保存 TURN 密钥。

本地联机可用是良好基础，但不是任意工程零修改的保证。AI 需检查 ENet 专有调用/通道、硬编码 IP/peer、NodePath 一致、authority 分配、可靠与不可靠消息及包大小；同步的数据结构、动作状态、胜负仍属于游戏。对局加载/3秒倒计时、权威判定、插值、短断流暂停由游戏实现，SDK 不猜玩法。

仅导出单线程 Web / GDScript / Compatibility。旧平台未启用或用户取消登录时失败并保留单机。信令暂时不可达不等于健康 RTC 已断线；玩法仍需可靠保活/失联暂停，不能继续判定胜负。当前不支持断线续局/热加入，不能向用户承诺刷新后回到战斗。

## 普通网页

`client.mjs` 负责信令和按需登录；游戏自身建立 `RTCPeerConnection({iceServers, iceTransportPolicy:"relay"})`、数据通道和玩法消息。`match(build)`、`create(mode, build)`、`list()`、`join(code, build)`、`signal(kind,data)`、`watch()`、`leave()` 返回 Promise。先协商宿主能力，旧宿主明确报 `UNSUPPORTED`。重试同一请求传原 `clientId` / `requestId`。

## 交给平台

让制作 AI 先确认玩法、引擎、联机入口、人数、断线规则，以及是否需要广告/商品/排行/存档。完成本地测试后生成一段已填写说明，用户上传 ZIP，再粘贴到该作品的平台聊天。示例：

> 这是《作品名》的新版本，更新同一作品。Godot 4.x 单线程 Web；双人随机匹配，build=my-game-v1。匿名单人，点击匹配才登录；双方选角后房主开始，断线停止本局并返回标题。保留已配置的底部广告，不新增商品、排行或云存档。已测试双端开局、动作同步、取消和断线；请回显配置并提供审核预览。

平台回显后核对配置，在预览测试，再提交审核。上传 ZIP 或粘贴说明本身都不等于平台已开启功能。

## 同一账号换设备

随机匹配发现同账号已有联机时，平台弹窗询问是否顶替。确认后结束旧联机并重新匹配；取消保留原会话。旧对手收到断开，游戏按自己的断线流程返回或重新匹配，不自动判负或发奖。创作者无需另接登录互踢、顶替接口或弹窗，继续使用原来的匹配入口并处理 `disconnected`。

确认期间不要重复发起匹配。测试等待中/对战中顶替、取消和重新匹配，并把实际测试结果写入上传后的平台聊天说明。旧平台返回 `ALREADY_IN_ROOM` 时保留原因，提示退出原页面后重试。详细边界见 [联机 Skill](SKILL.md#同一账号切换设备)。
