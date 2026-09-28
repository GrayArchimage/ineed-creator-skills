# 0.1.0 — 2026-09-28 (preview)

- Single creator skill entry routes to web, Godot and capability skills.
- Godot 4.3+ GDScript, single-thread Web stable protocol-v1 bridge and minimal example.
- Login, commerce, regional leaderboards, verified rewarded-ad receipts and explicit versioned storage contracts.
- Data-only and platform-UI integration paths; capability negotiation and explicit unsupported errors.
- Idempotent install and deterministic versioned ZIP distribution.

Compatibility: first baseline; protocol-v1 and old JavaScript SDK semantics are additive. Runtime 1.0.0 and 1.0.1 compatibility fixtures pass. Existing games do not need a new package for updates to already-bound platform services. New gameplay hooks and native game UI changes still require export.

Platform deployment is separate. Real advertising requires a configured server-verified provider and the additive receipt ledger. Missing production configuration is not simulated success. The public bundle does not contain platform credentials, internal operations skills, creator game assets or source.
