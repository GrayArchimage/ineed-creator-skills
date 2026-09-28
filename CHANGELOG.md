# v0.1.3

新增“与 iNeed 沟通”分类、配置交接单和入口验收要求，总入口与引擎技能显式路由。SDK 0.1.0、协议 v1 和旧页面路径不变。兼容结论：仅新增说明和相对引用，不改变既有 API、默认值、存档与支付/奖励语义。

# 0.1.1 — 2026-09-28 (preview)

- Bundle an OFL-licensed CJK font for the minimal Godot example so Chinese product names and nicknames render without relying on system fonts.
- Document font coverage and package-size checks for native game UI.

Compatibility: protocol v1, plugin 0.1.0 and all API/error/payment/reward/storage semantics are unchanged. Existing game ZIPs do not need this skill/example update. v0.1.0 remains available.

# 0.1.0 — 2026-09-28 (preview)

- Single creator skill entry routes to web, Godot and capability skills.
- Godot 4.3+ GDScript, single-thread Web stable protocol-v1 bridge and minimal example.
- Login, commerce, regional leaderboards, verified rewarded-ad receipts and explicit versioned storage contracts.
- Data-only and platform-UI integration paths; capability negotiation and explicit unsupported errors.
- Idempotent install and deterministic versioned ZIP distribution.

Compatibility: first baseline; protocol-v1 and old JavaScript SDK semantics are additive. Runtime 1.0.0 and 1.0.1 compatibility fixtures pass. Existing games do not need a new package for updates to already-bound platform services. New gameplay hooks and native game UI changes still require export.

Platform deployment is separate. Real advertising requires a configured server-verified provider and the additive receipt ledger. Missing production configuration is not simulated success. The public bundle does not contain platform credentials, internal operations skills, creator game assets or source.
