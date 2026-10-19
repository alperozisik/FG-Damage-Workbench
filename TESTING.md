# Verification record — 2026-10-19

This is a local 0.3.4 implementation. The tables distinguish executed tests from
items that still require acceptance testing. Tests use a separate local sandbox.

## Native documentation capture — 0.3.4

On 2026-10-19, the current demo panel was opened in Damage_Workbench_Sandbox.
Pointer input worked after correcting a stale screenshot-state reference in the
automation session. The earlier input errors below describe previous attempts.

Observed the initially locked native toolbar, clicked it to unlock the type
list, and clicked Critical to separate eligible dice from the fixed bonus.
Clicked Roll and waited for native dice to settle: piercing 1+3=4, radiant
4+6+6+8=24, and the non-critical fixed bonus 5 produced a total of 33.
Setup and results occupied separate cards with Undo between them. Save remained
visible after rolling and opened the layout-name and draggable-handle dialog.
Cropped captures are embedded in both usage guides under docs/screenshots/.

This targetless demo intentionally disables Apply. It does not verify target
health changes, separate-player transport, pointer drag/drop or wheel panning.

## 0.3.4 compact results spacing

The upper card ends 12 pixels before Undo; a further 12 pixels separates Undo
from the results or critical section heading. The separate result cards retain
their existing size. The results height is 760 pixels without critical headings,
814 with them, instead of 874. Status and Apply/Save move up with the window.
Native demo visual acceptance is recorded above; the earlier Windows input
issue is recorded under 0.3.3 below.

## 0.3.3 compact layout and wheel panning

Seventeen model/compilation tests passed. The new scrollbar regression checks
linear drag movement, no drift with a stationary pointer, both travel limits
and forwarding wheel input to the panel. The native toolbar toggle supplies
theme frames/icons and starts locked; it edits only the damage-type list.
Confirm Hit uses 230 pixels for one row and grows with additional requests.
The edit panel is 520 pixels high, with Critical and context sharing a row.
Native pointer acceptance remains unverified: FG launched, but the control tool
returned `foreground window did not report a process id` on the My Campaigns
click. No campaign was opened or changed during this attempt. The native theme
appearance, wheel routing over live controls and track/disabled-thumb hit testing
still require in-app acceptance.

## 0.3.2 direct cantrip targeting

Sixteen model/compilation tests passed. New regression checks direct damage
with an explicit drop target, exact damage-action selection, native evalAction,
pending-request reuse, disabled-user bypass, untargeted fallback, committed-roll
bypass and client-to-host request metadata. Interception uses the native
onActionPostTargeting event, before effects and dice are consumed.
`/dwbtest directcantrip` was added for sandbox acceptance testing, but was not
executed: the Windows control tool returned `foreground window did not report
a process id` when attempting to open My Campaigns. Real pointer drag/drop and
separate-client execution of this change remain unverified.

## 0.3.1 user preference checks

Fifteen model/compilation tests passed. Preference coverage includes independent
Alice/Bob/GM values, owner routing, disconnect/reconnect synchronization queries,
immediate client option-change announcements and bypassing request creation for
disabled users. The option uses FG's native bLocal/CampaignRegistry storage.
Late automatic-open responses are ignored after the user switches Off.
Native `/dwbtest prefs` passed: Off kept the normal attack without queuing DWB,
On queued an approval, and switching Off removed unconfirmed approvals.
After `/dwb off` and `/reload`, the sandbox CampaignRegistry.lua contained
`OptDWB_ENABLED = "off"`. A post-reload in-app assertion could not be run:
the UI control tool twice returned `foreground window did not report a process id`
after refreshing the window binding. The sandbox was left with DWB Off.
A separate player connection remains unverified end to end.

## 0.3.0 current checks

Fourteen model/compilation tests passed. The older automatic-class-feature
cases were retired because feature inference and suggestions were removed.
A new regression ensures appended damage never moves manual Non-critical dice.

Native `/dwbtest suite` passed UI callbacks, effect drops and exact Apply:
- Native DMG parsing preserves weapon/radiant types and melee filters.
- Divine Smite adds 2d8 against humanoid and 3d8 against fiend/undead.
- Native ELSE, AND and inverted conditionals are evaluated.
- Native UPCAST=2 with `{_[UPCAST]+2_}d6 radiant` yields 4d6.
- The real effect drag decoder and host import path run without adding a CT effect.
- No automatic class damage or optional-damage suggestions are supplied.
- A 37-pixel scroll retains all control identities; track/drag callbacks work.
- Repeated unapplied closes call local chat only, with one reminder per close.
- Reroll → Undo → Roll → reroll → Apply retains Save and produces the same
  accepted panel/chat/native dice and 51 wounds.

Real pointer clicks on the horizontal track and dragging its thumb moved the
clipped cards continuously. Real top-right X produced the local reminder.
The old session-id shortcut did not resolve a native window data source; it was
replaced with an opaque session-link DB record containing only the request id.
No damage plan is persisted. The link mapping is cleared at reload and its
record is removed after Apply. Other users receive no closure chat message.
The updated native suite passed again, including opening the real chat-link
window class. Real pointer clicks on both the initial reference and the new
close reminder reopened the same unapplied panel with its edited layout.

Physical effect dragging from an Actions sheet and a separate connected player
client remain unverified; serialized native drag callbacks and evaluation were
executed with Advanced Effects, Equipped Effects and BCE Gold loaded. Older
verification sections below describe the version named in each section.

## Environment

Windows; Fantasy Grounds Unity 5.1.14 (2026-10-17); 5E and CoreRPG rulesets
2026-10-06. The Updater completed with 262 products up to date. All Fantasy
Grounds clients were closed while it ran.

Tests used a separate `Damage_Workbench_Sandbox` campaign with private character
copies and an explicitly named training target. The original campaign was not
opened or written by the test harness. Campaign content and console logs stay
private and are excluded from the package and source archive.

## Automated Lua/model tests

`python tests/test_model.py`: **17 tests passed**, using Lua 5.4 through lupa 2.8.

Coverage includes critical toggling and fixed-value redistribution, non-critical
dice, critical tags, Piercer's extra die, selection/move/delete, unique types,
blank-type validation, invalid results, irreversible rerolls, preset replacement,
declarative slot choices, unsupported-die rejection without partial imports,
native roll flags, feature precedence, duplicate-effect suppression, Blessed
Strikes cadence, Improved Divine Smite, Sneak Attack cadence and Surprised.
Every runtime, development harness and inline XML Lua script compiles.

## Actual Fantasy Grounds tests

| Test | Result |
| --- | --- |
| Load with only Damage Workbench | Passed |
| Load with Advanced Effects 8.0, Equipped Effects 1.100, BCE Gold 7.6, Requested Rolls 2.2.2 and 5e Undo 1.4.2 together | Passed |
| Native weapon attack queues GM approval | Passed |
| Confirm announces HIT and opens the adjustment panel | Passed |
| Closing and using the chat reference reopens session-only damage | Passed |
| Private animated 3D throw, results remain out of chat until Apply | Passed by UI observation |
| Damage-type 3D skin and green critical result dice | Observed |
| Undo restores the original editing state | Passed by UI observation |
| Confirmed single-die reroll updates total and disables Undo | Passed by UI observation |
| Fixed-value direct editing and die selection outline | Observed |
| Active native DMG effects enter the plan | Passed by native harness |
| Preview leaves single-use effects intact; Apply consumes them | Passed by native harness |
| Blessed Strikes selected from Abilities, suppresses Divine Strike | Passed |
| Blessed Strikes blocked until next own turn, then resets | Passed |
| Improved Divine Smite added to melee weapon | Passed |
| Failed damaging-cantrip save creates magical plan | Passed |
| Native natural critical state survives preparation | Passed |
| Resistance and immunity: 10 raw becomes 6 actual wounds | Passed through native damage application |
| Critical immunity removes critical dice before resistance | Passed; expected 4 wounds |
| Duplicate Apply dispatches native damage once | Passed |
| Saved layout cannot reuse a spent turn-limited feature | Passed |
| Saved Divine Smite validates slots at Roll, spends one at Apply | Passed |
| Actual window save/drop/hotkey callbacks with serialized drag records | Passed |
| Callback preset replacement includes critical, magical and all zones | Passed |
| Preset activation without an open panel only prints usage | Passed |

The native deterministic suite temporarily replaces the 3D throw with values of
2 and routes the asynchronous damage notification synchronously into the real
native damage handler. Both functions are restored even if an assertion fails.
This checks damage arithmetic and hooks; it does not replace the separate real
animated-dice checks above.

Reproduction: create a fresh private sandbox with `tools/sandbox.py`, build with
`--test-harness`, enable it in that sandbox, then run `/dwbtest suite`,
`/dwbtest ui` and `/dwbtest exact`. Never distribute or enable that development package for live play.
The commands refuse to operate without the explicitly named training fixture.
Release packages exclude the harness entirely.

### 0.1.1 UI correction checks

The 14 model/compilation tests still pass. In the actual FG sandbox, the window
callback suite also passed with the DTZ edit lock closed: dropping dice over a
fixed-value cell adds dice without changing the fixed modifier, and dropping
over the dice list routes into that DTZ. Native window-menu close buttons and
inventory add/delete templates replace the custom text buttons. Padding and
vertical centering of the green add icon were checked in the running UI.
These callback checks do not certify physical mouse delivery by the Windows
automation tool; that limitation listed below still applies.

At the end of the earlier 0.1.1 work, all 33 recorded top-level source-campaign
file hashes matched that run's initial baseline. This historical check does not
cover the user's subsequent manual campaign testing.

### 0.2.0 correction checks

The 17 model/compilation tests include stable die ordering, canonical accepted
values, compact group widths with independent add buttons, and connected
selection segments. In the actual FG sandbox with all six extensions enabled,
`/dwbtest exact` passed: mixed d6/d8/d20 dice, critical copies and a single-die
reroll produced identical individual accepted/native/chat values and a total of
51; native wounds also increased by 51 on the undefended target. No post-roll
handler ran a second time at Apply. The existing native suite passed again,
including resistance, immunity, critical immunity and resource consumption.

The UI callback suite confirmed that Magical preserves the exact DTZ control
instances, dice drops work with type editing locked, selected dice move, and
presets replace the entire layout. FG reserves the right button for its context
menu; deletion uses its native Delete dice menu, not a fabricated button-2
click event (button 2 is the middle button).

See the [FG control API](https://fantasygroundsunity.atlassian.net/wiki/spaces/FGCP/pages/996644833)
for that mouse-button boundary. Release packages exclude the development harness.

Physical pointer checks in the running 0.2.0 UI also passed: the die context
menu shows Delete dice without Close Window and deletes a die; adjacent selected
dice form one continuous highlight; the eight-row dropdown scrolls internally
without shifting the card; Critical and Non-critical have external headings
and small centered add icons. A real animated critical throw displayed separate
upper dice and lower result frames aligned in the same columns, with Undo in
the gap. The themed top-right X closed the panel successfully.

## 0.2.2 context menu restoration

Restored Delete dice on setup die faces at radial menu slot 6, with the native
onMenuSelection callback routed to selection-aware deletion. Result dice and
fixed values do not register this menu. No additional confirmation is shown.
The 17 model/compilation tests passed. The native UI harness now exercises the
menu callback rather than calling panel removal directly; this updated harness
has not yet been run inside FG. Earlier 0.2.1 menu removal notes are historical.

## 0.2.1 correction checks

The 17 model/compilation tests passed again. Native `/dwbtest ui` additionally
invoked the real combo's `onOptionClicked` for poison and fire while Critical
was enabled. The DTZ host and dropdown remained alive until the callback
completed. Real pointer selection of both poison and fire in a newly added
Critical DTZ also passed with no console errors. The earlier error was caused
by rebuilding the panel inside the native combo's selection callback; native
code then tried to hide a control whose Lua context had already been destroyed.

Native `/dwbtest exact` passed the reroll → Undo → Roll → reroll → Apply flow.
Undo clears the whole result set and returns to setup, preserves the turn's
reroll count, and does not restore a prior individual die value. The result
screen's Undo is enabled and Save is visible and opens its dialog. Accepted
panel/chat/native values and 51 wounds still match.

The requested direct right-click delete is **not implemented**. The native
control engine consumes the right button before invoking Lua click handlers.
A scoped hover/button-state attempt did not detect stationary right clicks and
was removed. No application binaries were changed. The Delete dice menu was
removed as requested; Ctrl + left-click provides immediate die/selection deletion.
That fallback's physical modifier-plus-pointer delivery is not verified by the
automation tool. The underlying selection deletion is covered by native tests.

The preceding 0.2.0 menu observations describe that older build only.

## Remaining acceptance coverage

- Physical drag-and-drop into Quick Actions, from the hotbar into a panel, and
  between die cells. The Windows automation tool delivered no effective drags,
  including the application's own window-title drag. Callback behavior passed;
  mouse delivery and persistence across a restart have not been verified.
- A separate connected player client, owner disconnect/reconnect, simultaneous
  owners and several targets. Host-local ownership was tested; OOB transport is
  implemented but has not been verified end to end with a second client.
- Every BCE conditional syntax and paid Automated Effects data package, equipped
  item activation changes, all reroll/minimum/maximize effects, concentration,
  wards and Undo reversal. Combined loading and the native DMG/defense examples
  passed; that is not a claim of exhaustive extension compatibility.
- Other themes, UI scales, 240-die/28-zone limits and custom dice skins.
- Manual checks of zone-delete confirmation cancellation, Ctrl-wheel and
  overflowing dice lists. The type dropdown's internal scrolling was verified.

## Known implementation boundaries

Optional class damage is supplied through active effects or explicit drops;
there is no feature-name inference, suggestion dropdown or automatic slot spend.
Dropped effect conditions are sampled at drop time for the pending target.

The panel displays standard native 2D die icons; the 3D throw uses configured
damage-type skins. Full skin artwork inside editing/result cells is not
implemented. Horizontal navigation uses a continuous scrollbar and wheel.
The current UI uses a labelled Magical toggle rather than a checkbox glyph.

Pending plans and reroll counters are in memory and reset on reload. Only opaque
request ids for native chat links are stored in temporary DB records.
Single-use effect expiration is deferred, but arbitrary third-party callbacks
that mutate other state during modifier calculation cannot be made transactional
by this extension. Effects changed after preview require a fresh action.

The panel permits manual damage editing and is not an anti-cheat system.
Spell slots and concentration for manually dropped effects remain in the normal
character action workflow. Targets must retain their native combat-tracker health link.
