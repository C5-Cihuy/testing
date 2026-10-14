# Router Pattern Reference

## Core implementation

```swift
import SwiftUI
import Observation

enum AppRoute: Hashable {
    case home
    case detail(id: String)
    case settings
}

@Observable
final class AppRouter {
    var path = NavigationPath()
    var sheet: SheetRoute?
    var fullScreenCover: FullScreenRoute?
    var alert: AlertConfig?

    func navigate(to route: AppRoute) { path.append(route) }
    func pop() { guard !path.isEmpty else { return }; path.removeLast() }
    func popToRoot() { path.removeLast(path.count) }
    func replace(with route: AppRoute) {
        if !path.isEmpty { path.removeLast() }
        path.append(route)
    }
    func presentSheet(_ route: SheetRoute) { sheet = route }
    func dismissSheet() { sheet = nil }
    func presentFullScreen(_ route: FullScreenRoute) { fullScreenCover = route }
    func dismissFullScreen() { fullScreenCover = nil }
}
```

Own the router at the root, bind the path, map destinations exhaustively, and
inject the instance:

```swift
struct RootRouterView: View {
    @State private var router = AppRouter()

    var body: some View {
        NavigationStack(path: $router.path) {
            HomeView()
                .navigationDestination(for: AppRoute.self) {
                    RouteDestination(route: $0)
                }
        }
        .sheet(item: $router.sheet) { SheetDestination(route: $0) }
        .fullScreenCover(item: $router.fullScreenCover) {
            FullScreenDestination(route: $0)
        }
        .environment(router)
    }
}
```

## Modals, tabs, and deep links

Use separate `Identifiable` enums for sheets and full-screen covers with stable
IDs. Callback payloads are acceptable for short-lived sheet results such as
sort/filter selections; do not use them to replace business logic or router
state. Keep alert configuration in the router and bind `alert != nil` at root.

For tabs, keep one `NavigationPath` per tab and one selected-tab value. Selecting
the active tab may pop it to root. Cross-tab methods select the tab first, then
append its route.

Parse URLs at the router boundary into `AppRoute?`; reject malformed hosts or
IDs and explicitly decide whether deep links clear the current flow.

## Testing

Test the router as a plain object with Swift Testing:

```swift
import Testing

@Test func navigateAppendsRoute() {
    let router = AppRouter()
    router.navigate(to: .detail(id: "123"))
    #expect(router.path.count == 1)
}
```

Cover push, empty-path pop, pop-to-root, replace, modal presentation/dismissal,
convenience sequences, malformed deep links, and tab selection. `NavigationPath`
is type-erased, so assert count or maintain a typed test representation when
route contents must be inspected.

## Pitfalls

- Avoid accidental nested `NavigationStack`s.
- Ensure every `item:` route conforms to `Identifiable`.
- Keep route switches exhaustive; do not hide missing destinations with `default`.
- Guard empty paths before removing elements.
- Handle deep links interrupting unsaved flows explicitly.
