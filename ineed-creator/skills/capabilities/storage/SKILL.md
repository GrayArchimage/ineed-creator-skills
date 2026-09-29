---
name: ineed-storage
description: 将游戏已有 JSON 保存入口接入版本化存档，处理 1 MiB 限制、游客隔离、账号切换与冲突恢复。
---
# 存档

先检查游戏现有保存入口和格式，明确要同步的字段。SDK 不会透明上传全部 user:// 文件，不存图片、缓存、日志和平台凭据。

## 需要确认

必填：哪些字段、何时读取/保存、schemaVersion、冲突怎么让用户选择。可选：手动备份、游客进度导入、自动保存频率。保留原存档语义，不能借接入进行无授权的格式迁移。

## 读取与提交

1. 初始化及身份确定后 request("storage.load")，成功 value 是 `{value,version,schemaVersion,scope}`。首次 value=null、version=0 是正常空档，不当成损坏。
2. 校验 schemaVersion 和游戏字段，再应用；不认识的新版本保留原数据并停止覆盖。
3. 保存前冻结 JSON 快照，用读取的 version 作为 baseVersion，提交 `{value,baseVersion,schemaVersion}`。
4. 保存成功更新本地 version，显示已保存；保存响应至少含 version/scope，不依赖必有 value。
5. 串行或合并自动保存请求，避免每帧保存、多个异步写覆盖；保留最后确认版本和未保存的本地草稿。

```gdscript
func load_platform_save() -> Dictionary:
    return await INeed.request("storage.load")

func save_platform_value(snapshot: Dictionary, base_version: int) -> Dictionary:
    return await INeed.request("storage.save", {
        "value": snapshot, "baseVersion": base_version, "schemaVersion": 1
    })
```

## 身份与环境

guest 为游客浏览器独立本地槽，preview 为预览独立槽，account 为登录后的云档。游客槽受浏览器清理影响，不能承诺永久保存。登录后先加载账号档；想导入游客进度必须让玩家明确选择，并以账号当前 version 保存，不能自动覆盖已有账号档。

账号变化时丢弃旧账号的界面缓存并重新 load；旧请求即便成功也不能应用到新账号。平台云档与旧 JS SDK 使用的键共存；不要删除整个存储映射。

## 冲突和体积

STORAGE_CONFLICT：保留本地待保存草稿，重新 load 云档，显示两份摘要供选择，或按创作者已确认的领域规则合并；不能“换最新 version 然后自动覆盖”。存档中含奖励回执时，冲突不能导致奖励再次发放。

1 MiB 是平台总限制，不是游戏字段的可用净空间；JSON 包装、编码及既有键有开销。尽量保存紧凑状态，留足余量，并以服务器结果为准。STORAGE_TOO_LARGE 时保留本地草稿，提示缩减非必要数据。TIMEOUT 时先重读确认版本，不能无限重复 PUT。

## 验收

空档、新档、旧格式恢复、同账号重开、账号 A/B 隔离、游客显式导入、两个标签页冲突、超限、断网和保存后刷新。交付字段定义、schemaVersion、入口、scope 和冲突处理截图；接口细节见[接口手册](../../../guides/integration/api.md)。
