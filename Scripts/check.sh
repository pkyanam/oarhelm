#!/bin/zsh
set -eu
cd "${0:A:h}/.."
mkdir -p Build/Checks
cp Oarhelm/Resources/openapi.json Build/Checks/openapi.json
cp Oarhelm/Resources/capy-models.json Build/Checks/capy-models.json
swiftc -parse-as-library -swift-version 6 -target arm64-apple-macosx15.0 Oarhelm/CapyAPI.swift Oarhelm/APIContract.swift Oarhelm/BrowserSession.swift Oarhelm/OnboardingState.swift Oarhelm/AppRouter.swift Oarhelm/ModelCatalog.swift Oarhelm/LiveThreadState.swift Tests/ContractChecks.swift Tests/AsyncStateChecks.swift -o Build/Checks/ContractChecks
Build/Checks/ContractChecks
