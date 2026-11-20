# Forge publication materials — v0.3.10

These are publication drafts, not an announcement that the Forge item or forum thread is live.

## Text

- `short-description.txt`: concise listing summary.
- `description.md`: feature description, usage, requirements, limits and distribution instructions.
- `forum-post.md`: opening-post draft; add the Forge link after publication.
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

Release candidate version: v0.3.10. Consult `TESTING.md` for executed checks and outstanding acceptance work before making compatibility claims.
