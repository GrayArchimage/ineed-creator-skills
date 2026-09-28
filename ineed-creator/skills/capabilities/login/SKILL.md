---
name: ineed-login
description: 接入匿名进入和按需登录。
---
# 登录

默认匿名进入，需要账号时 `login`。平台负责验证和返回恢复。`account.get` 获取账号；`account.changed` 后清除旧账户缓存和待提交数据，不把旧请求结果应用到新账号。登录成功不是购买成功。未登录时云存档/排名写入明确返回 AUTH_REQUIRED。
