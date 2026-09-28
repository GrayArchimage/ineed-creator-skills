---
name: ineed-packaging
description: 校验托管包及导出产物资源访问风险。
---
# 打包和产物检查

导出到新目录，源工程保留。只打包静态运行必需文件，ZIP 根有 index.html；保持资源相对路径和文件名。平台不会执行 Python、BAT、htaccess。保留原 ZIP 作为审计输入；不上传编辑器缓存、密钥、源工程或未使用资产。

存储总量 50 MiB；Godot 资源解压后单文件及总量 128 MiB；gzip/br 必须匹配 Content-Encoding，WASM MIME application/wasm，pck application/octet-stream。有界解压，限制文件数、防目录穿越。不通过放宽主站同源沙箱修复游戏。

运行导出包，测试首载、返回、重新开局和重新加载；记录每个 URL、次数、transferSize、encodedBodySize、decodedBodySize、缓存命中、错误和重试。重复请求不等同重复网络下载，区分缓存与实际传输。网络观察无法证明所有潜在行为安全。

检查外链、追踪、挖矿/高资源占用、密钥、跨域请求、反复下载 WASM/PCK、循环重试。内容审查记录具体画面、文本、音频和来源证据；仅凭文件名不判违法。对授权不明的 IP/音乐/字体明确列出待核验依据，交平台审核决定。不要声称只运行一次就全面合规。
