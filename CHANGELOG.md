# Changelog

All notable changes to **Prevent Sleep** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0] - 2026-11-03

### Added
- **One-Click Instant Toggle**: Instantaneous switching between Prevent Sleep (ON) and Normal Sleep (OFF) directly from the macOS menu bar.
- **Truthful Kernel Power State**: Directly queries and updates `/usr/bin/pmset disablesleep` with immediate readback verification.
- **Modern LaunchDaemon Architecture**: Uses Apple's modern `SMAppService` for authorization; daily usage requires zero password prompts.
- **Strict Cryptographic Security**: Helper daemon validates client connections via macOS kernel audit token, requiring Apple signature and developer Team ID (`N4BDK3Z362`).
- **Low-Battery Auto-Disarm Safeguard**: Automatically restores normal sleep if laptop battery drops to or below 15% on battery power, with native macOS notification.
- **Closed-Lid Thermal Guidance**: Onboarding guidance alerting users about closed-lid heat management and battery conservation.
- **Safe Quit Confirmation**: Warns users if quitting while sleep is still disabled, offering one-click "Allow Sleep & Quit".
- **Single-Instance Enforcement**: Prevents redundant multiple menu bar icons from being spawned.
- **Event-Driven Refresh**: Replaced 1-second continuous process polling with event-driven refresh on menu open, system wake, and 20s coalesced background timer.
- **Automated Relocation**: Smart prompt to move or copy Prevent Sleep to `/Applications` when launched from a mounted DMG or Downloads.
- **Native macOS App Icon**: High-resolution custom icon asset catalog (`.xcassets`) featuring warm coffee mug aesthetic.
- **Automated Release Pipeline**: One-command build, Hardened Runtime codesigning, DMG packaging, and checksum verification (`scripts/release.sh`).
