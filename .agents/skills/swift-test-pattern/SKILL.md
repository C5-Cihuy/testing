---
name: swift-test-pattern
description: Write deterministic unit tests for this Swift project with the Swift Testing framework, including @Test descriptions, #expect assertions, async behavior, ViewModels, services, business logic, mocks, fixtures, and regression coverage. Use when adding or changing tests, diagnosing regressions, or validating asynchronous state changes. Do not use XCTest unless the project explicitly requires it.
---

# Swift Testing Pattern

Use `import Testing`, `@Test`, `#expect`, `#require`, and `Issue.record`—not
XCTest APIs. Every test must use a short description and put the declaration on
the next line:

```swift
@Test("loads products successfully")
func loadsProductsSuccessfully() async {
    #expect(true)
}
```

## Workflow

1. Inspect the target behavior and existing test conventions.
2. Write a focused test that describes observable behavior, not implementation
   details. Use Arrange, Act, and Assert sections.
3. Create fresh system-under-test (`sut`) and mock state for each test. Never
   rely on test order or shared mutable fixtures.
4. Mock dependencies at the boundary (repository, API, keychain), not every
   intermediate type.
5. Make async tests truly `async` and await the operation under test. Mark suites
   `@MainActor` when testing main-actor ViewModels.
6. Cover success, failure, empty data, validation boundaries, loading guards,
   state transitions, and regression cases.
7. Run the narrow test target first, then the complete suite.

## Assertions and test data

- Use `#expect` for boolean and equality checks.
- Use `try #require` for values required to continue; avoid force unwraps.
- Use `Issue.record` when an expected error or event did not occur.
- Keep Arrange/Act/Assert explicit.
- Add factory helpers such as `Product.mock(...)` for repeatable fixtures.
- Use `Decimal` for money calculations; avoid floating-point equality checks.

Read [references/testing-pattern.md](references/testing-pattern.md) for
ViewModel, state, service, async, validation, and fixture examples.

Ignore related router, MVVM, and components patterns; this skill defines test
structure and behavior verification only.
