---
name: swiftui-components-pattern
description: Build reusable SwiftUI components for this project with focused responsibilities, plain-data inputs, callback outputs, configuration structs, composition, previews, theming, accessibility, and consistent file organization. Use when extracting views, creating reusable rows/cards/buttons, designing loading or empty states, adding previews, or improving component accessibility.
---

# SwiftUI Components Pattern

Treat components as pure UI building blocks: data in, callbacks out, rendered
UI back. A component must not know where its data came from and must not own
feature business logic.

## Rules

- Give each component one visual responsibility.
- Accept plain `let` data and closures for user actions.
- Keep ViewModels, app-state `@Environment`, networking, persistence, and
  business logic out of reusable components.
- Keep scrolling and screen-level state in the feature view.
- Move formatting to a `+Formatting.swift` extension or feature layer.
- Add at least one `#Preview` with mock data for every component.

## Workflow

1. Identify the smallest cohesive visual responsibility and define its input
   data and callback API.
2. Extract one primary type per file under `Views/Components/`.
3. Keep the body declarative and stateless; let the parent decide what actions
   mean.
4. Replace four or more related visual parameters with a nested `Configuration`
   struct using sensible defaults and optional factory presets.
5. Compose components in feature Views rather than duplicating layout.
6. Add previews for default, long/empty, disabled, loading, and other meaningful
   edge states. Previews must never perform network or database work.
7. Add accessibility labels, hints, traits, and combined elements at the
   component boundary.

Read [references/components-pattern.md](references/components-pattern.md) for
implementation templates, theme guidance, and organization examples.

Ignore related MVVM, router, and testing patterns; this skill covers component
design and presentation boundaries only.
