## What and why

<!-- What does this change, and why? Link the issue if there is one. -->

## Checklist

- [ ] Every new or changed toggle has a Restore Default that returns to the documented Windows default or to a saved pre-Apply state.
- [ ] Risk level and warning text match what the change does (High for anything that weakens security or deletes data).
- [ ] `scripts/file-checksums.json` is regenerated for every changed file under `scripts/`.
- [ ] New security-weakening settings are reviewed and listed in `tools/security-weakening-allowlist.json` with a reason.
- [ ] `dotnet build -p:TreatWarningsAsErrors=true` and `dotnet test` pass locally.
- [ ] `CHANGELOG.md` has an entry under `[Unreleased]` for user-visible changes.

## How was it tested?

<!-- Unit tests, VM test (Windows build), screenshots for UI changes. -->
