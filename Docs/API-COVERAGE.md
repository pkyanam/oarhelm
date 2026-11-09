# API coverage

Source: https://docs.capy.ai/openapi.json, retrieved November 9, 2026. All 108 operations are loaded directly from the bundled contract and are searchable under Controls. This includes the legacy task aliases alongside subagents.

Native workflows cover API-key connection, project selection, thread creation, steering and queued delivery, transcript refresh, needs-you filtering, helpers, attachments, folders, captains, automations, issues, reviews, and usage. Less frequent actions remain available through contract forms with editable path and query parameters. Every JSON request schema is accessible through recursive object, array, boolean, numeric, enum, and union controls plus a JSON editor. Path values are encoded. Repeated query values can be entered as a JSON array of strings. Results expose an expandable tree, raw JSON, cursor navigation, and presigned download links.

File attachments use the two-step API upload: request a target, PUT disk-backed bytes with the declared content type and length without bearer credentials, then send the returned file ID. Generic SSE viewers retain at most 200 events and reconnect up to three times using Last-Event-ID. Live conversations reduce stream events into durable messages, assistant previews, tool calls, helper activity, and run status. Durable transcript events replace provisional text; transcript IDs supply the resume cursor.

All generic mutations ask for confirmation. Dedicated Start and Send controls act immediately on explicit taps. Thread request IDs and message client keys are retained across failed retries to avoid duplicate agent work.

Prototype limits: schema validation covers required keys, JSON types, enums, and basic string minima; the server validates remaining contract constraints. Free-form maps have key/value controls and a JSON editor. Transcript loading follows all forward cursors, retaining the most recent 1,000 messages in memory; older entries remain accessible through Browse transcript pages. After bounded retries, stream errors expose a reconnect action. No background push notifications or offline writes are implemented. API keys cannot be created here. Pairing, integration setup, purchases, MCP, and plugins link to Capy. The model picker uses a dated 56-model snapshot from official documentation because there is no public model-list endpoint; it cannot determine account-specific availability. Existing paired computer IDs and workspace paths can be entered, but the API does not expose paired-computer discovery.

Validation: Xcode 27.1 build 27A9275, simulator Debug build, two compiler jobs, disk-backed Build directory. Scripts/check.sh exercises the real transport with an intercepted test session and checks all 108 catalog entries, authentication, project decoding, rate limits, path guarding, disconnect, JSON round trips, SSE parsing, and request initialization. Test fixtures are never bundled in the application. Authenticated API actions could not be exercised without an API key. Duo UI verification proceeded after Notify released the simulator session.

## Operation inventory

- `automations.list` — GET `/api/v1/automations`
- `automations.create` — POST `/api/v1/automations`
- `automations.listBatches` — GET `/api/v1/automations/{automationId}/batches`
- `automations.cancelBatch` — POST `/api/v1/automations/{automationId}/batches/{batchId}/cancel`
- `automations.flushBatch` — POST `/api/v1/automations/{automationId}/batches/{batchId}/flush`
- `automations.delete` — POST `/api/v1/automations/{automationId}/delete`
- `automations.disable` — POST `/api/v1/automations/{automationId}/disable`
- `automations.enable` — POST `/api/v1/automations/{automationId}/enable`
- `automations.restore` — POST `/api/v1/automations/{automationId}/restore`
- `captains.list` — GET `/api/v1/captains`
- `captains.create` — POST `/api/v1/captains`
- `captains.get` — GET `/api/v1/captains/{captainId}`
- `captains.crew` — GET `/api/v1/captains/{captainId}/crew`
- `captains.digest` — GET `/api/v1/captains/{captainId}/digest`
- `files.upload` — POST `/api/v1/files`
- `folders.list` — GET `/api/v1/folders`
- `folders.threads` — GET `/api/v1/folders/{folderId}/threads`
- `folders.file` — POST `/api/v1/folders/{folderId}/threads`
- `folders.unfile` — DELETE `/api/v1/folders/{folderId}/threads`
- `issues.labels` — GET `/api/v1/issue-labels`
- `issues.createLabel` — POST `/api/v1/issue-labels`
- `issues.deleteLabel` — DELETE `/api/v1/issue-labels/{labelId}`
- `issues.updateLabel` — PATCH `/api/v1/issue-labels/{labelId}`
- `issues.prefix` — GET `/api/v1/issue-prefix`
- `issues.setPrefix` — PUT `/api/v1/issue-prefix`
- `issues.states` — GET `/api/v1/issue-states`
- `issues.createState` — POST `/api/v1/issue-states`
- `issues.reorderStates` — PUT `/api/v1/issue-states/order`
- `issues.deleteState` — DELETE `/api/v1/issue-states/{stateId}`
- `issues.updateState` — PATCH `/api/v1/issue-states/{stateId}`
- `issues.setDefaultState` — PUT `/api/v1/issue-states/{stateId}/default`
- `issues.list` — GET `/api/v1/issues`
- `issues.create` — POST `/api/v1/issues`
- `issues.get` — GET `/api/v1/issues/{code}`
- `issues.update` — PATCH `/api/v1/issues/{code}`
- `issues.comments` — GET `/api/v1/issues/{code}/comments`
- `issues.comment` — POST `/api/v1/issues/{code}/comments`
- `issues.fileDownload` — GET `/api/v1/issues/{code}/files/{fileId}/download`
- `issues.link` — POST `/api/v1/issues/{code}/links`
- `issues.unlink` — DELETE `/api/v1/issues/{code}/links`
- `issues.relations` — GET `/api/v1/issues/{code}/relations`
- `issues.relate` — POST `/api/v1/issues/{code}/relations`
- `issues.unrelate` — DELETE `/api/v1/issues/{code}/relations`
- `issues.timeline` — GET `/api/v1/issues/{code}/timeline`
- `projects.list` — GET `/api/v1/projects`
- `projects.get` — GET `/api/v1/projects/{projectId}`
- `projects.listEnvironmentVariables` — GET `/api/v1/projects/{projectId}/environment-variables`
- `projects.setEnvironmentVariables` — PUT `/api/v1/projects/{projectId}/environment-variables`
- `projects.deleteEnvironmentVariables` — DELETE `/api/v1/projects/{projectId}/environment-variables`
- `reviews.billingTransfer` — GET `/api/v1/review-billing-transfer`
- `reviews.acceptBillingTransfer` — POST `/api/v1/review-billing-transfer/accept`
- `reviews.cancelBillingTransfer` — POST `/api/v1/review-billing-transfer/cancel`
- `reviews.declineBillingTransfer` — POST `/api/v1/review-billing-transfer/decline`
- `reviews.offerBillingTransfer` — POST `/api/v1/review-billing-transfer/offer`
- `reviewFilters.listIgnorePaths` — GET `/api/v1/review-filters/ignore-paths`
- `reviewFilters.createIgnorePaths` — POST `/api/v1/review-filters/ignore-paths`
- `reviewFilters.deleteIgnorePaths` — DELETE `/api/v1/review-filters/ignore-paths/{id}`
- `reviewFilters.updateIgnorePaths` — PATCH `/api/v1/review-filters/ignore-paths/{id}`
- `reviewFilters.listRules` — GET `/api/v1/review-filters/rules`
- `reviewFilters.createRule` — POST `/api/v1/review-filters/rules`
- `reviewFilters.deleteRule` — DELETE `/api/v1/review-filters/rules/{id}`
- `reviewFilters.updateRule` — PATCH `/api/v1/review-filters/rules/{id}`
- `reviewRules.list` — GET `/api/v1/review-rules`
- `reviewRules.create` — POST `/api/v1/review-rules`
- `reviewRules.get` — GET `/api/v1/review-rules/{id}`
- `reviewRules.remove` — DELETE `/api/v1/review-rules/{id}`
- `reviewRules.update` — PATCH `/api/v1/review-rules/{id}`
- `reviews.settings` — GET `/api/v1/review-settings`
- `reviews.configure` — PUT `/api/v1/review-settings`
- `reviews.start` — POST `/api/v1/reviews`
- `reviews.round` — GET `/api/v1/reviews/rounds/{requestId}`
- `subagents.get` — GET `/api/v1/subagents/{subagentId}`
- `subagents.messages` — GET `/api/v1/subagents/{subagentId}/messages`
- `streams.subagent` — GET `/api/v1/subagents/{subagentId}/stream`
- `tasks.get` — GET `/api/v1/tasks/{taskId}`
- `tasks.messages` — GET `/api/v1/tasks/{taskId}/messages`
- `streams.task` — GET `/api/v1/tasks/{taskId}/stream`
- `threads.list` — GET `/api/v1/threads`
- `threads.create` — POST `/api/v1/threads`
- `folders.pin` — POST `/api/v1/threads/pin`
- `folders.unpin` — POST `/api/v1/threads/unpin`
- `threads.get` — GET `/api/v1/threads/{threadId}`
- `threads.rename` — PATCH `/api/v1/threads/{threadId}`
- `threads.archive` — POST `/api/v1/threads/{threadId}/archive`
- `attachments.list` — GET `/api/v1/threads/{threadId}/attachments`
- `attachments.download` — GET `/api/v1/threads/{threadId}/attachments/{fileId}/download`
- `messages.interrupt` — POST `/api/v1/threads/{threadId}/interrupt`
- `threads.join` — POST `/api/v1/threads/{threadId}/join`
- `threads.leave` — POST `/api/v1/threads/{threadId}/leave`
- `messages.send` — POST `/api/v1/threads/{threadId}/message`
- `messages.list` — GET `/api/v1/threads/{threadId}/messages`
- `messages.cancel` — POST `/api/v1/threads/{threadId}/messages/{eventId}/cancel`
- `messages.sendNow` — POST `/api/v1/threads/{threadId}/messages/{eventId}/send-now`
- `messages.versions` — GET `/api/v1/threads/{threadId}/messages/{eventId}/versions`
- `threads.read` — PUT `/api/v1/threads/{threadId}/read`
- `threads.regenerateTitle` — POST `/api/v1/threads/{threadId}/regenerate-title`
- `streams.thread` — GET `/api/v1/threads/{threadId}/stream`
- `subagents.list` — GET `/api/v1/threads/{threadId}/subagents`
- `threads.subscribe` — POST `/api/v1/threads/{threadId}/subscribe`
- `threads.takeover` — POST `/api/v1/threads/{threadId}/takeover`
- `tasks.list` — GET `/api/v1/threads/{threadId}/tasks`
- `threads.unarchive` — POST `/api/v1/threads/{threadId}/unarchive`
- `threads.unread` — PUT `/api/v1/threads/{threadId}/unread`
- `threads.unsubscribe` — POST `/api/v1/threads/{threadId}/unsubscribe`
- `usage.get` — GET `/api/v1/usage`
- `usage.balance` — GET `/api/v1/usage/balance`
- `usage.series` — GET `/api/v1/usage/series`
- `users.list` — GET `/api/v1/users`

## Viking redesign verification

The redesigned app uses typed adaptive routing, semantic Liquid Glass components, and the supplied helm as icon/logo. Local checks now include navigation-path retention, per-thread draft retention, send mutual exclusion, payload-sensitive retry keys, attachment upload gating, and advanced form retention. Duo lint reports zero findings. The Impeccable mechanical detector reported no findings (it is not a visual judgment). Both simulator compilation and signed real-device builds pass. The redesigned signed build is installed over WiFi on the physical Duo. Outer-screen rows and margins, Home routing, accessibility-sized Home and Workspace content, and expanded navigation with the sidebar visible and hidden were inspected in the Duo simulator. Full authenticated workflows still need a real key.

## Browser and setup validation

The fullscreen browser, five-stage setup, native warm dither surfaces, and sheet-preserving presentation are part of build 4. Additional checks cover independent overlay visibility states and project-refresh/replacement-key failures preserving an established connection. Simulator verification covered both displays, native return, edge docking, two-finger recovery, first-use help, and sheet return. No API key was used for authenticated live mutations.

Verified key replacement and explicit disconnect advance the account revision and clear previous account routing and unsent work. Failed refreshes and rejected replacement keys do not advance it.

## Build 6 integration

Captain creation, automation schedules, issue fields and labels, and model selection have dedicated native controls. Captain details combine the Captain, crew, and digest endpoints and route actual thread IDs into chat. The searchable contract console retains all 108 operations for advanced actions. Provider marks cover every provider in the bundled catalog; Capy artwork comes from its official brand kit.

Local checks include deterministic delayed transport responses for disconnect during verification, superseded connection attempts, and refresh after disconnect. Navigation checks cover repeated sidebar selection, route cycles, semantic thread identity, and retained drafts. Live thread reducer checks cover fragments, durable settlement, duplicate messages, tool settlement, and dropped previews. Duo lint scans 27 Swift files with no findings. Build 6 compiles for simulator and signed device using Xcode 27.1 RC 27A9275 and is installed over WiFi on the real Duo. Authenticated live streams and mutations remain unverified without an API key.
