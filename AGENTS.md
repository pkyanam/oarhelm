# Working on Oarhelm

## Start here

Read README.md, Docs/BUILDING.md, Docs/ARCHITECTURE.md, and Docs/LIMITATIONS.md before editing. DESIGN.md defines the visual system; Docs/API-COVERAGE.md maps the public API. Oarhelm is an independent reference prototype, not an official Capy application.

The recommended direction is to embed Capy's API into focused custom apps. Keep this repository useful as a transport, workflow, and adaptive UI reference. The project owner reports that Capy is developing its own official client; do not interpret this prototype as a commitment to compete with it.

## Sources and boundaries

- Official docs: https://docs.capy.ai; contract: Oarhelm/Resources/openapi.json. Confirm relevant operations and schemas before changing requests. Do not invent endpoints or supported model parameters.
- App requests go directly to https://api.capy.ai/api/v1. MCP servers are tools attached to Capy agents; they are not this client's transport.
- Agents run remotely on Capy's machines or already paired computers. Never suggest that iOS executes them locally.
- API keys must be created in Capy Settings, API. Keep credentials in Keychain. Never commit credentials, account exports, device profiles, private transcripts, or authenticated screenshots.
- Pairing, GitHub/Slack integration, buying credits, MCP, and plugins go to the official Capy site. The browser must never receive the native API bearer token.
- Show real data or clean empty states. Do not ship mock threads, code, models, spend, or fabricated operation results.
- Authenticated mutations affect a real account and can incur spend. Use deterministic local tests first; obtain explicit scope before live tests that create agent work.

## Build and verification

Use Xcode 27.1 RC build 27A9275 on the owner's Mac until a newer stable version is available. Run `xcodebuild -version` and `xcode-select -p` before building. Never silently substitute an older beta. iOS 27.1 SDK or later is needed for Duo side bars and full layout; deployment target is iOS 18.

Use local disk-backed Build storage and at most two compiler jobs. Coordinate with other active builds. Commands and signing overrides are in Docs/BUILDING.md. The checked-in Xcode project is usable without Ruby; regenerating it requires the xcodeproj gem. Scripts/generate-project.rb is authoritative for source/resource membership and build settings. New Swift files must be directly under Oarhelm to be auto-discovered. Tests are standalone files under Tests, not an XCTest target.

Run Scripts/check.sh after transport, reducer, contract, or router changes. Run the appropriate simulator build after SwiftUI changes. Use the Duo skill/linter if installed, and inspect both compact and expanded layouts plus larger text. Build success is not evidence of authenticated runtime correctness. Record precisely what was verified; Docs/BUILD-6-VALIDATION.md is the latest baseline.

When working in T3 Code, use its device tools and returned agent-device command for UI interaction, screenshots, folding, and launch. Do not take a device session owned by another thread. Release your own simulator session without shutting it down when handing it back. Outside T3, use Xcode's simulator and device workflow.

## Architecture invariants

- AppRouter owns typed section paths, sheet/browser presentation, drafts, attachments, send phases, and retry keys. Sidebar selection replaces the section root. Pushes and path bindings collapse repeated destinations and cycles. Preserve semantic thread identity by ID.
- Preserve drafts across display changes, browser visits, and navigation. Explicit disconnect or verified account replacement clears private account state; failed refreshes must preserve it.
- Commit async results only if account revision, project/period, and request identity still match. Ignore cancellation errors. An older task must never clear a newer task's handle or loading state.
- Gate repeated sends, creation, uploads, and pagination. Reuse an idempotency key only for an identical failed payload when the endpoint supports it. Do not invent idempotency support for endpoints that lack it.
- LiveThreadState reduces observed stream events. Durable messages replace previews. Bound memory and resume with documented transcript IDs. Helpers are observed and steered through supported parent-thread APIs.
- Upload disk-backed bytes to the presigned URL without forwarding authorization. Persistent WebKit storage is separate from API-key authentication.

## UI and content

Paper Mono is the default UI font. Keep official font files and SIL Open Font License. Use VikingTheme tokens: charcoal, cream, brass, and restrained semantic color. Prefer native Liquid Glass controls with Reduce Transparency and Reduce Motion fallbacks. Backgrounds may fill safe areas; text and interactive controls must respect them and Duo reserved regions.

Use size classes and container geometry, not hardcoded device dimensions or orientations. Model controls must show complete names when they fit and provider marks otherwise; expose the full selection in the picker and accessibility label. Prefer native task-oriented forms over JSON editors. Keep the complete contract console as an advanced fallback.

Copy stays short. No slogans, all-caps eyebrows, decorative arrows, redundant descriptions, or fake content. Keep the Oarhelm artwork inside circular Home/browser controls; do not place a square app icon on pages. Retain provenance for fonts and third-party marks in Docs/BRAND-ASSETS.md.

## Handoff

Report changed behavior, checks, remaining limitations, and output paths. Keep README and the coverage/limitations docs accurate. Never claim universal passkey support or live account verification from a local build. Do not commit Build, logs, recordings, DerivedData, signing material, or local secrets.

On the owner's Mac, if ~/.config/kai/kai-post exists, post `done` with the result and file paths at the end; use `needs-input` or `blocked` when human input is required, or `failed` if unfinished. Do not post started/milestone, include secrets, or read the webhook environment file. Keep the summary below 1500 characters.
