# Swift Testing Reference

## ViewModel tests

Use a fresh `sut` and mock dependency per test. Put `@Test` and `func` on
separate lines:

```swift
import Testing
@testable import AppModule

@MainActor
struct ProductViewModelTests {
    @Test("loads products successfully")
    func loadsProductsSuccessfully() async {
        let repository = MockProductRepository(result: .success([.mock()]))
        let sut = ProductViewModel(repository: repository)

        await sut.loadProducts()

        #expect(sut.products.count == 1)
        #expect(!sut.isLoading)
        #expect(sut.error == nil)
    }

    @Test("stores loading failure")
    func storesLoadingFailure() async {
        let repository = MockProductRepository(result: .failure(.network))
        let sut = ProductViewModel(repository: repository)

        await sut.loadProducts()

        #expect(sut.products.isEmpty)
        #expect(sut.error != nil)
        #expect(!sut.isLoading)
    }
}
```

Use `sut` for the system under test. Test outcomes—such as rendered state or
stored errors—rather than whether a particular private method was called.

## State and business logic

Cover initial state, each meaningful mutation, duplicate-item behavior, removal,
clearing, totals, validation boundaries, and invalid input. A test should make
the expected behavior obvious:

```swift
@Test("adding an existing item increments quantity")
func addingExistingItemIncrementsQuantity() {
    let product = Product.mock(price: 10)
    let sut = CartViewModel()

    sut.addItem(product)
    sut.addItem(product)

    #expect(sut.items.count == 1)
    #expect(sut.items.first?.quantity == 2)
}
```

## Service tests

Mock network/session, persistence, and keychain boundaries. Test successful
decoding, status-code errors, malformed data, transport failures, auth
success/failure, logout cleanup, and session restoration without real services.
Use `try #require` for URLs or responses needed by the test:

```swift
@Test("maps a not-found response to API error")
func mapsNotFoundResponseToAPIError() async throws {
    let url = try #require(URL(string: "https://api.test.invalid"))
    let session = MockURLSession(response: HTTPURLResponse(
        url: url, statusCode: 404, httpVersion: nil, headerFields: nil
    ))

    do {
        let _: Product = try await APIClient(session: session).get("/products/1")
        Issue.record("Expected not-found error")
    } catch let error as APIError {
        #expect(error == .notFound)
    }
}
```

## Async and timing behavior

Await the operation under test. For debounce or loading-state tests, use a
controlled mock or a short deterministic suspension, then await the task before
asserting final state:

```swift
@MainActor
struct SearchViewModelTests {
    @Test("debounces rapid query changes")
    func debouncesRapidQueryChanges() async throws {
        let repository = MockSearchRepository()
        let sut = SearchViewModel(repository: repository)

        sut.query = "a"
        sut.query = "ab"
        sut.query = "abc"
        try await Task.sleep(for: .milliseconds(500))

        #expect(repository.searchCallCount == 1)
    }
}
```

Prefer injected clocks or controllable test doubles when the project supports
them; avoid unnecessarily long sleeps and flaky wall-clock assumptions.

## Fixtures and regression tests

Centralize valid defaults in test-only factories and override only the value
relevant to the scenario:

```swift
extension Product {
    static func mock(
        id: UUID = UUID(),
        name: String = "Test Product",
        price: Decimal = 9.99
    ) -> Product {
        Product(id: id, name: name, price: price)
    }
}
```

When fixing a bug, first add a failing regression test, then implement the fix
and retain the test. Test edge cases and behavior, not internal call order.

## Common pitfalls

- Never omit `await` around async work; otherwise assertions can run too early.
- Mark `@MainActor` suites when their ViewModels require main-actor isolation.
- Do not use force unwraps in tests; use `#require` or assert optional state.
- Do not share mutable mock state across tests.
- Do not use `Double`/`Float` for exact monetary assertions.
- Keep every `@Test("short description")` immediately above its `func` on the
  following line.
