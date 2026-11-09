# Oarhelm visual and interaction system

The user requested the Viking theme and selected the generated oar-and-helm ring as the current identity. This replaces the previous warm-light prototype. Operate mode: personality should help someone find and control real work.

## Materials and tokens

The implementation authority is Oarhelm/VikingTheme.swift. Dark timber ground #0E0F0F, raised charcoal/olive surfaces, cream text, brass accent, ember attention, and sea-green running/success. Secondary text is a light warm gray-green, not low-contrast neutral gray. Paper Mono Regular and Medium provide hierarchy at approximately 12, 14, 17, 23, 30 points with Dynamic Type scaling. SF Symbols are controls; the user helm is brand artwork, never a background behind text. Model controls show full names when they fit and provider marks otherwise; their picker always exposes full names and selection.

Use actual SwiftUI Liquid Glass on iOS 26 and later: glassEffect for floating surfaces and glass/glassProminent button styles. Bars and navigation use the system's material. Respect Reduce Transparency with solid themed surfaces. Earlier systems receive an explicit material fallback. Do not simulate glass with opacity alone. Long transcript text is legible on spacious glass-backed messages, with sparse semantic color. No particle effects, decorative runes, generated illustrations, or ornamental dividers.

## Layout and routing

AppRouter owns a separate typed path per section. Compact width shows Helm, Threads, Workspace, Account tabs. Regular width shows a persistent navigation sidebar and content stack. The same paths and selection live outside the size-class branch, so folding reconstructs presentation without discarding navigation intent. Navigation destinations are centralized in RouteDestination. Sheets use one typed presentation state.

Thread drafts, attachment selections, delivery choice, send phase, and message idempotency key live in the router by thread ID. Sending disables conflicting composer edits. A failed send retains draft, attachments, and key; success clears them and rotates the key. Editing a failed payload generates a new key; an identical retry reuses its key. Upload activity is tracked per thread and blocks Send until files finish. Advanced operation form state also lives in the router. Repeated send taps while sending are rejected. An explicit disconnect or verified key change clears paths and drafts to avoid exposing a previous account's work.

## States

Connection: disconnected → connecting → connected or failed. An explicit retry starts a new attempt. Only successfully verified keys persist.

Thread loading: idle → loading → loaded/empty/error. Project changes invalidate previous requests. Filter-empty is distinct from an empty project. Cancelled requests cannot populate another project's view.

Composer: ready → sending → ready or failed. Refresh is independent of send. Re-rendering after a fold cannot duplicate a pending send. New-thread creation retains requestId after a failure and rotates after success.

SSE: opening → streaming → done, error, or bounded reconnect. Resume with Last-Event-ID. Transcript and tool activity remain read-only observations; helpers are steered through their parent thread.

## References studied online on main

No T3 Code repository checkout or code files were downloaded. The following upstream sources were inspected online:

- https://github.com/pingdotgg/t3code/blob/main/apps/mobile/src/lib/mobileTheme.ts
- https://github.com/pingdotgg/t3code/blob/main/apps/mobile/src/lib/mobileThemeVariables.ts
- https://github.com/pingdotgg/t3code/blob/main/apps/mobile/src/components/ui/GlassSurface.tsx
- https://github.com/pingdotgg/t3code/blob/main/docs/internals/mobile-layout.md
- https://github.com/pingdotgg/t3code/blob/main/docs/internals/mobile-navigation.md
- https://github.com/pingdotgg/t3code/blob/main/apps/mobile/src/features/threads/composerSendPresentation.ts

Applied ideas: semantic theme roles shared by native surfaces, capability-gated real glass, persistent routing independent of adaptive layout, and explicit composer states. This implementation is SwiftUI; it does not include copied T3 Code source.

Mobbin examples inspected: Things 3 task detail and inline actions, Craft home organization and navigation, Apple Music list/library hierarchy and floating controls. Layout patterns are reimplemented for Capy's resources; product screenshots and third-party branding are not shipped. Apple Music reference: https://mobbin.com/screens/3a938b4d-3b4e-43b7-8de3-cb039a924e31.

## Asset provenance

Assets.xcassets/BrandMark.imageset/BrandMark.png and AppIcon.appiconset/AppIcon.png use the selected generated oar-and-helm ring from Design/IconOptions/01-oar-and-helm.png, resized to 1024 pixels for asset packaging. System icon masking is left to iOS. The previous mask-and-oar asset has been removed. The artwork appears in the app only inside the circular Liquid Glass Home control; never as a square illustration on a page. Paper Mono files and OFL license are the official bundle from paper.design/mono.

Craft reference: https://mobbin.com/screens/86eff422-820b-475a-b47b-4667540c0182.

## Home control and Duo bars

The supplied email-client screenshot informed the independent circular identity/Home control, grouped navigation, and native sidebar toggle. Home is a titled accessible button with the new logo clipped to a circle. It returns to the Helm root while preserving other navigation stacks, form values, and unsent work. In the expanded layout it lives in the sidebar's native toolbar; with the sidebar hidden or in compact width it lives in the detail toolbar. Its custom logo intentionally stays on the horizontal axis on iOS 27.1, with high visibility priority. The system positions all native bars around reserved regions. Shared toolbar background is hidden for this single item because the button already supplies its own circular Liquid Glass surface, avoiding stacked glass rings.

## Browser and onboarding

Browser presentation belongs to the currently visible root or sheet, so the sheet remains mounted and preserves its local forms and navigation. Browser phase is opening, loading, ready, or failed. The independent control mode is visible, docked, or hidden; a native simultaneous two-finger hold restores it. VoiceOver always exposes the control. First-use help is acknowledged only by Got it. Tapping the logo opens a menu; fullscreen dismissal uses its explicit Return action, while WebKit swipes navigate website history. Deliberate outward drags dock the control. Visibility changes use an edge slide and spring, disabled for Reduce Motion. Active fold and camera regions displace the floating control. Read-only sampling of the visible page's lower edge drives the full backing color and status contrast. The website viewport stays inside safe areas; its backing fills every edge.

Setup moves through welcome, key guide, key entry, project selection, and ready. It cannot advance past key verification without a connection. Connection checks disable navigation, dismissal, and repeated submissions. Keys persist only after verification. Refresh is independent of connection state; a failure keeps the existing account, project selection, drafts, and attachments.

## Texture and candidate icons

DitherSurface supplies sparse, static ordered-dither fields underneath native glass and in the backdrop. It uses warm brass, never a blue or indigo default palette. Reduce Transparency removes the pattern. The implementation follows dithercn's tone and threshold mechanism rather than bundling its web components. Details: Docs/DITHER-PORT.md.

Image generation produced three independent Oarhelm icon concepts in Design/IconOptions: oar-and-helm ring, Viking mask, and longship. The user selected the oar-and-helm ring. It remains the installed icon and circular Home and browser-controls identity in build 6. Capy and provider marks identify actual services; provenance is in Docs/BRAND-ASSETS.md.
