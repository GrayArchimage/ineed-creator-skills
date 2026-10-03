# 游戏展示广告事件

这里是可选的宿主适配层，协议 v1 和现有 INeed/INeedRealtime 方法不变。它只请求平台尝试展示；是否启用、频率、供应商及素材由平台决定。未支持、无填充或失败时继续游戏，不补发到稍后的战斗里。它不是 `ads.rewarded`，不能用来发道具、复活或解锁付费能力。

## 最少接入

Godot 可复制实时插件旁的 [hosted_display_ads.gd](../../skills/capabilities/realtime/godot/hosted_display_ads.gd)，以项目自选名称 preload：

```gdscript
const DisplayAds = preload("res://platform/hosted_display_ads.gd")
# 真正开始等待匹配后，传入不覆盖按钮的空白 Control。
DisplayAds.matching_waiting($MatchPanel/AdSpace)
# 匹配成功、取消、失败、离开或开始倒计时，均关闭整个广告位置。
DisplayAds.matching_closed()
# 仅当用户要求败局广告：真实结束且本地玩家失败时通知一次。
DisplayAds.defeat(run_id + ":" + str(defeat_index))
# 复活、新局、回菜单或关闭结算，立即使旧异步响应失效。
DisplayAds.playing()
DisplayAds.dismissed()
```

默认按项目 `aspect=keep` 使用同一比例并计算居中留边；若项目刻意采用忽略宽高比的拉伸，第三个参数传 false。其他自定义 viewport/CanvasLayer 变换由网页适配器提供最终坐标，不猜测。普通横屏 canvas 使用默认参数；若网页适配器把整个 canvas 顺时针旋转了 90 度，传 `matching_waiting(control, true)`。不旋转的原生横屏仍为 false。空白区域变化或窗口旋转后重新发送位置；广告未填充时不画背景或白板。广告区的 Control 不拦截输入，避免遮挡取消按钮。测试最终导出包，不能只看编辑器位置。

开屏由平台配置处理，游戏无需反复发送 entry 事件。只需要开屏和匹配广告时，不接败局事件。失败 ID 在一次页面会话中唯一，同一次结算重绘复用同 ID；复活后下一次失败生成新 ID。广告不应用于加载旧死亡存档、取消操作或网络暂时中断。

## Web / 自定义适配器契约

向父窗口发送 `type: "ineed:hosted-ad-event"`。平台只接收当前内容 iframe，外部 iframe 和任意页面消息无效：

- 匹配：`event: "match-waiting"`，`visible: true` 和 `layout: {x,y,width,height,viewportWidth,rotated}`。位置单位是内容窗口内 CSS 像素；旋转时 x/y/width/height 为旋转前的逻辑坐标，viewportWidth 仍是当前窗口物理宽度。关闭只发同一 event 和 `visible: false`。宽度不足 100、高度不足 30、越界或素材过大会隐藏整块广告；不要强迫显示。
- 败局：`event: "game-result"`，`state: "ended"`、`outcome: "defeat"`（或 `failure`）、`resultId`。ID 限 1–128 个英文字母/数字/下划线/冒号/点/短横线；同 ID 去重。
- 失效：同一 `game-result` 的 `state: "playing"` 或 `"dismissed"`，使旧败局响应不可展示。父层导航和登录/付款界面也会保护当前操作。

宿主不支持此适配层时消息安静忽略；不能据此宣布广告已接通。作品的展示广告授权、开屏许可和实际触发点必须由平台回显，不能由网页消息自行开启。普通展示仅统计真实可见事件，发出请求不等于有收益。

## 交接及验收

发布说明只写实际需要的一行，例如“广告：进入开屏，匹配等待时展示，匹配成功/取消/失败即关闭；无填充继续游戏；不接激励”。需要败局广告时补真实触发入口和复活/回菜单失效行为。

创作者验证空白区域与事件；平台验证授权、一次 SDK、请求串行、频率、无填充、迟到响应、关闭无残留，以及 PC/手机旋转几何。模拟素材只证明布局，真实填充需平台域名的供应商响应与可见证据。用户没有选择的付费/激励功能不增加。
