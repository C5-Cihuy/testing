# MVVM Pattern Reference

## Model

Models are pure data and should not import SwiftUI or contain UI state:

```swift
import Foundation

struct Post: Identifiable, Codable {
    let id: String
    let authorID: String
    let title: String
    let content: String
    let createdAt: Date
    let likes: Int
    let isLiked: Bool
}
```

Keep display formatting and mutable presentation state in the ViewModel or a
small view helper, not in the model.

## ViewModel and service injection

```swift
import Observation

@Observable
final class PostListViewModel {
    private(set) var posts: [Post] = []
    private(set) var isLoading = false
    private(set) var error: AppError?

    private let service: PostServiceProtocol

    init(service: PostServiceProtocol = PostService()) {
        self.service = service
    }

    func loadPosts() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            posts = try await service.fetchPosts()
        } catch let error as AppError {
            self.error = error
        } catch {
            self.error = .unknown(error)
        }
    }

    func dismissError() { error = nil }
}
```

Views can own the model lifetime with `@State`:

```swift
struct PostListView: View {
    @State private var viewModel = PostListViewModel()

    var body: some View {
        content
            .task { await viewModel.loadPosts() }
            .refreshable { await viewModel.loadPosts() }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.posts.isEmpty {
            ProgressView()
        } else if viewModel.posts.isEmpty {
            ContentUnavailableView("No Posts", systemImage: "doc")
        } else {
            List(viewModel.posts) { post in
                PostRow(post: post) { /* send intent */ }
            }
        }
    }
}
```

For a ViewModel requiring runtime input, initialize its `@State` in the View
initializer. For shared observable state, create it at the appropriate root,
inject with `.environment(model)`, and retrieve it with `@Environment(Type.self)`.

## Inputs, outputs, and state enums

Separate editable inputs from read-only outputs. For forms, keep fields such as
`email` and `password` writable, expose `private(set)` loading/error/success
state, and derive validation with computed properties.

Use an explicit state enum when states are mutually exclusive:

```swift
enum ViewState<Value> {
    case idle
    case loading
    case loaded(Value)
    case error(AppError)
}
```

Switch over the enum in the View so loading, content, and error rendering cannot
accidentally appear together.

## Composition and factories

Let a parent ViewModel own child ViewModels for genuinely complex screens. Pass
child ViewModels to child Views only when the child owns meaningful state.
Otherwise pass plain data and closures.

Introduce a ViewModel factory only when dependency construction is repeated or
the app has a real dependency container. A factory should create ViewModels from
injected services; it should not contain screen business logic.

## Testing

Test ViewModels without constructing Views:

```swift
import Testing

@MainActor
struct PostListViewModelTests {
    @Test func loadSuccessUpdatesPosts() async {
        let service = MockPostService(result: .success([.preview]))
        let viewModel = PostListViewModel(service: service)

        await viewModel.loadPosts()

        #expect(viewModel.posts.count == 1)
        #expect(viewModel.error == nil)
        #expect(!viewModel.isLoading)
    }
}
```

Also test service failure, duplicate-load protection, validation, optimistic
update rollback, and success/error state transitions. Prefer deterministic mock
services over network or UI tests.

## Pitfalls

- Use `@State` with `@Observable`; do not mix it with the older `@StateObject`
  approach unless the project explicitly uses `ObservableObject`.
- Do not start async work in `init`; use `.task` or an explicit action.
- Do not bind directly to computed properties. Use stored input properties for
  two-way bindings and computed properties for one-way derived output.
- Avoid god ViewModels. Split by screen or focused responsibility.
- Keep analytics and other side effects in ViewModel actions or services, not in
  rendering code.
