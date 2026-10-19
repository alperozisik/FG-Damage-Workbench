# Damage Workbench

A campaign-independent Fantasy Grounds Unity extension for 5E. Review weapon and
cantrip damage after a confirmed hit, roll privately, reroll individual dice, then
commit through the native 5E damage system.

Licensed under the [MIT License](LICENSE). The build scripts produce local
packages and never upload them. [Türkçe kullanım](README.tr.md).

## Install

1. Run `python tools/build.py`.
2. Copy `dist/DamageWorkbench.ext` into your Fantasy Grounds data `extensions` folder.
3. Enable **Damage Workbench** in a separate test campaign first.
4. Set **Options → Damage Workbench → Confirm hits before damage adjustment** to
   **Ask GM** (default) or **Automatic**.

Requires the 2026 CoreRPG/5E action and effect APIs. The development baseline is
FGU 5.1.14, 5E/CoreRPG rulesets dated 2026-10-06. Other rulesets are not supported.

## Per-user switch

Options → Damage Workbench → **Use Damage Workbench (this user)**: On/Off.
Each client saves this choice locally in FG's CampaignRegistry for the campaign;
it is not a shared GM option. `/dwb on` and `/dwb off` change the same setting.
Changes are sent to the host immediately, as well as on connection/reload.
An online character owner's choice controls their attacks and cantrip damage;
unowned/offline-owned characters use the GM's local choice. Unsynchronized
clients use classic behavior until their preference arrives.

Off leaves the native attack/save/damage workflow intact and stops new DWB
requests. Turning it off also dismisses that user's unconfirmed GM approvals.
Already prepared/rolled damage remains available to finish or reopen, so changing
the preference does not discard a pending throw. The default is On.

## Workflow

A successful PC weapon attack or a failed save against a damaging cantrip creates
an in-memory request. In Ask GM mode, resolve any late modifiers before confirming
the hit. Only confirmation publishes the additional HIT announcement and opens
the owner's adjustment panel.

In 0.3.2, directly activating a cantrip damage action with a selected target,
or dropping that action onto a target, also creates a request. A drop does not
require a preselected target. The exact damage variant is retained and evaluated
through native PowerManager; an existing request for that action/target is reused.
An untargeted double-click continues through the classic FG flow.

- Unlock to edit damage types. Types cannot repeat within the same group.
- Damage dice are stably sorted by die size. Results keep that order, with
  critical copies next to their original dice. Adjacent selections connect.
- Drop desktop dice into a type. Drop a power's damage action anywhere to add its
  clauses. Left-click selects dice within one type. Right-click a die and choose
  Delete dice to remove it or its selection. Ctrl + left-click
  immediately removes the clicked die or its selection, without a menu.
  Drag selected dice between types.
- Fixed values occupy the first cell. Edit directly, or use Ctrl + mouse wheel.
- Critical doubles eligible dice, while fixed damage moves to Non-critical.
  Switching Critical off merges the groups; switching it on again reclassifies
  their dice as critical-eligible.
- Magical starts from the original weapon/spell action. Later drops do not change it.
- Roll uses the native 3D dice system without publishing a chat result. Results
  stay in the panel. Undo discards the entire throw and returns to dice setup,
  including after a reroll; the turn's reroll count is preserved.
- Double-click one result die and confirm to reroll. The prompt includes the
  actor's reroll count for the current combat turn. The new value replaces the
  old value; there is no history to restore an earlier individual die result.
- Apply publishes the accepted dice and invokes the installed native result and
  health hooks. Resistance, immunity, critical immunity, wards, concentration,
  and compatible damage Undo integrations remain in that pipeline.

The upper dice cards and lower result cards have separate borders. Critical and
Non-critical headings belong to their respective areas, with a compact add
button for each area. Type dropdowns are bounded to eight visible rows. Magical
changes only its value without recreating the dice controls.

Apply resolves the accepted values directly, avoiding a second post-roll
transformation after the player has reviewed them. Raw chat dice and totals must
match the panel; target defenses may then reduce actual wounds.

Save is available during setup and in results; it saves the layout, not rolled
values. Right-click opens the Delete dice context menu during dice setup;
choosing it deletes immediately without another confirmation.

Every close before Apply adds a local chat reminder with a reopen link and
`/dwb` instructions. Other users receive no reminder. Closing applies no damage;
unrolled local edits are retained for reopening.
Requests and reroll counters are session memory; restarting/reloading clears
them. Only opaque request ids for native chat links have temporary DB records;
rolled values and pending layouts are not persisted. A saved layout is separate: Save opens a named drag handle for Quick Actions.
Dropping/activating it replaces an open unrolled plan's entire layout. Activating
it without a panel prints a usage message.

## Damage effect drops

Drop an effect action from the character's Actions sheet or an effect entry into
an unrolled panel. The host evaluates its DMG components for this attack's source,
target, weapon/spell and melee/ranged filters. Native effect expression and
conditional APIs handle variables, `{_expression_}` math, IF/IFT, ELSE and the
condition checks registered by installed extensions. No effect is added to the
combat tracker and unrelated active DMG effects are not added a second time.

`DMG: 2d6 weapon` inherits the weapon's damage type. For
`DMG: 2d8 radiant, melee; IFT: TYPE(undead, fiend); DMG: 1d8 radiant, melee`,
a melee hit adds 2d8 radiant against a humanoid or 3d8 against a fiend/undead.
Critical classifies new eligible dice without moving manually placed
Non-critical dice. Every added die remains editable and removable.

Drop the caster's actual effect action when using UPCAST. Its power context is
preserved when available; an unresolved UPCAST expression without a unique
source action is rejected rather than guessed. With UPCAST=2,
`DMG: {_[UPCAST]+2_}d6 radiant` adds 4d6 radiant. The exact installed modules
provide their effect text; installed ruleset/extension APIs evaluate that text.

There are no automatic class-feature additions or optional-damage dropdown.
Players add Smite, Sneak Attack and similar bonuses explicitly. The workbench
does not spend spell slots or activate concentration for a dropped DMG effect;
those remain in the character's normal spell/effect workflow. Conditions are
sampled on drop for this pending target; resolve a fresh drop if its state changes.

## Development and tests

```text
python -m pip install -r requirements-dev.txt
python -m unittest discover -s tests -p "test_*.py" -v
python tools/build.py
```

`python tools/build.py --source` also builds a clean, allow-listed source ZIP for
later review or publication. It excludes all local references and campaign data.

`tools/sandbox.py --data <FG data folder> --source <source campaign folder>`
creates a new, explicitly named local sandbox with private character copies and
a training target. It refuses to overwrite an existing sandbox. It records hashes
of the source campaign and never writes to that campaign.

`python tools/build.py --test-harness` produces a separate development package.
Its `/dwbtest` commands refuse to operate without the explicitly named training
target. Release builds never include the harness. See [TESTING.md](TESTING.md)
for the verification record and remaining coverage.

`.reference/`, `.private/`, dependencies, builds, and private campaign fixtures are
excluded by `.gitignore`. The release extension contains original Lua/XML only;
it redistributes no ruleset, paid module, or third-party extension code or artwork.
The small connected-selection PNG segments are original UI assets.

## Scope boundaries

Class damage is effect-driven and explicitly added by the player. The workbench
does not infer eligibility from feature names, adjacency, flanking, edition or
spell-slot availability. Custom/signed dice outside the supported standard
positive dice are rejected instead of being silently omitted.

The panel uses native 2D die icons and number overlays; configured damage-type
skins are used by the 3D throw. The full 3D skin artwork is not reproduced inside
the 2D editing cells. A horizontal track below the cards supports continuous pixel scrolling, by
moving the thumb, clicking the track or using the wheel. It moves the existing
cards inside a clipped viewport; no pagination arrows are used.

Source code and original UI assets are distributed under the MIT License.
