# Changelog

All notable changes to PleaseTweakWindows are documented in this file. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html). Release packages, `SHA256SUMS.txt` and
the CycloneDX SBOM of each version are published on the
[GitHub Releases](https://github.com/26zl/PleaseTweakWindows/releases) page.

## [Unreleased]

### Added

- This changelog.

### Changed

- Microsoft.Extensions.DependencyInjection, Microsoft.Extensions.Logging and
  Microsoft.Extensions.Logging.Abstractions 10.0.10 → 10.0.13 (app and test project).
- Test tooling: xunit.v3 3.2.2 → 4.0.2, xunit.runner.visualstudio 3.1.5 → 4.0.1,
  Microsoft.NET.Test.Sdk 18.8.1 → 18.11.0, Moq 4.20.72 → 4.21.0; coverage is collected with
  coverlet.MTP 10.1.0 (was coverlet.collector 10.0.1) for the Microsoft.Testing.Platform runner.
- CI actions: actions/checkout 7.0.0 → 7.0.1, actions/upload-artifact 7.0.1 → 7.0.2,
  actions/download-artifact 8.0.1 → 8.0.2, step-security/harden-runner 2.20.0 → 2.22.2,
  softprops/action-gh-release 3.0.2 → 3.0.3.
- Both `packages.lock.json` files are regenerated with `dotnet restore --force-evaluate` after the
  package bumps so the locked-mode restore in CI passes.
- UAC "Never notify" is excluded from Run All, and the Debloat/Performance registry batches no
  longer disable Windows Update, security, VPN, camera frame-server, Windows Hello enrollment or
  Web Threat Defense services (#48).

### Fixed

- LSA protection and Credential Guard are enabled without the UEFI lock, so Restore Default can
  actually undo them (#47).
- Restoring network security rebuilds the Workstation service dependency list from the drivers
  that are present instead of re-adding the SMB1 driver Windows 11 no longer ships, which made the
  service fail to start (#47).
- Blocking Microsoft accounts refuses to run while a Microsoft-account user exists, so the tweak
  cannot lock out the only administrator; it is also excluded from Run All (#47).
- Script checksum manifest regenerated after the security fixes so the CI checksum gate and the
  runtime checksum verification pass again (#49).

## [2.2.0] - 2026-07-17

### Added

- STIG / CIS Baselines category: Windows 11 STIG V2R9 and CIS Level 1 aligned Apply/Restore
  bundles composed from existing security actions, with protected progress state so Apply can
  roll back after a partial failure and Restore can resume after an interruption.

### Changed

- Security policy hardening across the existing scripts.
- Serilog 4.3.1 → 4.4.0, Microsoft.Extensions.DependencyInjection and Microsoft.Extensions.Logging
  10.0.9 → 10.0.10, Microsoft.NET.Test.Sdk 18.7.0 → 18.8.1.
- CI actions: actions/cache 4.3.0 → 6.1.0, actions/upload-artifact 4.6.2 → 7.0.1,
  step-security/harden-runner 2.19.4 → 2.20.0, softprops/action-gh-release 3.0.1 → 3.0.2.

## [2.1.3] - 2026-07-03

### Changed

- Migrated to .NET 10, with production hardening across the app, scripts, CI and documentation,
  new tweaks and bug fixes.
- Releases are no longer code-signed. Every release now ships `SHA256SUMS.txt` and a CycloneDX
  SBOM (`SBOM.json`) for verification.
- CI actions: actions/checkout 4.3.1 → 7.0.0, actions/setup-dotnet 4.3.1 → 5.4.0,
  actions/download-artifact 4.3.0 → 8.0.1, step-security/harden-runner 2.16.0 → 2.19.4,
  softprops/action-gh-release 2.6.1 → 3.0.1.

## [2.1.2] - 2026-04-18

### Changed

- Application rewritten in C# (WPF), with fixes and new tweaks focused on security and privacy.

[Unreleased]: https://github.com/26zl/PleaseTweakWindows/compare/v2.2.0...HEAD
[2.2.0]: https://github.com/26zl/PleaseTweakWindows/compare/v2.1.3...v2.2.0
[2.1.3]: https://github.com/26zl/PleaseTweakWindows/compare/v2.1.2...v2.1.3
[2.1.2]: https://github.com/26zl/PleaseTweakWindows/releases/tag/v2.1.2
