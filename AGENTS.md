# Release requirements

- Record every user-visible change under Unreleased in CHANGELOG.md while working.
- Before releasing, bump extension.xml version and its native announcement together.
- Update the version covered by README.md and README.tr.md and their load-message examples.
- Move Unreleased entries into a dated version section and update comparison/release links.
- Keep the usage guides current; label screenshot provenance accurately.
- Update TESTING.md with checks actually run and remaining limitations.
- Run the existing tests and tools/build.py --source. Publish the extension, clean source archive and SHA256SUMS.txt with the release.
- Push documentation, screenshots and changelog with the release commit/tag.
