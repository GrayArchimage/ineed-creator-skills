# iNeed Creator Skills

将 Release 中 `ineed-creator.zip` 解压成一个 `ineed-creator` 技能目录，给创作者 AI 阅读其中的 `SKILL.md`。总入口会识别引擎并按需读取子技能。Godot 首版范围：Godot 4.3+、GDScript、单线程 Web、Compatibility 渲染器。Unity 暂缓。

仓库维护技能和稳定 Godot 插件；平台维护动态运行时。平台升级现有能力无需重新导出游戏。新增玩法事件或游戏自绘界面需要重新导出。

版本、功能边界见 [目录](ineed-creator/catalog.json)，开发约束见 [兼容规则](AGENTS.md)。构建：`python3 ineed-creator/scripts/build_bundle.py`。不要将创作者源码、商业素材、凭据或平台内部运维技能加入本仓库。
