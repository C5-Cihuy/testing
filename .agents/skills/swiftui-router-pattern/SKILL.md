---
name: swiftui-router-pattern
description: Build and maintain centralized, type-safe SwiftUI navigation for this project using an @Observable router, enum routes, NavigationStack paths, environment injection, modal routes, tabs, deep links, and router tests. Use when adding screens, navigation, sheets, full-screen covers, alerts, tab flows, or deep-link handling.
---

# SwiftUI Router Pattern

Use the project’s router pattern instead of coordinators, navigation protocols,
delegates, factories, or scattered presentation state.

## Workflow

1. Inspect the existing router, route enums, destination views, and root view.
2. Add destinations to the appropriate `Hashable` route enum.
3. Add an exhaustive route-to-view switch and let the compiler find omissions.
4. Mutate navigation only through router methods. Feature views use
   `@Environment(AppRouter.self)`.
5. Keep stack, sheet, full-screen, and alert bindings in the root router view.
6. Add Swift Testing tests for new methods, navigation sequences, and deep links.

## Required shape

- Store an `@Observable` router instance in root `@State`.
- Bind its `NavigationPath` to `NavigationStack(path:)`.
- Register destinations with `navigationDestination(for:)`.
- Inject with `.environment(router)` and read by type.
- Make sheet and full-screen route enums `Identifiable` for `item:` bindings.
- Prefer convenience methods for multi-step flows.

Read [references/router-pattern.md](references/router-pattern.md) for the
implementation template, modal/tab/deep-link guidance, and testing examples.
