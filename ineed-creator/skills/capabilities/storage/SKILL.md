---
name: ineed-storage
description: 将真实保存入口接入显式版本化云存档。
---
# 存档

`storage.load` 返回 value/version；`storage.save` 提交 value/baseVersion/schemaVersion。复用现有云存档，保留 1 MiB 总限制。冲突返回 STORAGE_CONFLICT，提示选择或显式合并，不能自动覆盖或偷偷迁移格式。

游客与账户隔离；匿名使用独立本地槽位，不自动上云合并。账号改变重新载入。绑定已有保存入口，仅同步约定的数据；不能承诺透明接管所有 user://。预览环境不写正式账号云档。
