# Limits and recommended use

## Direction

Prefer using Capy's public API inside focused custom apps rather than building another full Capy client. A task-specific interface can combine thread creation, steering, helpers, issues, and usage into a workflow suited to its users. Oarhelm is a reference prototype for those building blocks.

The project owner reports that Capy is building an official client. That is project context, not an independently verified release announcement or schedule. This repository does not promise parity with an official app, continued production support, or a distribution release.

## Public API boundary

The authority is [Capy's docs](https://docs.capy.ai) and the bundled [OpenAPI snapshot](../Oarhelm/Resources/openapi.json), retrieved November 9, 2026. The snapshot contains 108 operations, including legacy task aliases alongside subagents. A searchable operation is not evidence that every account can use it or that its live execution has been verified.

- Authentication is a user-created bearer API key. The app cannot create keys or substitute a website login/passkey for native API access. Create keys under Capy Settings, API.
- Agent execution is remote on Capy or a previously paired computer. An iPhone does not run the agent. A paired computer must already be configured and available.
- No public paired-computer discovery is exposed by this snapshot. Device/workspace values remain advanced inputs. Computer pairing is done in Capy.
- No model-list endpoint exists in the snapshot. The picker bundles 56 documented coding models with provenance and date. It cannot report account-specific availability, entitlement, or continuously updated pricing. Default omits an override and lets Capy choose.
- GitHub/Slack setup, credits/purchases, MCP servers, and plugin setup are managed on the official Capy app/site. MCP expands an agent's tools; it does not expand the HTTP API available to this client.
- IDs, required fields, permissions, rate limits, and endpoint-specific constraints are enforced by the server. Do not infer an operation from a website button. Read current docs before extending the snapshot.
- Idempotency is endpoint-specific. Thread/message/automation retry controls do not imply safe automatic retries for every mutation. An uncertain network outcome can require inspecting the account before retrying an operation without an idempotency contract.

## Prototype implementation

- Authenticated agent runs, live account streams, mutations, billing, and account-specific models have not been end-to-end verified with a real API key. Local checks use intercepted requests. Build 6 was installed on a real Duo; that does not establish production correctness.
- Common setup flows are native; uncommon operations still use contract/schema controls or JSON. Schema validation is partial; the server validates remaining constraints. Native workflows do not provide a polished dedicated screen for all 108 operations.
- There is no durable offline cache, offline write queue, background push notification service, or guaranteed background SSE. Router drafts are in-memory and do not survive process termination.
- Stream reconnection is bounded. Reducer memory is bounded; conversations retain at most 1,000 durable messages, with older pages accessible through advanced transcript browsing. Network gaps and event ordering require further live validation.
- API errors can include server response text. Do not publish screenshots or logs containing account data. Keychain protects the native API key, but this prototype has no independent security audit.
- No CI workflow, TestFlight/App Store pipeline, release signing automation, or universal device/accessibility certification is configured. Original project code is MIT licensed; fonts retain their included SIL Open Font License, and third-party assets and trademarks retain their applicable rights and notices.

## WebKit and iOS

The fullscreen browser is not Safari and does not promise compatibility with every site's authentication, popup, download, or media flow. Website cookies persist separately from the native Capy API key. Browser controls provide back/forward/reload, find, share, explicit return, docking, hiding, and two-finger recovery. The tutorial and accessibility recovery path matter because dismissal gestures do not exit the fullscreen website.

Universal passkeys cannot be switched on for arbitrary sites in this ordinary WKWebView. Domain-specific support needs a two-sided associated-domain relationship and a website that supports passkeys. Broader browser capability requires Apple's approved entitlements and eligibility. Oarhelm currently has neither route configured. See [the primary-source research](BROWSER-CAPABILITIES.md).

Downloads, PDF export, private sessions, separate profiles, website data controls, and a dedicated Safari authentication fallback remain unimplemented. Safe-area backing color is sampled from visible page backgrounds; complex animated, gradient, image, or embedded content may need additional tuning. A website can still control its own colors and responsive layout.

Duo layouts use current SDK APIs and reserved-region geometry. Simulator checks covered both active displays and larger text; hinge telemetry failed during one fold check, while the advised screenshot confirmed the outer display. This is not exhaustive testing of partial folds, multitasking, every accessibility setting, or all hardware poses.
