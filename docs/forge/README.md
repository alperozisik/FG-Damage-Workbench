# Forge publication materials — v0.3.11

## Publication status — 2026-11-20

[Forge item 3793](https://forge.fantasygrounds.com/shop/items/3793/view) is approved and **ACTIVE/listed**; v0.3.11 **build #1 is on Live**. The publication coordinator verified the Live selection and active/listed state on 2026-11-20. The [forum thread](https://www.fantasygrounds.com/forums/showthread.php?88612) is published. Repository copy records publication and remains the source for future description updates.

- Item UUID: `a9cfd5ce-e4b9-11f1-a411-0050562be458`; free (**0 Gold**), **5E Compatible / Extension**; install location **Data**.
- Submitted public GitHub release: **v0.3.11**; `DamageWorkbench.ext` SHA256: `f1ac8b0a855550753d745528349e71c7f11b92d7def32a5ecfa1aebabd8ea5e2`.
- Five uploaded images are active; the conceptual illustration is the primary cover.
- Forum posts **775977** (introduction), **775978** (usage/all Settings), **775979** (release/support), authored by **morfil**. Thread 88612 was entered in the Forge form.
- The live Forge description uses simple HTML headings and paragraphs. Forge strips inline `img` elements on save; use the gallery and forum for product images. Repository Markdown images remain useful on GitHub.

### Publication verification checklist

- [x] Coordinator verified approved build #1 on **Live**.
- [x] Coordinator verified **ACTIVE/listed** state.
- [ ] Independently verify subscription and actual Updater delivery with all FG sessions closed; compare the delivered package with the public GitHub release hash. This end-to-end smoke test has not been run.
- [ ] Coordinator updates the published Forge/forum copy and removes the old pending notice; this repository update corrects README/README.tr and the stored description copy.

Live/listed publication is confirmed. Do not describe the separate Updater smoke test as completed.

## Text

- `short-description.txt`: concise listing summary.
- `description.md`: feature description, usage, requirements, limits and distribution instructions.
- `forum-post.md`: repository opening-post copy and links to the published three-post thread.
- `cover-provenance.txt`: cover prompt and generation provenance.

The root English and Turkish READMEs remain usage guides. Distribution instructions belong in the listing description.

## Images

Use `images/damage-workbench-cover-forge.jpg` first. This is an AI-generated conceptual illustration, **not a screenshot**. The original PNG is retained in the shared `output/forge-release-prep` archive. Product screenshots follow the cover:

| File | Shows |
| --- | --- |
| `images/damage-auto-apply.png` | Targeted setup with Auto Apply checked. |
| `images/confirm-hit-ammo.png` | Confirm HIT and already-spent ammunition notice. |
| `images/damage-results-x2.png` | Six critical result dice, Undo, x2, Apply and Save. |

These v0.3.10 candidate captures use a separate sandbox QA identity with identical runtime/UI files. Every Forge upload image must be PNG/JPG under 300,000 bytes; full-size or historical usage-guide examples need not be uploaded.

The runtime chat icon already exists as `graphics/dwb_logo.png` (40×40). `ui/graphics.xml` registers `dwb_logo`; the native announcement in `extension.xml` uses it. The larger documentation logo is `docs/assets/damage-workbench-logo.png` (256×256). No replacement runtime icon is required.

## Build and distribution

Forge must receive the **exact `DamageWorkbench.ext` asset from a public GitHub release**, with the same SHA256. Do not build a separate Forge variant. If a package changes, publish the appropriate GitHub release first. Neither `DamageWorkbench-Test.ext` nor a local QA package is distributable.

GitHub source: https://github.com/alperozisik/FG-Damage-Workbench

Published GitHub release / Live Forge build: v0.3.11. Consult `TESTING.md` for executed checks and outstanding acceptance work before making compatibility claims.

v0.3.11 changes packaging and version metadata only; its unchanged runtime/UI is covered by the v0.3.10 captures. The extension packages the MIT license as `LICENSE.txt` to satisfy Forge file-type rules. The source archive retains `LICENSE`.

## Documentation update checklist

- Keep the English/Turkish READMEs, Forge description, screenshots and complete Settings values/defaults/scope/persistence in sync.
- Before Forge publication, update this repository's listing draft. Once published, update the live Forge description in the same change set as GitHub documentation.
- Check behavior against source and keep actual test/screenshot provenance and compatibility limits explicit. A documentation-only change does not require a new binary release or tag.
