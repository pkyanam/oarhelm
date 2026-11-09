# Contributing to Oarhelm

Contributions are welcome, including small fixes, clearer docs, accessibility improvements, and bug reports. You do not need a Capy account to build the app or run local checks.

Oarhelm is an independent SwiftUI prototype and reference for using Capy's API in focused custom apps. Read [the README](README.md) and [current limitations](Docs/LIMITATIONS.md) before proposing broad new features. The project owner reports that Capy is building an official client; this project is not an official Capy app or a promise of feature parity.

## Get running

1. Fork the repository and create a branch for your change.
2. Follow [the build guide](Docs/BUILDING.md). The checked-in Xcode project needs no Ruby dependency; regeneration requires the xcodeproj gem.
3. Run `Scripts/check.sh`. This runs local intercepted transport and state checks without contacting Capy.
4. Open Oarhelm.xcodeproj in Xcode or run the simulator build command in the build guide. Explore without an API key.

[AGENTS.md](AGENTS.md) explains project invariants for coding agents and humans. [The architecture map](Docs/ARCHITECTURE.md) points to the relevant files. Use Xcode 27.1 RC build 27A9275 or a newer stable toolchain and record the version you actually used. Keep build products in Build and use at most two compiler jobs.

## Choose a change

Useful starting points include improving native controls that still fall back to schema forms, accessibility and text wrapping, documentation, and deterministic tests for state transitions. See [API coverage](Docs/API-COVERAGE.md) for implemented workflows and gaps. Search existing issues first. For a substantial feature or architectural change, open an issue describing the user problem and the public API that supports it. Small fixes can go straight to a pull request.

Keep pull requests focused. Explain the visible behavior before and after, why it matters, and how you checked it. Include screenshots for UI changes where practical, using empty states or redacted real data. Do not invent work records or code to make screenshots appear populated. If a change needs an API contract refresh, record its official source, retrieval date, and affected operations.

## Implementation expectations

- Use documented public Capy APIs. Do not invent endpoints, account entitlements, model availability, or capabilities from the website UI. Agents execute remotely, not on the phone.
- Prefer native task-oriented controls. Preserve the complete advanced API console for less common operations. Follow [the design system](DESIGN.md): Paper Mono, short copy, semantic warm colors, native glass, and readable text.
- Preserve navigation and drafts across display changes. Protect mutations and pagination against repeated taps. Reject stale asynchronous results after account, project, or request changes.
- Use endpoint-supported idempotency and bounded reconnects. Never forward bearer tokens to a presigned upload URL or the embedded browser.
- Keep dependencies small. Explain any new package and include its licensing/provenance. Update Scripts/generate-project.rb when source membership or project settings change; it recreates the checked-in Xcode project.
- Include documentation updates for changed behavior or limitations. Be respectful, specific, and constructive in issues and reviews.

## Verification

Run checks appropriate to the change and report their results. Transport, router, reducer, and contract changes should run `Scripts/check.sh`; add meaningful regression coverage when fixing those behaviors. SwiftUI changes should compile for the simulator and be inspected at compact and expanded widths, with larger text and keyboard presentation where relevant. New tests belong under Tests and must be added to the standalone runner if needed; there is no XCTest target or CI pipeline today.

Authenticated execution is optional for contributors. Never use someone else's credentials or incur agent spend without permission. Use a key you control if a live check is needed, keep its permissions and scope appropriate, and describe exactly what was checked. A build or intercepted transport test is not proof that live mutations or streams work. If you could not run a check, say so in the pull request.

Do not commit Build, DerivedData, logs, recordings, credentials, private transcripts, provisioning profiles, or signing material. The tracked signing team and bundle identifier are owner-specific; use local command-line overrides or your own Xcode signing settings when necessary.

## Security and licensing

Report suspected vulnerabilities privately using [SECURITY.md](SECURITY.md), not a public issue. Public bug reports must be stripped of keys, cookies, signed URLs, personal information, and account data.

Original project code is MIT licensed. Contributions to that code are submitted under the [MIT license](LICENSE). Retain third-party notices: Paper Mono uses its bundled SIL Open Font License, and Capy/provider artwork and trademarks remain subject to their respective rights. See [asset provenance](Docs/BRAND-ASSETS.md).
