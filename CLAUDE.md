# Working on packer-zboxdesktop

Packer build of the zBox Desktop appliance (Debian, `zboxdesktop.json` plus one var file per Debian
point release, `build-zboxdesktop.sh` names the current one). Read `README.md` first; `CHANGELOG.md`
says what shipped.

## Releases

- Versions follow the Debian point release: `zboxdesktop-13.7.json` is tag `v13.7` is release `v13.7`.
- Every change gets a line under `[Unreleased]` in `CHANGELOG.md`: what changed for the person
  deploying the appliance, and why in a clause.
- A release is one command: `python3 tools/release.py X.Y --push` (`--dry-run` first). Create
  `zboxdesktop-X.Y.json` and build the OVA first; the cut moves the heading, points
  `build-zboxdesktop.sh` at the var file, commits, tags `vX.Y`, pushes; the tag then publishes the
  section as the GitHub release through `.github/workflows/release.yml`.
- `python3 tools/release.py --check` is what CI runs on every push: shipped version equals the
  newest section, every tag has a section, nothing local is tracked. Keep the forbidden-string
  list in `.release-denylist` (git-ignored) for the names that must never enter the history.
- Never tag by hand, never edit a release on GitHub: fix the changelog and re-run the workflow
  (`workflow_dispatch`, blank version republishes every tag).
