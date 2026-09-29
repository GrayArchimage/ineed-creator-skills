# 界面与交互建议

推荐沿用游戏自己的视觉和入口；没有明确偏好时使用平台现成商店/榜单。账号验证、支付确认和真实广告展示仍由可信平台承接。界面模式可以按功能分别选择。

## 入口放在哪里

| 功能 | 建议位置与文案 | 避免 |
|---|---|---|
| 账号 | 主菜单的头像/“登录”；游客标记可见 | 免费试玩前连续强制登录 |
| 商店 | 主菜单/准备页“商店”；商品名、价格、类型、库存 | 把购买按钮写成“开始”而隐去费用 |
| 消耗品使用 | 对应动作旁“使用 1 次（剩余 3）” | 选中即消耗、刷新即再买 |
| 购买并使用 | 真实动作处“购买并使用”；注明购买量和本次用量 | 按钮看似免费，成功后才解释扣款 |
| 排行榜 | 主菜单与结算页；自己的成绩突出但不喧宾夺主 | 反复自动弹榜、把登录失败写成空榜 |
| 激励广告 | 奖励场景内“看广告获得…”，可跳过 | 将普通广告假装可领奖；取消后发奖 |
| 存档 | 设置中“读取/保存”，保存结果轻提示 | 每次成功都阻塞游戏；冲突静默覆盖 |

价格和库存来自平台数据；商品名称/描述应支持换行，避免长昵称把按钮撑出屏幕。移动端一列为主、留触控间距，关键按钮至少约 44 像素可点击区域。保留游戏风格，不为 SDK 接入强制重画整套 UI。

## 每个交互需要的状态

待操作 → 等待登录（如需）→ 平台确认/处理中 → 成功或可恢复失败。处理中禁用重复点击且保持布局尺寸。成功说明“购买到账”“已使用”“成绩已提交”中的实际一种；它们不是同一状态。组合流程购买后使用失败应显示“已购买，使用尚未完成，请重试恢复”，不要让玩家再次购买。

取消返回原选择；余额不足保留进度并提供充值/返回；未知结果显示“正在核实/请查询订单”，不能显示成功也不能反复扣款。缺功能时说明未开通，不展示能点击但无反应的入口。

## 暂停和音频

下列适配节点需要持续存在；结合项目现有暂停管理器使用，不要同时存在两套相互覆盖的处理器。Master 静音示例适用于单一主音频总线；复杂项目保存自身总线状态。例子不把 resume 当交易成功。

```gdscript
extends Node
var previous_pause := false
var previous_mute := false
var platform_paused := false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    if not INeed.platform_event.is_connected(_on_platform_event):
        INeed.platform_event.connect(_on_platform_event)

func _on_platform_event(name: String, _data: Dictionary) -> void:
    if name == "pause" and not platform_paused:
        previous_pause = get_tree().paused
        previous_mute = AudioServer.is_bus_mute(0)
        platform_paused = true
        get_tree().paused = true
        AudioServer.set_bus_mute(0, true)
    elif name == "resume" and platform_paused:
        get_tree().paused = previous_pause
        AudioServer.set_bus_mute(0, previous_mute)
        platform_paused = false
```

账号切换用游戏的统一身份管理器处理。Node 退出时 Godot 会清理该对象的信号连接；Autoload 不重复创建。平台弹窗期间避免切换并释放唯一的恢复节点。

## 手机和内嵌浏览器

登录/支付入口由真实点击触发。当前页登录跳转可能重载游戏，提前持久化可恢复进度。返回重新初始化，不自动重复消费。QQ/微信与系统浏览器分别测试；桌面模拟 UA 不等于真机验收。

## 字体和资源

动态昵称、商品名称、错误提示都必须有字体覆盖及默认占位。保留字体许可证；按需加载头像并控制缓存，不每帧重新请求。启动阶段区分下载、引擎初始化和平台连接，不把全部时间写成“正在加载”。参见[资源访问验收](../packaging/validation.md)。
