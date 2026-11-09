# Security policy

Oarhelm is an independent prototype that handles Capy API keys, remote agent controls, file uploads, and website sessions. It has not received an independent security audit. Do not treat local checks as a security certification.

## Report privately

Use [GitHub's private vulnerability reporting form](https://github.com/pkyanam/oarhelm/security/advisories/new) for this repository. Do not post suspected vulnerabilities, credentials, or private account data in public issues or pull requests. If the form is unavailable, do not publish sensitive details; open a public issue asking only for a private reporting channel, without exploit details or attachments.

Include the affected commit or app version, iOS and Xcode versions if relevant, the impact, prerequisites, and minimal reproduction steps. Use synthetic identifiers and redacted examples. Explain whether you observed the behavior in a local test or a live account. Do not include API keys, cookies, authorization headers, presigned URLs, private transcripts, or unnecessary personal information. Coordinate public disclosure through the private report after a fix or mitigation is available.

There is no guaranteed response time, bounty program, or service-level agreement. Maintainers will assess reports as capacity permits. Investigation may need further information; do not assume a report has been received or fixed without a response.

## Scope and supported code

Security fixes target the current main branch. There is no maintained release/backport schedule; older snapshots and forks may not receive fixes. Include a commit SHA in reports so maintainers can identify the affected implementation.

Relevant areas include native Keychain handling, account isolation, API authorization, upload URL handling, WebKit navigation/storage, browser-to-app boundaries, and disclosure of sensitive data. Capy's backend and third-party websites are outside this repository's control; report service-side vulnerabilities through the affected provider's official channel.

## Safe research

Test locally and with accounts you control. Do not probe other users' accounts, access private data, create unwanted agent work or spend, disrupt services, or run destructive tests against Capy. A minimal intercepted-request test is preferable when it demonstrates the issue. This policy grants no authorization to test Capy or any third-party service.

If you accidentally expose a key or session credential, revoke or rotate it through the issuing service immediately and report the exposure privately. Removing it from a comment or commit does not invalidate it. Do not paste the credential into a report.

## Contributor safeguards

- Keep native API credentials in Keychain and separate from browser cookies.
- Do not attach native bearer credentials to website requests or presigned upload URLs.
- Reject stale work across account changes and avoid duplicate remote mutations.
- Keep secrets, personal data, signing material, and authenticated recordings out of the repository.
- Preserve platform security defaults; do not add blanket transport exceptions, bypass certificate validation, or enable arbitrary website capabilities without a documented need and review.

See [AGENTS.md](AGENTS.md) for implementation invariants and [platform limitations](Docs/LIMITATIONS.md) for current constraints, including embedded-browser passkeys.
