# Build and run

## Requirements

- macOS with Xcode 27.1 RC build 27A9275, or a newer stable Xcode. Verify the active toolchain with `xcodebuild -version` and `xcode-select -p`. The latest verified build used 27A9275. A newer toolchain must be checked before describing it as supported.
- iOS deployment target 18.0. Native glass requires iOS 26; Duo-specific APIs are availability-gated to 27.1. Use the 27.1 SDK or later for optimized Duo layout.
- No official Capy SDK or third-party runtime dependency. Foundation, SwiftUI, UIKit, Security, and WebKit provide the implementation.
- Ruby plus the `xcodeproj` gem only if regenerating the project: `gem install xcodeproj`. There is no Gemfile lock; use the checked-in project if regeneration is unnecessary.

Clone the private repository using an account with access:

```sh
git clone https://github.com/pkyanam/oarhelm.git
cd oarhelm
xcodebuild -version
xcode-select -p
```

## Local checks

```sh
Scripts/check.sh
```

This compiles a standalone macOS Swift executable and copies the bundled OpenAPI and model snapshots into Build/Checks. It runs intercepted transport tests, deterministic delayed-response races, contract checks, navigation invariants, draft/retry state checks, and live stream reducer checks. It does not contact Capy or run an iOS app. The script currently targets Apple Silicon macOS 15 or later; Intel hosts need an appropriate target adjustment. It is not an XCTest suite and `xcodebuild test` is not a substitute.

## Simulator

```sh
xcodebuild -project Oarhelm.xcodeproj -scheme Oarhelm \
  -sdk iphonesimulator -configuration Debug \
  -derivedDataPath Build -jobs 2 CODE_SIGNING_ALLOWED=NO build
```

The app is at Build/Build/Products/Debug-iphonesimulator/Oarhelm.app. Open Oarhelm.xcodeproj in Xcode, choose an installed simulator, and Run. In T3 Code, open a device through its device panel tool, install the app with the returned agent-device command, and launch through that command. Do not assume another machine has the same simulator UUID.

The first-launch flow supports exploring without a key. Connecting requires a real key created at Capy Settings, API. No API key belongs in a build setting or source file. There are no demo records.

## Real device

The checked-in signing settings name the owner's team and com.preetham.oarhelm bundle ID. These are identifiers, not credentials. Other developers must choose their own valid signing team and bundle ID in Xcode or override them on the command line. A connected/trusted device, Developer Mode, and a provisionable signing identity are required. WiFi installation also requires a previously paired reachable device.

```sh
xcodebuild -project Oarhelm.xcodeproj -scheme Oarhelm \
  -configuration Debug -destination 'id=YOUR_DEVICE_UDID' \
  -derivedDataPath Build/Device -jobs 2 \
  DEVELOPMENT_TEAM=YOUR_TEAM_ID \
  PRODUCT_BUNDLE_IDENTIFIER=YOUR_UNIQUE_BUNDLE_ID \
  -allowProvisioningUpdates build

xcrun devicectl device install app --device YOUR_DEVICE_UDID \
  Build/Device/Build/Products/Debug-iphoneos/Oarhelm.app
```

Use Xcode or the device UI tool to launch. Keep provisioning profiles and signing keys outside the repository. This project has no archive/export, TestFlight, or App Store release pipeline.

## Regenerating the project

```sh
ruby Scripts/generate-project.rb
```

The generator recreates Oarhelm.xcodeproj and its shared scheme. It includes Oarhelm/*.swift, the asset catalog, and direct files under Oarhelm/Resources. Update the generator when changing build settings; editing only the project will be overwritten on regeneration. Inspect the resulting diff. Keep test fixtures out of the app bundle.

## Visual checks

Inspect the outer and inner Duo displays, sidebar shown/hidden, large accessibility text, keyboard/composer resizing, long model names, loading/error/empty states, and browser return with an unsent draft. Verify reduced motion/transparency behavior when changing custom surfaces. Existing evidence and its limits are in BUILD-6-VALIDATION.md. The optional iphone-duo-design skill supplies duo-lint; it is not a repository dependency.
