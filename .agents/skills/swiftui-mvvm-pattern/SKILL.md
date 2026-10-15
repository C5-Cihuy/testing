---
name: swiftui-mvvm-pattern
description: "Build and maintain SwiftUI features using MVVM: framework-agnostic models, @Observable view models, injected services, declarative views, reusable data-driven components, explicit state enums, and testable async logic. Use when adding screens, forms, loading/error states, service integrations, child view models, dependency injection, or ViewModel tests."
---

# SwiftUI MVVM Pattern

Keep responsibilities separate: Models hold pure data, ViewModels own state and
actions, Views render state and send user intent, and Services handle external
dependencies. Do not put networking, persistence, analytics, or business rules
inside Views.

## Workflow

1. Inspect the project’s existing Models, ViewModels, Views, Services, and test
   conventions before adding a feature.
2. Define framework-agnostic `struct` models with `Identifiable`/`Codable` only
   when needed. Keep presentation formatting and mutable UI state out of models.
3. Add an `@Observable` ViewModel per screen or focused feature. Expose state
   with `private(set)` and mutate it through intention-revealing methods.
4. Inject service protocols through the initializer, with production defaults
   only where consistent with the project. Keep dependencies replaceable in tests.
5. Store the ViewModel with `@State` when the View owns its lifetime. Use
   `.task` for async loading; never perform async work in an initializer.
6. Keep Views declarative: render ViewModel state, create bindings, and call
   ViewModel actions. Extract reusable rows as data plus closures, without a
   ViewModel unless they own meaningful state.
7. Test ViewModels directly with Swift Testing, including success, failure,
   loading guards, state transitions, optimistic updates, and service calls.

## State rules

- Prefer computed properties for derived values such as `isFormValid` and
  `canSubmit` instead of storing duplicate state.
- Use a `ViewState` enum (`idle`, `loading`, `loaded`, `error`) when booleans
  could represent contradictory states.
- For optimistic updates, update immediately, call the service, and restore the
  original value on failure.
- Mark ViewModels and matching tests `@MainActor` when their observable state is
  UI-main-actor isolated.
- Use `@Bindable` locally when a View needs `$viewModel.property` bindings for
  controls; do not expose unrestricted mutation from the View.

Read [references/mvvm-pattern.md](references/mvvm-pattern.md) for templates and
advanced guidance. Ignore related router, components, and test-pattern guides;
this skill only defines MVVM responsibilities and ViewModel testing practices.
