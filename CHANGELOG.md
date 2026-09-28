# Changelog

Notable changes, newest first. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

Versions track the Debian point release the appliance is built from: `13.7` is built from
`debian-13.7.0-amd64-netinst.iso`, and the tag is `v13.7`. A version is cut once the Debian
bump **and** the appliance changes that go with it have all landed — one tag per Debian
point release. A respin of the same Debian version takes a third digit (`v13.7.1`).

**Cutting a release.** Changes land under `[Unreleased]` as they are made. When a new Debian
point release is out: create `zboxdesktop-X.Y.json` (ISO URL and sha256), build the OVA with
`./build-zboxdesktop.sh`, publish it, then `python3 tools/release.py X.Y --push` does the rest:
`[Unreleased]` becomes `[X.Y] — date`, `build-zboxdesktop.sh` is pointed at the new var file, the
commit is tagged `vX.Y` and pushed, and the tag publishes this file's section as the GitHub
release note, with the ISO, its checksum and the OVA link above it
(`.github/workflows/release.yml`, `tools/release_notes.py`). The script refuses a dirty tree, an
empty `[Unreleased]` (`--from-commits` fills it from the commits), a version not above the last
tag, a var file that does not exist yet, and any string from the local `.release-denylist`;
`--check` runs the same rules, and CI runs it on every push. Preview a note with
`python3 tools/release_notes.py X.Y`.

## [Unreleased]

### Changed

- **Releases follow the shared zPodFactory standard.** `tools/release.py` (cut, `--check`,
  `--draft`, `--from-commits`) and `tools/release_notes.py` are the same files as in every other
  repository, with a configuration block at the top: here the version is the var file
  `build-zboxdesktop.sh` names, and the note carries the ISO, its checksum and the OVA link.
  `tools/README.md` explains the release in a page.

## [13.7] — 2026-09-24

### Changed

- **Debian 13.7** (`debian-13.7.0-amd64-netinst.iso`).
- **`eza` comes from apt alone now.** The image installed the Debian package *and* dropped the
  latest upstream binary into `/usr/local/bin`, where it shadowed the packaged one on PATH — so
  the apt copy was never the one that ran. The upstream drop is gone; `eza` now follows the
  Debian lifecycle like every other packaged tool.

### Removed

- **`btop` and `wakey`**, matching the same removal in the [zBox](https://github.com/zPodFactory/packer-zbox)
  base image.

## [13.6] — 2026-09-01

### Added

- **`snitch`, `witr` and `xfr`** — connection inspector, "why is this running", and an iperf3
  alternative with a live TUI.
- **`dnsutils`**, so `dig` and `nslookup` are present.

### Changed

- **Debian 13.6** (`debian-13.6.0-amd64-netinst.iso`).
- **`chrony` replaces `openntpd`** for time sync, aligning with the base image.
- **`mise` is no longer preinstalled.** Its apt repository still ships, so `apt install mise`
  works out of the box — the package itself is large enough not to be worth baking in.
- **README corrections.** The disk-expansion note said `zbox-init.sh --extend-disk` grows the
  root volume; first boot already does that, and the flag only re-runs the expansion after the
  virtual disk is grown later.

### Removed

- **`pure-ftpd` and `nfs-kernel-server`** — server daemons that do not belong on a desktop
  template.
- **`dstat`**.

## [13.5] — 2026-05-17

### Changed

- **Debian 13.5** (`debian-13.5.0-amd64-netinst.iso`).
- **`atuin` is installed globally** to `/usr/local/bin` instead of into root's home, so every
  user on the appliance gets the same shell history tooling rather than root alone.

## [13.4] — 2026-05-16

### Added

- **RDP keyboard layout mapping.** `/etc/xrdp/xrdp_keyboard.ini` now ships with the image. The
  preseed installs a `us` console keymap, so without this map a non-US client — AZERTY and the
  rest — typed the wrong characters over RDP.
- **[chezmoi](https://chezmoi.io/)** for dotfiles management.
- **`surge`**, a fast download manager.
- **Mise apt repository**, so `apt install mise` is available.
- **Netbird and Cloudflare Tunnel apt repositories.**

### Changed

- **Debian 13.4** (`debian-13.4.0-amd64-netinst.iso`).
- **Kubernetes repository tracks upstream stable.** The minor version is read from
  `dl.k8s.io/release/stable.txt` at build time instead of being pinned to `v1.33`, so the image
  stops drifting a release behind as soon as it is built.
- **Third-party repositories all use `/etc/apt/keyrings` and the native codename.** The
  bookworm fallbacks for repos that had not published trixie yet were dropped.
- **tmux tuned for true color**, with the Catppuccin theme via TPM.
- **zshrc moved to oh-my-zsh plugins** for autosuggestions, syntax highlighting and zoxide.

### Removed

- **Microsoft repository and PowerShell.**
- **`direnv`** — superseded by mise.

## [13.3] — 2026-01-22

### Added

- **`ttl`**, a traceroute with a live TUI.

### Changed

- **Debian 13.3** (`debian-13.3.0-amd64-netinst.iso`).
- **`eza` installed from the upstream release** rather than the maintainer's apt repository,
  which was dropped.

### Fixed

- **OVF properties are read correctly inside a vApp.** A vApp's OVF environment carries one
  `PropertySection` per VM, and `zbox-init` parsed the file as a whole — so an appliance
  deployed in a vApp could pick up another VM's hostname, address or password. It now reads
  only the first `PropertySection`, which is the one belonging to the VM itself.

## [13.2] — 2026-01-04

### Changed

- **Debian 13.2** (`debian-13.2.0-amd64-netinst.iso`), and made the default build target.

## [13.1] — 2026-01-04

### Added

- **Initial zBoxDesktop appliance**, built on Debian 13.1: an XFCE desktop reachable over
  xrdp, on top of the [zBox](https://github.com/zPodFactory/packer-zbox) base image's shell
  and tooling.
- **`zadmin` user**, created at first boot with the password from `guestinfo.password` and
  passwordless sudo.
- **Chromium**, plus the theming defaults applied per user at first login.
- **First-boot configuration from OVF properties** — hostname, address, gateway, DNS, domain,
  root password and SSH key — with LVM root expansion to the full disk.

### Changed

- **VMware Tools guest customization disabled**, so OVF properties and cloud-init are the only
  things configuring the appliance.
