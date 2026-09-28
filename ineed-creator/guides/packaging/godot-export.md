# Godot Web 导出设置

## 平台支持组合

Godot 4.3+，GDScript，Compatibility 渲染器，单线程 Web。编辑器与官方 Web 导出模板版本匹配。其他组合先明确标注未支持或未验证，不自动修改项目引擎版本。

| 项目 | 设置或建议 |
|---|---|
| 导出目标 | Web |
| 导出路径 | 新目录中的 index.html |
| 渲染器 | Compatibility / gl_compatibility |
| Thread Support | 关闭 |
| Extensions Support | 关闭 |
| 导出模板 | 与编辑器版本完全匹配的单线程模板 |
| PWA / Service Worker | 首次接入建议关闭；托管沙箱下不能承诺离线或 SW 可用 |
| 自定义 HTML shell | 用于持久化 shell 改动，避免下次导出丢失 |

## 必须保留的产物

保留本次生成的 HTML、JS、WASM、PCK 及实际引用的 worklet、图标等文件。不要把名字不同但看起来相似的其他项目产物拼进去。压缩、路径、字体和[大小限制](limits.md)分别检查。

## 插件和玩法

先按 [Godot Skill](../../skills/engines/godot/SKILL.md)安装插件、初始化协商，再把登录、商品、榜单、存档、广告绑定到真实事件。只导出成功不能证明接入完成。只有成品包时不能承诺已修改内部结算与奖励逻辑。

## 浏览器差异

浏览器需要 WebAssembly 和 WebGL 2.0。输入、音频、全屏、存储和后台暂停受浏览器约束；UDP/ENet 原生网络不能直接搬到 Web。`user://` 持久化不等于平台云存档，平台插件不透明接管所有文件。

横屏设计应验证手机横竖屏和触控目标；浏览器模拟尺寸不是实体手机验收。微信等内嵌浏览器中的登录返回、支付返回与音频恢复需实测。

[Godot 官方 Web 导出文档](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html)提供引擎层面的限制说明。平台支持范围以上表及当前能力协商为准；不因引擎增加新特性就自动扩大平台承诺。
