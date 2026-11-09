# Browser capabilities research

Researched 2026-11-09 against Apple and WebKit primary documentation. Build 6 implements native Find in Page and URL sharing; the remaining additions below are research.

## Passkeys

Oarhelm currently uses an ordinary WKWebView, a persistent default website data store, and no associated-domain or browser entitlements. There is no general passkey switch to enable for arbitrary websites in this configuration.

Apple documents that an embedded WKWebView needs the relying-party domain configured as an associated domain. Association is two-sided: the website must authorize the application's identifier in its apple-app-site-association file, and the app needs the matching webcredentials entitlement. Adding capy.ai to an entitlement alone is insufficient. Capy would need to authorize Oarhelm for this route, and the website itself must offer passkey authentication.

An entitled browser has a broader route. WebKit documents entitled browsers as an exception to the ordinary associated-domain restriction. Apple's browser entitlements are managed capabilities requiring Apple approval and browser eligibility. The arbitrary-relying-party public-key-credential entitlement documentation specifically describes a macOS browser request; it should not be treated as a drop-in iOS permission. For iOS, the browser/default-browser entitlement route must be assessed and approved. This research does not establish Oarhelm's eligibility or guarantee approval.

Conclusion: universal passkeys cannot be enabled in the current Oarhelm browser through an app-only change. Domain-specific support is conditional on website cooperation; broader browser access is conditional on Apple's entitlement approval. A user-invoked Open in Safari fallback is feasible. Authentication in Safari or a system authentication session does not imply that the current embedded WKWebView is also signed in. ASWebAuthenticationSession requires an actual service-supported return flow; it is not a generic way to import another browser's cookies.

Passkeys for the website also cannot replace Oarhelm's native Capy API-key authentication: the bundled public OpenAPI contract exposes bearer API-key authentication.

Sources:
- https://developer.apple.com/documentation/authenticationservices/supporting-passkeys
- https://developer.apple.com/documentation/xcode/supporting-associated-domains
- https://developer.apple.com/documentation/authenticationservices/passkey-use-in-web-browsers
- https://bugs.webkit.org/show_bug.cgi?id=250912
- https://developer.apple.com/documentation/xcode/preparing-your-app-to-be-the-default-browser
- https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.web-browser.public-key-credential
- https://developer.apple.com/documentation/authenticationservices/aswebauthenticationsession
- Oarhelm/Resources/openapi.json, components.securitySchemes

## Feasible additions

These can be implemented with public APIs while keeping the custom fullscreen browser. They are not all present today.

| Addition | Implementation and limits |
| --- | --- |
| Find in Page | Enable WKWebView.isFindInteractionEnabled and expose the native find panel from the control menu. |
| Downloads | Handle navigation-to-download transitions and WKDownloadDelegate; surface progress, cancellation, Files export, and supported resume data. Download support depends on what the website actually serves. |
| Save PDF and share | WKWebView.createPDF produces a page snapshot for export; it does not make an interactive web app work offline. |
| Private sessions | A separate nonPersistent website data store keeps website storage in memory; it is not an anonymity guarantee. |
| Separate web profiles | Persistent WKWebsiteDataStore instances identified by UUID isolate website sessions, allowing personal and work web logins. These are separate from the native API-key account. |
| Website data controls | List and remove website records through WKWebsiteDataStore. Clearing a site's cookies may sign the user out. |
| Per-site page size | WKWebView.pageZoom plus a locally stored preference; verify layouts on both Duo displays. |
| Bookmarks and recent pages | App-owned URL/title storage and explicit restoration controls. Avoid storing submitted forms or credentials in history. |
| Show address and open externally | Display the current origin in the overlay menu, copy/share the URL, or open it in Safari for incompatible sign-in flows. |

Current browser has persistent website cookies, back and forward navigation, reload, native Find, URL sharing, same-view new-window links, and loading/failure states. Find was exercised in the Duo simulator. Oarhelm does not implement WKDownloadDelegate or expose profiles and website-data controls.

Sources:
- https://developer.apple.com/documentation/webkit/wkwebview/isfindinteractionenabled
- https://developer.apple.com/documentation/webkit/wkdownloaddelegate
- https://developer.apple.com/documentation/webkit/wkwebview/createpdf(configuration:completionhandler:)
- https://developer.apple.com/documentation/webkit/wkwebsitedatastore
- https://webkit.org/blog/14423/building-profiles-with-new-webkit-api/
- https://developer.apple.com/documentation/webkit/wkwebview/pagezoom
- https://developer.apple.com/documentation/webkit/wkwebview

Possible next additions: downloads and Safari fallback, then website profiles and private sessions. Passkeys remain conditional rather than promised.
