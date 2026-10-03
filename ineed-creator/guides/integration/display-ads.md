# 显式展示广告

创作者选择入口、位置和关闭时机，游戏调用 `show` / `close`；平台校验作品授权并处理供应商、频控、实际展示和关闭。普通展示不发奖励，也不能用于复活、解锁商品或证明支付成功；这些功能使用[支付](../../skills/capabilities/payments/SKILL.md)或[激励广告](../../skills/capabilities/rewarded-ads/SKILL.md)。

新接入由平台登记允许的 `placement + type`，只在游戏显式调用时尝试展示。登记后不自动附加开屏、底栏、死亡或重开广告；想要进入广告，也在创作者选定的进入事件调用一次。未迁移的旧作品保留原有入口和匹配广告配置，不因 SDK 更新改变行为。不要监听血量、结局文字或 DOM 来猜测广告时机。

## 1. 选择入口，交给平台开通

先说明实际入口、类型（`interstitial` 或 `banner`）、广告位别名和关闭条件。平台回显真实 placement、类型授权和限制后再核对绑定。安装 SDK 不等于开通：helper 会协商 `ads.show` / `ads.close`；旧宿主或未开放方法返回 `UNSUPPORTED`，广告位未获许可返回 `NOT_ALLOWED`。普通展示不额外要求登录。

无填充、取消、超时、频控或不支持时继续原游戏流程；不能因此绕过独立的付费或激励校验。一次展示使用一个 requestId；同 ID 重试不会变成新曝光，新一次展示才生成新 ID。

## 2. 最短调用

### JavaScript

把 [client.mjs](../../skills/capabilities/ads/client.mjs) 复制到项目中。helper 每次调用读取平台注入的 `window.INeedHost` 并协商能力；不要额外装广告商 SDK。`round-break` 仅为示例，须换成平台确认的广告位。

```js
import { displayAds } from './platform/client.mjs';
let activeAdId = '';

// 由创作者选定的游戏事件调用；advanceOriginalFlow 是游戏原有流程。
async function onChosenAdEntry() {
  const requestId = `ad_${crypto.randomUUID()}`;
  activeAdId = requestId;
  try {
    const result = await displayAds.show({
      type: 'interstitial', placement: 'round-break', requestId
    });
    if (!result.ok) console.warn('display ad:', result.error.code);
    // 普通展示的 shown/closed 均不是奖励或付款凭据。
  } finally {
    if (activeAdId === requestId) {
      activeAdId = '';
      advanceOriginalFlow();
    }
  }
}
function leaveChosenAdEntry() {
  const id = activeAdId;
  activeAdId = '';
  if (id) void displayAds.close(id);
}
```

提前离开或取消时调用 `await displayAds.close(requestId)`。因此需要离开的场景应将该 ID 存在场景状态中；不要生成另一个 ID 来关闭。

### Godot

按 [Godot Skill](../../skills/engines/godot/SKILL.md) 安装 `INeed` Autoload，再复制 [hosted_display_ads.gd](../../skills/capabilities/realtime/godot/hosted_display_ads.gd)。helper 会初始化并检查能力；本地原生运行或没有平台宿主时返回 `UNSUPPORTED`。

```gdscript
const Ads = preload("res://platform/hosted_display_ads.gd")
var ad_request_id := ""

func on_chosen_ad_entry() -> void:
    ad_request_id = "ad_" + Crypto.new().generate_random_bytes(16).hex_encode()
    var id := ad_request_id
    var result: Dictionary = await Ads.show("interstitial", "round-break", id)
    if id != ad_request_id or not is_inside_tree():
        return
    ad_request_id = ""
    if not result.get("ok", false):
        print("display ad: ", result.get("error", {}).get("code", "UNKNOWN"))
    advance_original_flow()

func close_current_ad() -> void:
    if not ad_request_id.is_empty():
        var closing_id := ad_request_id
        ad_request_id = ""
        await Ads.close(closing_id)
```

暂停和声音保留原状态，平台模态结束后恢复原状态；`resume` 不是发奖通知。不要用展示结果改变联机胜负或等待对手确认广告。

## 3. 匹配 banner 独立于匹配进度

开始匹配不等待广告填充。在真实“正在等待”事件中另起广告调用；成功匹配、开始倒计时、取消、失败、离开或账号切换时，立即关闭同一 requestId，继续原匹配流程。广告加载和 SDK 初始化尚未完成也可以 close；迟到请求或素材不能在开战后再次出现。

Godot 只需传入不遮挡按钮的透明 Control：

```gdscript
var match_ad_id := ""

func on_match_waiting() -> void:
    match_ad_id = "match_" + Crypto.new().generate_random_bytes(16).hex_encode()
    show_match_ad() # 不 await；联机流程独立继续。

func show_match_ad() -> void:
    if match_ad_id.is_empty():
        return
    var id := match_ad_id
    var result: Dictionary = await Ads.show("banner", "matching", id, $MatchPanel/AdSpace)
    if id != match_ad_id:
        return # 场景已离开，不应用迟到结果。
    if not result.get("ok", false):
        print("match ad: ", result.get("error", {}).get("code", "UNKNOWN"))

func on_match_leaving() -> void:
    var id := match_ad_id
    match_ad_id = ""
    if not id.is_empty():
        close_match_ad(id) # 不等广告关闭才启动倒计时/回菜单。

func close_match_ad(id: String) -> void:
    await Ads.close(id)
```

`Ads.show(type, placement, request_id, space = null, rotated_clockwise = false, keep_aspect = true)` 默认处理 `aspect=keep` 的等比缩放和居中留边。只有整个 Canvas 被网页顺时针转 90 度时，第五个参数传 true；设备原生横屏仍为 false。明确使用忽略宽高比拉伸的工程才将第六个参数设为 false。自定义 viewport/CanvasLayer 变换需单独验证。

helper 不自动监听布局变化。Control 尺寸或浏览器方向变化后，在仍等待时再次调用 `show_match_ad()`，复用当前 ID 更新位置；不会重新加载素材或重复占用频控。不要每帧发请求。Control 不画背景且设置 `mouse_filter = Control.MOUSE_FILTER_IGNORE`，取消按钮在广告填充前后都可用。

Web 的 `show` 使用 JSON `layout`，不能直接传 DOM 或 Godot Node。普通未旋转 DOM 区域可这样取位置：

```js
const rect = adSpace.getBoundingClientRect();
const result = await displayAds.show({
  type: 'banner', placement: 'matching', requestId: activeMatchAdId,
  layout: { x: rect.x, y: rect.y, width: rect.width, height: rect.height,
    viewportWidth: innerWidth, rotated: false }
});
```

将这段放在独立异步函数中，不让它阻塞开始匹配；离开时 `displayAds.close(activeMatchAdId)`。同一 ID 只更新当前广告的布局；终态后需要新的真实展示动作才用新 ID。正常 DOM 坐标是内容窗口内 CSS 像素；旋转 Canvas 使用旋转前逻辑坐标，viewportWidth 仍为物理窗口宽度。Godot 应优先用 helper 转换，不自行拼私有协议。

关闭时平台移除素材及整块容器；创作者同时隐藏自己额外画出的广告背景。广告未填充时不显示占位白板。至少检查 PC、手机竖屏内旋转、等比留边、无填充、加载中取消和匹配结束。

## 参数与结果

底层桥接为 `INeedHost.request("ads.show", params)` / `INeedHost.request("ads.close", {requestId})`；Godot 也可使用 `INeed.request`。推荐先用上述 helper，不需要手写 postMessage。

- type 仅 `banner` / `interstitial`。placement 为 1–64 位英文字母、数字或 `_.-`；requestId 为 1–128 位英文字母、数字或 `_:.-`。
- banner 必须提供有效 layout：`{x,y,width,height,viewportWidth,rotated}`；平台校验几何边界、过小尺寸和素材适配；Canvas 内按钮的位置由创作者保证不被覆盖，平台不能自动识别这些操作区。
- show 的正常 envelope 为 `{ok:true,value:{requestId,type,placement,status,shown,reason?}}`。`ok` 表示请求正常处理，不表示广告一定显示。

| status | 含义 | 游戏处理 |
| --- | --- | --- |
| shown | banner 已实际可见 | 需要离开时仍须 close |
| closed | 插屏实际结束，或关闭已展示的广告 | 按 shown 判断是否实际展示；继续原流程 |
| no_fill | 没有可用素材 | 继续，不留占位 |
| cancelled | 请求或展示被取消 | 查看 shown 判断此前是否可见；迟到结果不可重新展示 |
| timeout | 加载或展示到达上限 | 继续，不循环补发 |
| skipped | 频控、忙碌或当前界面等条件不适合展示 | 查看 reason 用于排错，不挡游戏 |

close 在 show 尚未到达时也有效，value 此时可以只有 `{requestId,status:"closed",shown:false}`，不要求 type/placement。关闭已结束请求返回记录结果，不强行把 no_fill 等改成 closed。

结构或权限错误为 `{ok:false,error:{code,message}}`：`INVALID_PARAMS`、`NOT_ALLOWED`、`UNSUPPORTED`、`REQUEST_ID_CONFLICT`。同 ID 改 type 或 placement 属冲突；桥接超时或会话请求过多也可能返回 TIMEOUT/BUSY 等错误，保留实际错误码。close 可以在 show 待定时调用，并使原调用结束；不会被普通模态 BUSY 锁挡住。加载最多等待 15 秒，已显示插屏最多 120 秒后整块收起；这些上限不是要求游戏阻塞等待。

腾讯供应商若已经开始不可中止的异步渲染，取消后会清理其迟到内容，并可能让该页面后续插屏返回 skipped/busy。继续游戏即可，不为获取广告刷新或循环重试。

普通结果没有奖励或支付 receipt。需要奖励时调用 `ads.rewarded`，由平台服务端校验供应商完成状态，再核对 receiptId、actionId 和 placement 并去重；本地倒计时、关闭播放器和联机 RPC 均不能作为奖励凭据。

## 交接和兼容

随 ZIP 发送一段真实说明，例如：

```text
广告由游戏显式调用：匹配等待使用 banner，广告位 matching；匹配成功/开始倒计时/取消/失败/离开即 close。
无填充继续匹配，不保留背景；没有激励奖励，不额外绑定死亡或重开广告。
请回显 placement + type 授权和限制。已测：<实际环境与结果>；待测：<确实未测的供应商或设备>。
```

有进入广告或其他入口时按实际选择补充，不照抄示例。上传 ZIP 后将已填写说明复制到该作品的平台聊天。模拟素材只能证明布局和调用结果，真实填充需平台预览验证。撤销某个入口时明确覆盖旧说明，不能让旧事件重新开启。

旧包的 `matching_waiting` / `matching_closed` 等单向兼容方法继续保留，但没有展示结果，不能当作新接口的成功凭据；新接入使用 `show` / `close`。平台开启新 placement 授权前应确认包已调用新 API，不能只改配置使旧游戏的既有广告消失。
