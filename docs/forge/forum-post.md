# [5E] Damage Workbench — editable weapon and cantrip damage

Published thread: [Damage Workbench](https://www.fantasygrounds.com/forums/showthread.php?88612). First three posts by **morfil**: introduction **775977**, usage/all Settings **775978**, release/support **775979**. This file is repository source copy, not a verbatim export of the rich-text posts.

[Forge item 3793 — Live](https://forge.fantasygrounds.com/shop/items/3793/view). As of **2026-11-20**, the item is approved and **ACTIVE/listed**, with v0.3.11 **build #1 on Live**, verified by the publication coordinator. An independent end-to-end Updater download has not been tested. The coordinator maintains the published forum posts.

Damage Workbench opens an editable damage panel after PC weapon hits and damaging cantrips. Adjust damage types and dice, add damage effects, then roll. Auto Apply is enabled by default; turn it off when you want to inspect results, reroll, Undo, or choose x2 before applying damage.

Highlights:

- Critical and Non-critical sections, compact dice groups, and horizontal wheel scrolling.
- Drag-and-drop damage actions and conditional DMG effects, including Sneak Attack and Smite.
- Per-die auto-reroll thresholds and saved Quick Action layouts.
- Private Undo audit messages for the GM and roller.
- Per-user on/off preference, changeable during play.
- Native used-ammo tracking without a second charge on Apply.

Try `/dwb demo` to explore safely. The GM can require Confirm HIT before the owner's panel opens. Each user can select classic FG behavior with `/dwb off`.

**Current release: v0.3.11.** Tested with FG Unity 5.1.15 and the native 5E action pipeline. This is for PC weapons and cantrips; general levelled-spell and NPC attack interception are outside scope. Separate exhaustive 2014/2024 class-feature coverage and inventory-stack ammunition integrations are not certified. The verification record lists the actual tests and limits.

Download: https://github.com/alperozisik/FG-Damage-Workbench/releases/latest

Usage and screenshots: https://github.com/alperozisik/FG-Damage-Workbench#readme

Tests: https://github.com/alperozisik/FG-Damage-Workbench/blob/main/TESTING.md

Changelog: https://github.com/alperozisik/FG-Damage-Workbench/blob/main/CHANGELOG.md

Issues: https://github.com/alperozisik/FG-Damage-Workbench/issues

When reporting a problem, include the DWB/FG/ruleset versions, enabled extensions, GM or player role, the action and target type, and steps to reproduce. Use synthetic data or redact campaign details before attaching logs or images.

MIT licensed. GitHub downloads are available now. The approved Forge item is active/listed with build #1 on Live; independent end-to-end Updater delivery testing remains outstanding.
