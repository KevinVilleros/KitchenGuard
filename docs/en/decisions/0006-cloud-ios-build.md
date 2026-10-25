# ADR 0006 — Build iOS in the cloud with GitHub Actions

## Status
Accepted

## Context

Building an `.ipa` for iOS requires macOS with Xcode, but development happens on
Windows.

## Decision

Produce the `.ipa` **in the cloud** with a **GitHub Actions** workflow
(`.github/workflows/ios.yml`, `macos-latest` runner). The workflow produces an
**unsigned** `.ipa` installed with **Sideloadly**. There is also an optional
signing job when certificate secrets are configured.

## Consequences

**Positive**
- No personal Mac needed.
- Reproducible, automatable build.
- The unsigned `.ipa` is enough for testing with Sideloadly.

**Negative**
- An `.ipa` with a free Sideloadly account **expires after 7 days**.
- Depends on GitHub CI minutes.

**Neutral**
- The workflow triggers on push to `main` touching `cocinap_mobile/**`, or
  manually.
