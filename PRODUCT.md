# Oarhelm for Capy

## Platform

ios. Native SwiftUI, built with Xcode 27.1 RC build 27A9275. Display name Oarhelm. iPhone Duo inner and outer screens are first-class layouts.

## Product purpose

A remote client for Capy's public API: start and steer sessions, observe helpers, answer needs-you requests, organize work, run captains and automations, inspect reviews, track issues, and see spend. Agents run remotely on Capy or already paired computers.

Recommended future use: integrate these API building blocks into focused custom apps rather than pursue another full client. The owner reports that Capy is developing an official client. Keep Oarhelm as an independent prototype and implementation reference. See Docs/LIMITATIONS.md for the verified API boundary and implementation gaps.

## Confirmed constraints

The Capy documentation and bundled OpenAPI contract define functionality. API keys are created in Capy Settings, API, and saved in the device Keychain. Pairing computers, integration setup, purchases, MCP and plugins belong in the official Capy app. No invented work, code, spend, or demo records appear in the UI.

## Confirmed design commitments

User requested a substantial Viking theme with a circular glass Home control, Liquid Glass wherever applicable, friendly task-based navigation, and adaptation for both Duo displays. Paper Mono is the default typeface. Copy stays short, with no all-caps eyebrows or decorative arrows. Mobbin references across apps and T3 Code's React Native mobile design system inform implementation.

The user selected the generated oar-and-helm ring for the installed app icon and circular Home and browser-menu controls. The original three concepts remain in Design/IconOptions.
