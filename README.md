# Oarhelm for Capy

Native SwiftUI iOS prototype. Display name: Oarhelm.

**Recommended use:** embed Capy's API in focused custom apps rather than build another general-purpose Capy client. Oarhelm is a reference for native API transport, agent workflows, and adaptive iOS controls. The project owner reports that Capy is developing an official client; this is project context, not a verified release schedule.

Start with [build instructions](Docs/BUILDING.md), [agent instructions](AGENTS.md), [architecture](Docs/ARCHITECTURE.md), and [platform/API limitations](Docs/LIMITATIONS.md). The [operation inventory](Docs/API-COVERAGE.md) and [latest validation record](Docs/BUILD-6-VALIDATION.md) describe coverage and what has actually been checked.

Open `Oarhelm.xcodeproj`, select Oarhelm, and run on iOS 18 or later. Project files can be regenerated with `ruby Scripts/generate-project.rb` (requires the xcodeproj Ruby gem). Build storage belongs in `Build/` and local builds use at most two jobs.

Connect using a key created at https://capy.ai under Settings, API. Keys are stored in the device Keychain. No demo records are bundled. An account and reachable Capy API are required to load real work or run operations.

The source of truth is https://docs.capy.ai and the downloaded `Oarhelm/Resources/openapi.json`. The app connects directly to https://api.capy.ai with bearer authentication. MCP is an agent integration, not the app transport. Computer pairing, third party integration setup, credit purchases, plugins, and MCP configuration open the official Capy site.

Typography: official Paper Mono OTF files for native rendering; official WOFF2 files are retained alongside the SIL Open Font License in Resources. UIKit navigation titles and tab labels also use Paper Mono. System symbols and native input controls retain platform behavior.

Design reference: Linear Mobile inbox, https://mobbin.com/screens/0248e978-f201-4ecc-b2aa-19ff8c38e2e5. The implementation uses native rows, clear empty states, warm matte surfaces, and short copy. It contains no invented work, code, or spend.

This is an independent prototype, not an official Capy app. Mutating operations affect the real account connected with the key.

## Validation

Run `Scripts/check.sh` for local transport and contract checks. Run `xcodebuild -project Oarhelm.xcodeproj -scheme Oarhelm -sdk iphonesimulator -configuration Debug -derivedDataPath Build -jobs 2 CODE_SIGNING_ALLOWED=NO build` for a simulator build. Verified with Xcode 27.1 RC, build 27A9275.

The simulator build and local checks pass. Authenticated actions still need verification with a user-provided API key. The Duo simulator was inspected on its outer display and expanded inner display after the previous Notify session was released. See `Docs/API-COVERAGE.md` for the public surface and prototype limits.

There is no CI or release pipeline. Drafts are in memory, streams have bounded recovery, and some advanced actions still use schema/JSON forms. Model availability is not discoverable per account. Embedded-browser passkeys require website cooperation or approved browser entitlements and are not enabled. See the limitations document before treating this as a production client.

## Viking redesign

The current UI uses the selected oar-and-helm ring as app icon and circular Liquid Glass Home control, semantic VikingTheme tokens, real SwiftUI Liquid Glass where available, and Paper Mono. Compact width uses a four-section glass tab bar; regular width uses a sidebar plus content. AppRouter preserves typed navigation, thread drafts, attachments, delivery selection, and advanced forms across size-class changes. The composer stays docked above the safe area. Advanced API operations now live under Account rather than competing with everyday work. See DESIGN.md for sources and state transitions.

## Browser and setup

HTTP and HTTPS links open in a persistent, fullscreen WebKit browser. The visible page background fills the home-indicator area and Duo status edge. Tap the circular logo for Back, Forward, Reload, Find, Share, visibility controls, and Return to Oarhelm. Controls slide to and from the edge; Reduce Motion disables the transition. A two-finger long hold restores hidden controls; first-use help explains this. Browser presentation keeps the underlying sheet and its local draft mounted. API credentials are never added to webpage requests. Passkey constraints are documented in `Docs/BROWSER-CAPABILITIES.md`.

Setup has five stages: welcome, key creation guide, verification, project selection, and completion. Exploring without a key is supported. Project refresh failures preserve the connection and unsent work.

The native ordered-dither texture follows dithercn's tone and threshold approach with warm brass and charcoal, static rendering, and a Reduce Transparency fallback. The selected icon is `Design/IconOptions/01-oar-and-helm.png`; all three generated concepts remain in `Design/IconOptions`.

## Native work controls

Build 6 adds guided Captain, automation, and issue creation, Captain crew and digest views, a composer-first new thread, and live conversation rendering with tool activity and helpers. Drafts, attachment selections, and retry keys survive navigation and display changes. Sidebar selections replace their section destination rather than stacking copies. Request generations reject stale account and project responses.

Model selection uses a searchable snapshot of 56 coding models from Capy's official documentation. The public API does not list models or account-specific availability. A default selection omits the model override. Compact controls fall back to provider marks; the picker displays complete names. Capy's official brand kit and provider mark sources are recorded in `Docs/BRAND-ASSETS.md`.

Build 6 passes the simulator and signed device builds, contract and deterministic delayed-response checks, and Duo layout lint. It is installed on the physical Duo over WiFi. Simulator checks cover expanded and compact layouts, model selection, browser controls, and repeated sidebar selection. Live authenticated agent execution remains unverified without an API key.
