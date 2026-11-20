# Damage Workbench v0.3.10

Fixed a live ranged-attack error caused by reading the ammo counter through the wrong DB overload. The attack wrapper now reads the full value path and handles serialized before-count metadata.

Updated English/Turkish usage guides, current test evidence and compatibility limits. Added Forge/forum drafts, a labelled illustrative cover and native screenshots of Auto Apply, x2 and the Confirm HIT ammunition notice.

Validation: 31 automated tests passed. Live FG 5.1.15 GM/player testing covered native Longbow attacks, six critical weapon/Sneak Attack dice, Undo audit delivery, manual Apply, player Auto Apply, matching chat totals and persisted player preference. Inventory-stack ammunition integrations and exhaustive 2014/2024 feature coverage are not certified.

Assets: DamageWorkbench.ext, DamageWorkbench-Source.zip and SHA256SUMS.txt. Forge must use this exact public release extension asset.
