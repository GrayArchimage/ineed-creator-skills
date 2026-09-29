# iNeed Creator Skills

将 Release 中 `ineed-creator.zip` 解压成一个 `ineed-creator` 技能目录，给创作者 AI 阅读其中的 `SKILL.md`。总入口会识别引擎并按需读取子技能。Godot 首版范围：Godot 4.3+、GDScript、单线程 Web、Compatibility 渲染器。Unity 暂缓。

仓库维护技能和稳定 Godot 插件；平台维护动态运行时。平台升级现有能力无需重新导出游戏。新增玩法事件或游戏自绘界面需要重新导出。

版本、功能边界见 [目录](ineed-creator/catalog.json)，开发约束见 [兼容规则](AGENTS.md)。构建：`python3 ineed-creator/scripts/build_bundle.py`。不要将创作者源码、商业素材、凭据或平台内部运维技能加入本仓库。

## 可抓取的静态文档库

阅读入口：[创作者文档](https://ineeds.club/creator-skills/index.html)。无需登录或 JavaScript 即可遍历全文；每页提供原始 Markdown，另有 `llms.txt`、`llms-full.txt` 和 `sitemap.xml`。网页没有第三方字体、跟踪器或前端框架。

- 内容源：`ineed-creator/**/*.md`，分类与页面登记：`docs-nav.json`。
- 页面模板：`scripts/build_site.py`；样式/搜索：`web/assets/`。
- 完整 Skill ZIP 包含插件、脚本和示例；Markdown ZIP 只供阅读。
- 版本修改 `ineed-creator/catalog.json`；插件和冻结协议不因文档更新改变。

```sh
python3 -m venv .docs-venv
.docs-venv/bin/pip install -r requirements-docs.txt
.docs-venv/bin/python scripts/build_site.py
.docs-venv/bin/python scripts/check_source_links.py
.docs-venv/bin/python scripts/check_archives.py
.docs-venv/bin/python scripts/check_site.py
.docs-venv/bin/python scripts/package_site.py
python3 -m http.server 18772 --bind 127.0.0.1 --directory site
```

输出 `site/` 可部署到静态服务器；所有站内链接相对寻址。需要换正式域名时修改 `docs-nav.json` 的 `baseUrl` 后重建，不能只搬文件而留下错误 canonical / sitemap。完整包下载沿用平台公开下载地址，历史固定包见 GitHub Release。

平台维护者还需运行 `scripts/check_platform_policy.py <平台仓库>` 检查格式与容量契约，再执行 `scripts/vendor_platform.py <平台仓库>` 固定附带同一制品。仅复制脚本不会部署；平台上线继续走既有 Jenkins 发布流程。新增文档保持旧 URL 和锚点可用；必要时添加兼容页/重定向，不能因整理目录直接删除已发布链接。

## 开发文档与 SDK

- [Godot 接口手册](https://ineeds.club/creator-skills/godot-api.html)：参数、返回值、购买与消耗包装器。
- [完整开发流程](https://ineeds.club/creator-skills/development-workflow.html)：工程检查、提问清单、界面分工与平台交接。
- [商品购买与消耗](https://ineeds.club/creator-skills/payments.html)：未登录先登录、只购买、只消耗、组合流程和失败恢复。
- [插件源代码](ineed-creator/skills/engines/godot/plugin/ineed.gd)；[最小工程](ineed-creator/skills/engines/godot/example)。

插件商业流程测试（隔离内存夹具，不连接线上）：

```sh
godot --headless --path ineed-creator/skills/engines/godot/example --script "$PWD/scripts/test_godot_commerce.gd"
```
